import type { BasketItem, MealPlan } from "@/domain/types";

export type APIBasketItem = Omit<BasketItem, "pantryStatus"> & { pantryStatus: boolean };
export type APIPlan = Omit<MealPlan, "basket"> & { basket: APIBasketItem[] };

export function hydratePlan(plan: APIPlan): MealPlan {
  return {
    ...plan,
    basket: plan.basket.map((item) => ({
      ...item,
      pantryStatus: item.pantryStatus ? "already_have" : "needed",
    })),
  };
}
