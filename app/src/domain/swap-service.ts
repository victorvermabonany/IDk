import { randomUUID } from "node:crypto";
import { buildBasket, basketTotal, priceCoverage, scaleMeal } from "./engine";
import { mealConstraintIssues, preferenceScore, requiredServings, validatePlanOrThrow } from "./constraints";
import { mealSimilarity, prepareMealContent } from "./meal-quality";
import { DEMO_MEALS } from "./fixtures";
import { providerForStore } from "./grocery-providers";
import { PlanGenerationError, type BasketItem, type GroceryProvider, type MealPlan, type SwapPreview } from "./types";

export interface PricedSwapPreview extends SwapPreview { basket: BasketItem[]; }

function cachedSearchProvider(provider: GroceryProvider): GroceryProvider {
  const searches = new Map<string, ReturnType<GroceryProvider["searchProducts"]>>();
  return {
    id: provider.id,
    displayName: provider.displayName,
    findStores: (zipCode) => provider.findStores(zipCode),
    searchProducts(input) {
      const key = `${input.storeId}:${input.ingredientId}`;
      const existing = searches.get(key);
      if (existing) return existing;
      const pending = provider.searchProducts(input);
      searches.set(key, pending);
      return pending;
    },
    getProduct: (input) => provider.getProduct(input),
  };
}

export async function createSwapPreviews(plan: MealPlan, mealID: string): Promise<PricedSwapPreview[]> {
  const current = plan.meals.find((meal) => meal.id === mealID);
  if (!current) throw new PlanGenerationError("CONSTRAINT_CONFLICT", "That meal is no longer in the current plan.");
  const usedTitles = new Set(plan.meals.map((meal) => meal.title.toLowerCase()));
  const pantry = new Set([
    ...plan.basket.filter((item) => item.pantryStatus === "already_have").map((item) => item.ingredientId),
  ]);
  const provider = cachedSearchProvider(providerForStore({ id: plan.store.id, locationId: plan.store.providerStoreId }));
  const previews: Array<PricedSwapPreview & { qualityScore: number }> = [];
  const otherMeals = plan.meals.filter((meal) => meal.id !== mealID);
  for (const candidate of DEMO_MEALS) {
    if (usedTitles.has(candidate.title.toLowerCase())) continue;
    const scaled = scaleMeal(prepareMealContent(candidate), requiredServings(plan.constraintsUsed));
    const replacement = { ...scaled, id: current.id, day: current.day };
    if (mealConstraintIssues(replacement, plan.constraintsUsed).length > 0) continue;
    if (mealSimilarity(replacement, current) >= 0.72) continue;
    if (otherMeals.some((meal) => mealSimilarity(replacement, meal) >= 0.82)) continue;
    const meals = plan.meals.map((meal) => meal.id === mealID ? replacement : meal);
    try { validatePlanOrThrow(meals, plan.constraintsUsed); } catch { continue; }
    const basket = await buildBasket({ meals, provider, storeId: plan.store.id, pantryIngredientIds: [...pantry] });
    if (priceCoverage(basket) < 1) continue;
    const total = basketTotal(basket);
    if (total > plan.budgetCents) continue;
    const oldIngredients = new Set(plan.meals.filter((meal) => meal.id !== mealID).flatMap((meal) => meal.ingredients.map((item) => item.ingredientId)));
    const deltaCents = total - plan.estimatedTotalCents;
    previews.push({
      id: randomUUID(), meal: replacement, basket,
      deltaCents,
      reusedIngredientCount: replacement.ingredients.filter((item) => oldIngredients.has(item.ingredientId)).length,
      resultingTotalCents: total,
      qualityScore: preferenceScore(meals, plan.constraintsUsed) - Math.max(0, deltaCents) / Math.max(1, plan.budgetCents) * 60,
    });
  }
  const ranked = previews.sort((left, right) => right.qualityScore - left.qualityScore || left.resultingTotalCents - right.resultingTotalCents);
  const distinct: PricedSwapPreview[] = [];
  for (const preview of ranked) {
    if (distinct.some((selected) => mealSimilarity(preview.meal, selected.meal) >= 0.72)) continue;
    distinct.push({
      id: preview.id,
      meal: preview.meal,
      basket: preview.basket,
      deltaCents: preview.deltaCents,
      reusedIngredientCount: preview.reusedIngredientCount,
      resultingTotalCents: preview.resultingTotalCents,
    });
    if (distinct.length === 3) break;
  }
  return distinct;
}

export function applyPricedSwap(plan: MealPlan, mealID: string, preview: PricedSwapPreview): MealPlan {
  if (preview.resultingTotalCents > plan.budgetCents) throw new PlanGenerationError("BUDGET_TOO_LOW", "That alternative no longer fits the weekly budget.");
  return {
    ...plan,
    meals: plan.meals.map((meal) => meal.id === mealID ? preview.meal : meal),
    basket: preview.basket,
    estimatedTotalCents: preview.resultingTotalCents,
  };
}

export function reconcileGroceryOwnership(plan: MealPlan, ownedItemIDs: Set<string>): MealPlan {
  const basket = plan.basket.map((item) => {
    const owned = ownedItemIDs.has(item.id);
    const unitPrice = item.product ? item.product.salePriceCents ?? item.product.regularPriceCents : null;
    return { ...item, pantryStatus: owned ? "already_have" as const : "needed" as const, totalPriceCents: owned ? 0 : unitPrice === null ? null : item.packageCount * unitPrice };
  });
  return { ...plan, basket, estimatedTotalCents: basketTotal(basket) };
}
