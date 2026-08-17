import { randomUUID } from "node:crypto";
import { buildBasket, basketTotal, normalizeIngredientName, priceCoverage, scaleMeal } from "./engine";
import { mealConstraintIssues, preferenceScore, requiredServings, validatePlanOrThrow } from "./constraints";
import { DEMO_MEALS, DEMO_STORE, DEMO_STORES } from "./fixtures";
import { fixtureGroceryProvider } from "./fixture-provider";
import { PlanGenerationError, type BasketItem, type Meal, type MealPlan, type PlannerRequest, type ProviderStore } from "./types";

function combinations<T>(items: T[], count: number): T[][] {
  const result: T[][] = [];
  const visit = (start: number, current: T[]) => {
    if (current.length === count) { result.push([...current]); return; }
    for (let index = start; index <= items.length - (count - current.length); index += 1) {
      current.push(items[index]); visit(index + 1, current); current.pop();
    }
  };
  visit(0, []);
  return result;
}

async function resolveStore(request: PlannerRequest): Promise<ProviderStore> {
  const stores = await fixtureGroceryProvider.findStores(request.store.postalCode);
  const store = stores.find((candidate) => candidate.id === request.store.id && candidate.providerStoreId === request.store.locationId);
  if (!store) throw new PlanGenerationError("PROVIDER_UNAVAILABLE", "That store location is not available for the selected ZIP code.", ["Choose another supported store"]);
  return store;
}

async function priceCombination(meals: Meal[], request: PlannerRequest, store: ProviderStore) {
  const pantryIds = request.pantryItems.map(normalizeIngredientName);
  const basket = await buildBasket({ meals, provider: fixtureGroceryProvider, storeId: store.id, pantryIngredientIds: pantryIds });
  return { basket, coverage: priceCoverage(basket), total: basketTotal(basket) };
}

async function optimizeCandidates(candidates: Meal[], request: PlannerRequest, store: ProviderStore) {
  const servings = requiredServings(request);
  const eligible = candidates
    .map((meal) => scaleMeal(meal, servings))
    .filter((meal) => mealConstraintIssues(meal, request).length === 0)
    .sort((left, right) => preferenceScore([right], request) - preferenceScore([left], request))
    .slice(0, 13);

  if (eligible.length < request.dinnerCount) {
    throw new PlanGenerationError(
      "CONSTRAINT_CONFLICT",
      `We couldn't find ${request.dinnerCount} dinners that satisfy every selected food and time constraint.`,
      ["Reduce dinners", "Increase the cooking-time limit", "Change non-safety preferences"],
    );
  }

  const target = Math.round(request.budgetCents * 0.94);
  let best: { meals: Meal[]; basket: BasketItem[]; coverage: number; total: number; score: number } | undefined;
  for (const mealSet of combinations(eligible, request.dinnerCount)) {
    const priced = await priceCombination(mealSet, request, store);
    if (priced.coverage < 1 || priced.total > request.budgetCents) continue;
    const targetDistance = Math.abs(priced.total - target) / Math.max(1, request.budgetCents);
    const score = preferenceScore(mealSet, request) - targetDistance * 180;
    if (!best || score > best.score) best = { meals: mealSet, ...priced, score };
  }
  if (!best) {
    throw new PlanGenerationError(
      "BUDGET_TOO_LOW",
      `We couldn't build ${request.dinnerCount} dinners for ${request.householdSize} people within ${(request.budgetCents / 100).toLocaleString("en-US", { style: "currency", currency: "USD" })} while keeping your selected restrictions.`,
      ["Increase the budget", "Reduce dinners", "Turn off planned leftovers"],
    );
  }
  return best;
}

async function candidatePool(request: PlannerRequest): Promise<Meal[]> {
  if (process.env.OPENAI_LIVE_PLANNING_ENABLED === "true") {
    if (!process.env.OPENAI_API_KEY) throw new PlanGenerationError("MODEL_FAILURE", "Live meal generation is not configured.");
    let lastError: unknown;
    for (let attempt = 0; attempt < 2; attempt += 1) {
      try {
        const { proposeMeals } = await import("../lib/ai/openai-recipe-proposer");
        const proposed = await proposeMeals(request, attempt === 0 ? undefined : "Return more varied candidates and strictly obey every hard constraint.");
        if (proposed.length >= request.dinnerCount) return proposed;
      } catch (error) { lastError = error; }
    }
    throw new PlanGenerationError("MODEL_FAILURE", lastError instanceof Error ? `Meal generation failed: ${lastError.message}` : "Meal generation failed before valid structured candidates were returned.");
  }
  return DEMO_MEALS;
}

export async function generatePlan(request: PlannerRequest): Promise<MealPlan> {
  const store = await resolveStore(request);
  const optimized = await optimizeCandidates(await candidatePool(request), request, store);
  validatePlanOrThrow(optimized.meals, request);
  const observedTimes = optimized.basket.flatMap((item) => item.product ? [item.product.observedAt] : []);
  const createdAt = new Date().toISOString();
  return {
    id: randomUUID(),
    title: `${request.dinnerCount} dinners for your week`,
    store,
    constraintsUsed: structuredClone(request),
    budgetCents: request.budgetCents,
    internalTargetCents: Math.round(request.budgetCents * 0.94),
    estimatedTotalCents: optimized.total,
    priceCoverage: optimized.coverage,
    priceKind: store.priceKind,
    priceObservedAt: observedTimes.sort().at(-1) ?? createdAt,
    meals: optimized.meals,
    basket: optimized.basket,
    createdAt,
    safetyNotice: "Generated plans exclude known allergens using available recipe and catalog metadata. Always verify every package label and cross-contact warning. Cross-contact cannot be guaranteed. Nutrition and complete-package prices are planning estimates, not medical advice or exact shelf totals.",
  };
}

export const DEFAULT_PLANNER_REQUEST: PlannerRequest = {
  store: { id: DEMO_STORE.id, locationId: DEMO_STORE.providerStoreId, postalCode: "45202" },
  budgetCents: 10_000,
  householdSize: 2,
  dinnerCount: 5,
  leftovers: { enabled: false, extraServings: 0 },
  nutritionStyle: "high-protein",
  dietaryRestrictions: [],
  allergies: [],
  dislikedFoods: ["mushrooms", "seafood"],
  preferredCuisines: [],
  maxCookingMinutes: 40,
  pantryItems: ["olive oil", "salt", "black pepper"],
  customInstructions: "",
};

export { DEMO_STORES };
