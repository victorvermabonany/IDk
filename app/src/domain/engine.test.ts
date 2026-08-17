import { describe, expect, it } from "vitest";

import { buildBasket, consolidateIngredients, normalizeIngredientName, solvePackageCount } from "./engine";
import { fixtureGroceryProvider } from "./fixture-provider";
import { DEMO_PRODUCTS, DEMO_STORE } from "./fixtures";
import type { Meal } from "./types";

const meal = (ingredients: Meal["ingredients"], id = "meal"): Meal => ({
  id,
  day: "Monday",
  title: "Test meal",
  description: "",
  servings: 2,
  prepMinutes: 5,
  cookMinutes: 10,
  calories: 400,
  proteinGrams: 30,
  cuisine: "Test",
  tags: ["test"],
  ingredients,
  instructions: [],
  imagePosition: "50% 50%",
});

describe("ingredient normalization and package pricing", () => {
  it("normalizes common onion descriptions to one canonical ingredient", () => {
    expect(normalizeIngredientName("diced yellow onion")).toBe("yellow_onion");
    expect(normalizeIngredientName("medium onion")).toBe("yellow_onion");
  });

  it("consolidates equivalent weight units across meals", () => {
    const result = consolidateIngredients([
      meal([{ ingredientId: "chicken_breast", name: "chicken", quantity: 1, unit: "lb" }], "one"),
      meal([{ ingredientId: "chicken_breast", name: "chicken", quantity: 8, unit: "oz" }], "two"),
    ]);

    expect(result).toEqual([
      expect.objectContaining({
        ingredientId: "chicken_breast",
        quantity: 24,
        unit: "oz",
        mealIds: ["one", "two"],
      }),
    ]);
  });

  it("charges for two whole packages when one package is insufficient", () => {
    const chicken = DEMO_PRODUCTS.find((item) => item.ingredientId === "chicken_breast");
    expect(chicken).toBeDefined();
    expect(solvePackageCount(2.5, "lb", chicken!)).toBe(2);
  });

  it("keeps pantry ingredients in the basket but removes them from the subtotal", async () => {
    const basket = await buildBasket({
      meals: [meal([{ ingredientId: "olive_oil", name: "olive oil", quantity: 2, unit: "tbsp" }])],
      provider: fixtureGroceryProvider,
      storeId: DEMO_STORE.id,
      pantryIngredientIds: ["olive_oil"],
    });

    expect(basket[0]).toMatchObject({
      pantryStatus: "already_have",
      packageCount: 1,
      totalPriceCents: 0,
    });
  });
});
