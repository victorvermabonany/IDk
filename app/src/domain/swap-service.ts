import { randomUUID } from "node:crypto";
import { buildBasket, basketTotal, priceCoverage, scaleMeal } from "./engine";
import { mealConstraintIssues, requiredServings, validatePlanOrThrow } from "./constraints";
import { DEMO_MEALS } from "./fixtures";
import { fixtureGroceryProvider } from "./fixture-provider";
import { PlanGenerationError, type BasketItem, type MealPlan, type SwapPreview } from "./types";

export interface PricedSwapPreview extends SwapPreview { basket: BasketItem[]; }

export async function createSwapPreviews(plan: MealPlan, mealID: string): Promise<PricedSwapPreview[]> {
  const current = plan.meals.find((meal) => meal.id === mealID);
  if (!current) throw new PlanGenerationError("CONSTRAINT_CONFLICT", "That meal is no longer in the current plan.");
  const usedTitles = new Set(plan.meals.map((meal) => meal.title.toLowerCase()));
  const pantry = new Set([
    ...plan.basket.filter((item) => item.pantryStatus === "already_have").map((item) => item.ingredientId),
  ]);
  const previews: PricedSwapPreview[] = [];
  for (const candidate of DEMO_MEALS) {
    if (usedTitles.has(candidate.title.toLowerCase())) continue;
    const scaled = scaleMeal(candidate, requiredServings(plan.constraintsUsed));
    const replacement = { ...scaled, id: current.id, day: current.day };
    if (mealConstraintIssues(replacement, plan.constraintsUsed).length > 0) continue;
    const meals = plan.meals.map((meal) => meal.id === mealID ? replacement : meal);
    try { validatePlanOrThrow(meals, plan.constraintsUsed); } catch { continue; }
    const basket = await buildBasket({ meals, provider: fixtureGroceryProvider, storeId: plan.store.id, pantryIngredientIds: [...pantry] });
    if (priceCoverage(basket) < 1) continue;
    const total = basketTotal(basket);
    if (total > plan.budgetCents) continue;
    const oldIngredients = new Set(plan.meals.filter((meal) => meal.id !== mealID).flatMap((meal) => meal.ingredients.map((item) => item.ingredientId)));
    previews.push({
      id: randomUUID(), meal: replacement, basket,
      deltaCents: total - plan.estimatedTotalCents,
      reusedIngredientCount: replacement.ingredients.filter((item) => oldIngredients.has(item.ingredientId)).length,
      resultingTotalCents: total,
    });
  }
  return previews.sort((left, right) => left.resultingTotalCents - right.resultingTotalCents).slice(0, 3);
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
