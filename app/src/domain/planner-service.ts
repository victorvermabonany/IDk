import { randomUUID } from "node:crypto";
import { buildBasket, basketTotal, normalizeIngredientName, priceCoverage, scaleMeal } from "./engine";
import { mealConstraintIssues, preferenceScore, requiredServings, validatePlanOrThrow } from "./constraints";
import { prepareMealContent } from "./meal-quality";
import { validateHighProteinTarget, weeklyNutritionSummary } from "./nutrition";
import { DEMO_MEALS, DEMO_STORE, DEMO_STORES } from "./fixtures";
import { providerForStore } from "./grocery-providers";
import { budgetTargetPercent, runtimeMode } from "@/server/runtime-config";
import { PlanGenerationError, type BasketItem, type GroceryProvider, type Meal, type MealPlan, type PlannerRequest, type ProviderStore } from "./types";

export type GenerationProgressStage =
  | "Building your grocery list"
  | "Checking your store"
  | "Balancing your budget"
  | "Finishing your week";

export interface GenerationProgressMetadata {
  ingredientCount?: number;
  productsMatched?: number;
  reusedIngredientCount?: number;
  underBudgetCents?: number;
}

export interface GenerationProgressEvent {
  stage: GenerationProgressStage;
  metadata?: GenerationProgressMetadata;
}

export type GenerationProgressReporter = (event: GenerationProgressEvent) => Promise<void>;

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

function cachedProvider(provider: GroceryProvider): GroceryProvider {
  const searches = new Map<string, ReturnType<GroceryProvider["searchProducts"]>>();
  const products = new Map<string, ReturnType<GroceryProvider["getProduct"]>>();
  return {
    id: provider.id,
    displayName: provider.displayName,
    findStores: (zipCode) => provider.findStores(zipCode),
    searchProducts(input) {
      const key = `${input.storeId}:${input.ingredientId}`;
      let pending = searches.get(key);
      if (!pending) {
        pending = provider.searchProducts(input);
        searches.set(key, pending);
      }
      return pending;
    },
    getProduct(input) {
      const key = `${input.storeId}:${input.productId}`;
      let pending = products.get(key);
      if (!pending) {
        pending = provider.getProduct(input);
        products.set(key, pending);
      }
      return pending;
    },
  };
}

async function resolveStore(request: PlannerRequest): Promise<{ store: ProviderStore; provider: GroceryProvider }> {
  let provider: GroceryProvider;
  try { provider = providerForStore(request.store); }
  catch {
    throw new PlanGenerationError("PROVIDER_UNAVAILABLE", "That pricing source is not configured for this Cove environment.", ["Choose another store or estimate"]);
  }
  const stores = await provider.findStores(request.store.postalCode);
  const store = stores.find((candidate) => candidate.id === request.store.id && candidate.providerStoreId === request.store.locationId);
  if (!store) throw new PlanGenerationError("PROVIDER_UNAVAILABLE", "That store location is not available for the selected ZIP code.", ["Choose another supported store"]);
  if (runtimeMode() !== "development_fixture" && store.priceKind === "fixture") {
    throw new PlanGenerationError("PROVIDER_UNAVAILABLE", "Fixture pricing is disabled in this Cove environment.");
  }
  return { store, provider: cachedProvider(provider) };
}

async function priceCombination(meals: Meal[], request: PlannerRequest, store: ProviderStore, provider: GroceryProvider) {
  const pantryIds = request.pantryItems.map(normalizeIngredientName);
  const basket = await buildBasket({ meals, provider, storeId: store.id, pantryIngredientIds: pantryIds });
  return { basket, coverage: priceCoverage(basket), total: basketTotal(basket) };
}

function eligibleCandidates(candidates: Meal[], request: PlannerRequest) {
  const servings = requiredServings(request);
  const normalizedTitles = new Set<string>();
  const eligible = candidates
    .map(prepareMealContent)
    .filter((meal) => {
      const title = meal.title.toLowerCase();
      if (normalizedTitles.has(title)) return false;
      normalizedTitles.add(title);
      return true;
    })
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

  return eligible;
}

async function optimizeCandidates(eligible: Meal[], request: PlannerRequest, store: ProviderStore, provider: GroceryProvider) {
  const targetPercent = budgetTargetPercent(store.priceKind);
  const target = Math.round(request.budgetCents * targetPercent);
  let best: { meals: Meal[]; basket: BasketItem[]; coverage: number; total: number; score: number } | undefined;
  for (const mealSet of combinations(eligible, request.dinnerCount)) {
    const priced = await priceCombination(mealSet, request, store, provider);
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

export async function generatePlan(
  request: PlannerRequest,
  planID: string = randomUUID(),
  reportProgress: GenerationProgressReporter = async () => {},
): Promise<MealPlan> {
  const candidates = await candidatePool(request);
  await reportProgress({ stage: "Building your grocery list" });
  const eligible = eligibleCandidates(candidates, request);

  await reportProgress({ stage: "Checking your store" });
  const { store, provider } = await resolveStore(request);

  await reportProgress({ stage: "Balancing your budget" });
  const optimized = await optimizeCandidates(eligible, request, store, provider);
  validatePlanOrThrow(optimized.meals, request);
  await reportProgress({
    stage: "Finishing your week",
    metadata: {
      ingredientCount: optimized.basket.length,
      productsMatched: optimized.basket.filter((item) => item.product !== null).length,
      reusedIngredientCount: optimized.basket.filter((item) => item.mealIds.length > 1).length,
      underBudgetCents: Math.max(0, request.budgetCents - optimized.total),
    },
  });
  const observedTimes = optimized.basket.flatMap((item) => item.product ? [item.product.observedAt] : []);
  const createdAt = new Date().toISOString();
  const nutritionProvenance = {
    kind: "unverified" as const,
    source: process.env.OPENAI_LIVE_PLANNING_ENABLED === "true" ? "model_recipe_estimate" : "fixture_recipe_estimate",
  };
  const highProteinValidation = validateHighProteinTarget(optimized.meals, nutritionProvenance);
  if (request.nutritionStyle === "high-protein" && highProteinValidation.supported && !highProteinValidation.meetsTarget) {
    throw new PlanGenerationError(
      "CONSTRAINT_CONFLICT",
      "The authoritative nutrition calculation did not meet Cove's protein target for this week.",
      ["Choose balanced planning", "Relax another preference"],
    );
  }
  return {
    id: planID,
    title: `${request.dinnerCount} dinners for your week`,
    store,
    constraintsUsed: structuredClone(request),
    budgetCents: request.budgetCents,
    internalTargetCents: Math.round(request.budgetCents * budgetTargetPercent(store.priceKind)),
    estimatedTotalCents: optimized.total,
    priceCoverage: optimized.coverage,
    priceKind: store.priceKind,
    priceObservedAt: observedTimes.sort().at(-1) ?? createdAt,
    pricingProvenance: {
      pricingMode: store.priceKind === "live" || store.priceKind === "feed" ? "live" : store.priceKind,
      provider: provider.id as "kroger" | "cove_estimate" | "fixture",
      providerName: provider.displayName,
      storeName: store.name,
      providerStoreId: store.providerStoreId,
      updatedAt: observedTimes.sort().at(-1) ?? createdAt,
    },
    nutritionProvenance,
    weeklyNutritionSummary: weeklyNutritionSummary(optimized.meals, nutritionProvenance),
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
