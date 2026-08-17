import type { BasketItem, MealPlan } from "@/domain/types";

// The boolean form existed in the earliest browser prototype. Keep decode
// compatibility for a stored beta session, while the versioned API uses the
// domain's explicit `needed` / `already_have` values.
export type APIBasketItem = Omit<BasketItem, "pantryStatus"> & {
  pantryStatus: BasketItem["pantryStatus"] | boolean;
};
export type APIPlan = Omit<MealPlan, "basket"> & { basket: APIBasketItem[] };

export function hydratePlan(plan: APIPlan): MealPlan {
  return {
    ...plan,
    basket: plan.basket.map((item) => ({
      ...item,
      pantryStatus: typeof item.pantryStatus === "boolean"
        ? item.pantryStatus ? "already_have" : "needed"
        : item.pantryStatus,
    })),
  };
}
