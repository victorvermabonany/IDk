import { describe, expect, it } from "vitest";
import { mealConstraintIssues, validatePlanOrThrow } from "./constraints";
import { DEMO_MEALS, INGREDIENT_DIETARY_TRAITS, VALUE_STORE } from "./fixtures";
import { DEFAULT_PLANNER_REQUEST, generatePlan } from "./planner-service";
import { createSwapPreviews } from "./swap-service";
import type { Meal, PlannerRequest } from "./types";

const request = (overrides: Partial<PlannerRequest> = {}): PlannerRequest => ({
  ...structuredClone(DEFAULT_PLANNER_REQUEST), ...overrides,
});
describe("canonical planner constraint matrix", () => {
  it("generates vegetarian meals with no meat", async () => {
    const plan = await generatePlan(request({ nutritionStyle: "vegetarian" }));
    expect(plan.meals).toHaveLength(5);
    expect(plan.meals.flatMap((meal) => meal.ingredients).some((item) => (INGREDIENT_DIETARY_TRAITS[item.ingredientId] ?? []).includes("meat"))).toBe(false);
  }, 30_000);

  it("composes vegetarian and high-protein constraints", async () => {
    const plan = await generatePlan(request({ nutritionStyle: "high-protein", dietaryRestrictions: ["vegetarian"] }));
    expect(plan.meals.flatMap((meal) => meal.ingredients).some((item) => (INGREDIENT_DIETARY_TRAITS[item.ingredientId] ?? []).includes("meat"))).toBe(false);
    expect(plan.meals.reduce((sum, meal) => sum + meal.proteinGrams, 0) / plan.meals.length).toBeGreaterThanOrEqual(25);
  }, 30_000);

  it("generates vegan meals without animal-derived ingredients", async () => {
    const plan = await generatePlan(request({ dietaryRestrictions: ["vegan"], dinnerCount: 7, budgetCents: 15_000 }));
    expect(plan.meals).toHaveLength(7);
    expect(plan.meals.flatMap((meal) => meal.ingredients).some((item) => (INGREDIENT_DIETARY_TRAITS[item.ingredientId] ?? []).includes("animal-derived"))).toBe(false);
  }, 30_000);

  it("rejects allergy and disliked-food violations", () => {
    const peanutMeal: Meal = { ...DEMO_MEALS[0], servings: 2, ingredients: [{ ingredientId: "peanut_butter", name: "peanut butter", quantity: 2, unit: "oz" }] };
    expect(mealConstraintIssues(peanutMeal, request({ allergies: ["peanut"] })).join(" ")).toContain("allergy");
    expect(mealConstraintIssues(DEMO_MEALS[0], request({ dislikedFoods: ["zucchini"] })).join(" ")).toContain("disliked");
  });

  it("scales requirements for household size and leftovers", async () => {
    const two = await generatePlan(request({ householdSize: 2, dinnerCount: 3, budgetCents: 15_000 }));
    const five = await generatePlan(request({ householdSize: 5, dinnerCount: 3, budgetCents: 30_000 }));
    const leftover = await generatePlan(request({ householdSize: 2, dinnerCount: 3, budgetCents: 15_000, leftovers: { enabled: true, extraServings: 1 } }));
    expect(five.meals.every((meal) => meal.servings === 5)).toBe(true);
    expect(five.basket.reduce((sum, item) => sum + item.requiredQuantity, 0)).toBeGreaterThan(two.basket.reduce((sum, item) => sum + item.requiredQuantity, 0));
    expect(leftover.meals.every((meal) => meal.servings === 3)).toBe(true);
  }, 30_000);

  it.each([3, 5, 7])("returns exactly %i dinners", async (dinnerCount) => {
    const plan = await generatePlan(request({ dinnerCount, budgetCents: 20_000 }));
    expect(plan.meals).toHaveLength(dinnerCount);
  }, 30_000);

  it("adapts to budget instead of returning an over-budget plan", async () => {
    const high = await generatePlan(request({ dinnerCount: 3, budgetCents: 15_000 }));
    const low = await generatePlan(request({ dinnerCount: 3, budgetCents: 6_000, nutritionStyle: "budget-first" }));
    expect(low.estimatedTotalCents).toBeLessThanOrEqual(6_000);
    expect(low.estimatedTotalCents).toBeLessThanOrEqual(high.estimatedTotalCents);
  }, 30_000);

  it("enforces total cooking time and custom no-oven instructions", () => {
    const slow = { ...DEMO_MEALS[0], servings: 2, prepMinutes: 15, cookMinutes: 30 };
    expect(() => validatePlanOrThrow([slow, { ...slow, id: "2", title: "Two" }, { ...slow, id: "3", title: "Three" }], request({ dinnerCount: 3, maxCookingMinutes: 30 }))).toThrow(/30 total minutes/);
    const ovenMeal = { ...DEMO_MEALS[0], instructions: ["Roast everything in the oven until browned.", "Serve immediately while hot."] };
    expect(mealConstraintIssues(ovenMeal, request({ customInstructions: "Don't use an oven." })).join(" ")).toContain("no-oven");
  });

  it("removes pantry items from the authoritative subtotal", async () => {
    const withoutRice = await generatePlan(request({ dinnerCount: 3, pantryItems: [] }));
    const withRice = await generatePlan(request({ dinnerCount: 3, pantryItems: ["rice"] }));
    expect(withRice.basket.find((item) => item.ingredientId === "brown_rice")?.totalPriceCents ?? 0).toBe(0);
    expect(withRice.estimatedTotalCents).toBeLessThanOrEqual(withoutRice.estimatedTotalCents);
  }, 30_000);

  it("scopes prices and products to the selected store location", async () => {
    const primary = await generatePlan(request({ dinnerCount: 3 }));
    const value = await generatePlan(request({ dinnerCount: 3, store: { id: VALUE_STORE.id, locationId: VALUE_STORE.providerStoreId, postalCode: "45202" } }));
    expect(value.store.id).toBe(VALUE_STORE.id);
    expect(value.basket.every((item) => item.product?.storeId === VALUE_STORE.id)).toBe(true);
    expect(value.estimatedTotalCents).not.toBe(primary.estimatedTotalCents);
  }, 30_000);

  it("keeps swap candidates inside the original hard constraints and budget", async () => {
    const plan = await generatePlan(request({ nutritionStyle: "high-protein", dietaryRestrictions: ["vegetarian"], allergies: ["peanut"], maxCookingMinutes: 30 }));
    const previews = await createSwapPreviews(plan, plan.meals[0].id);
    expect(previews.length).toBeGreaterThan(0);
    for (const preview of previews) {
      expect(mealConstraintIssues(preview.meal, plan.constraintsUsed)).toEqual([]);
      expect(preview.resultingTotalCents).toBeLessThanOrEqual(plan.budgetCents);
    }
  }, 30_000);

  it("satisfies a composed multi-constraint request and snapshots it", async () => {
    const constraints = request({
      budgetCents: 8_500, householdSize: 3, dinnerCount: 5, nutritionStyle: "high-protein",
      dietaryRestrictions: ["vegetarian"], dislikedFoods: ["mushrooms"], allergies: ["peanut"],
      maxCookingMinutes: 30, pantryItems: ["rice"],
    });
    const plan = await generatePlan(constraints);
    validatePlanOrThrow(plan.meals, constraints);
    expect(plan.estimatedTotalCents).toBeLessThanOrEqual(8_500);
    expect(plan.basket.find((item) => item.ingredientId === "brown_rice")?.totalPriceCents ?? 0).toBe(0);
    expect(plan.constraintsUsed).toEqual(constraints);
  }, 30_000);

  it("passes release scenarios A through D and rejects the intentionally impossible scenario E", async () => {
    const scenarios = [
      request({ budgetCents: 6_000, householdSize: 1, dinnerCount: 3, nutritionStyle: "quick", dietaryRestrictions: ["vegetarian"], maxCookingMinutes: 30 }),
      request({ budgetCents: 12_000, householdSize: 2, dinnerCount: 5, nutritionStyle: "high-protein", dislikedFoods: ["seafood"] }),
      request({ budgetCents: 8_500, householdSize: 3, dinnerCount: 5, nutritionStyle: "high-protein", dietaryRestrictions: ["vegetarian"], dislikedFoods: ["mushrooms"], maxCookingMinutes: 30, pantryItems: ["rice"] }),
      request({ budgetCents: 15_000, householdSize: 4, dinnerCount: 7, nutritionStyle: "balanced", dietaryRestrictions: ["dairy-free"] }),
    ];

    for (const constraints of scenarios) {
      const plan = await generatePlan(constraints);
      validatePlanOrThrow(plan.meals, constraints);
      expect(plan.meals).toHaveLength(constraints.dinnerCount);
      expect(plan.meals.every((meal) => meal.servings === constraints.householdSize)).toBe(true);
      expect(plan.estimatedTotalCents).toBeLessThanOrEqual(constraints.budgetCents);
    }

    await expect(generatePlan(request({ budgetCents: 100, householdSize: 8, dinnerCount: 7, dietaryRestrictions: ["vegan"], maxCookingMinutes: 15 }))).rejects.toThrow();
  }, 30_000);
});
