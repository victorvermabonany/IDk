import type { MealPlan } from "@/domain/types";

function alignment(position: string) {
  const percent = Number.parseFloat(position);
  return Number.isFinite(percent) ? Math.min(1, Math.max(0, percent / 100)) : 0.5;
}

export function apiPlan(plan: MealPlan) {
  return {
    ...plan,
    meals: plan.meals.map((meal) => ({ ...meal, imageAlignment: alignment(meal.imagePosition) })),
    basket: plan.basket.map((item) => ({
      id: item.id,
      ingredientId: item.ingredientId,
      displayName: item.displayName,
      productName: item.productName,
      packageDisplay: item.packageDisplay,
      requiredDisplay: item.requiredDisplay,
      requiredQuantity: item.requiredQuantity,
      requiredUnit: item.requiredUnit,
      product: item.product,
      packageCount: item.packageCount,
      totalPriceCents: item.totalPriceCents ?? 0,
      department: item.department,
      mealIds: item.mealIds,
      pantryStatus: item.pantryStatus === "already_have",
    })),
  };
}

export function apiSwapPreview(preview: { id: string; meal: MealPlan["meals"][number]; deltaCents: number; reusedIngredientCount: number; resultingTotalCents: number }) {
  return { ...preview, meal: { ...preview.meal, imageAlignment: alignment(preview.meal.imagePosition) } };
}
