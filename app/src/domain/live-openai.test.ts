import { expect, it } from "vitest";
import { validatePlanOrThrow } from "./constraints";
import { DEFAULT_PLANNER_REQUEST, generatePlan } from "./planner-service";

const liveTest = process.env.RUN_LIVE_OPENAI_TESTS === "true" ? it : it.skip;

liveTest("generates and validates a live multi-constraint week", async () => {
  const constraints = {
    ...structuredClone(DEFAULT_PLANNER_REQUEST),
    budgetCents: 8_500,
    householdSize: 3,
    dinnerCount: 5,
    nutritionStyle: "high-protein" as const,
    dietaryRestrictions: ["vegetarian"],
    allergies: ["peanut"],
    dislikedFoods: ["mushrooms"],
    maxCookingMinutes: 30,
    pantryItems: ["rice"],
    customInstructions: "Keep the meals mild and do not use an oven.",
  };
  const plan = await generatePlan(constraints);
  validatePlanOrThrow(plan.meals, constraints);
  expect(plan.meals).toHaveLength(5);
  expect(plan.meals.every((meal) => meal.servings === 3)).toBe(true);
  expect(plan.meals.every((meal) => meal.prepMinutes + meal.cookMinutes <= 30)).toBe(true);
  expect(plan.meals.flatMap((meal) => meal.ingredients).every((ingredient) => !/(chicken|turkey|sausage|beef|pork|fish|shellfish|peanut|mushroom)/i.test(`${ingredient.ingredientId} ${ingredient.name}`))).toBe(true);
  expect(plan.meals.flatMap((meal) => meal.instructions).every((instruction) => !/oven|bake|roast|sheet[ -]?pan/i.test(instruction))).toBe(true);
  expect(plan.estimatedTotalCents).toBeLessThanOrEqual(8_500);
  expect(plan.basket.find((item) => item.ingredientId === "brown_rice")?.pantryStatus).toBe("already_have");
  expect(plan.basket.every((item) => item.product !== null && item.packageCount > 0)).toBe(true);
  expect(plan.meals.every((meal) => meal.instructions.length >= 2 && meal.ingredients.length >= 3)).toBe(true);
  expect(plan.constraintsUsed).toEqual(constraints);
}, 180_000);
