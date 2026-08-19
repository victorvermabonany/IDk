import { describe, expect, it } from "vitest";

import { mealSimilarity, mealVarietyReport, normalizeMealTitle, prepareMealContent, type MealVarietyReport } from "./meal-quality";
import { DEFAULT_PLANNER_REQUEST, generatePlan } from "./planner-service";
import { createSwapPreviews } from "./swap-service";
import { DEMO_MEALS } from "./fixtures";
import type { MealPlan, PlannerRequest } from "./types";

function request(overrides: Partial<PlannerRequest>): PlannerRequest {
  return { ...structuredClone(DEFAULT_PLANNER_REQUEST), ...overrides };
}

function maximumUse(counts: Record<string, number>) {
  return Math.max(0, ...Object.values(counts));
}

function summary(name: string, plan: MealPlan, report: MealVarietyReport) {
  return {
    name,
    titles: plan.meals.map((meal) => meal.title),
    repeatedPrimaryProteins: Object.fromEntries(Object.entries(report.primaryProteins).filter(([, count]) => count > 1)),
    repeatedStarches: Object.fromEntries(Object.entries(report.primaryStarches).filter(([, count]) => count > 1)),
    repeatedFormats: Object.fromEntries(Object.entries(report.mealFormats).filter(([, count]) => count > 1)),
    repeatedCuisines: Object.fromEntries(Object.entries(report.cuisines).filter(([, count]) => count > 1)),
    repeatedFlavors: Object.fromEntries(Object.entries(report.flavorProfiles).filter(([, count]) => count > 1)),
    uniqueIngredientCount: report.uniqueIngredientCount,
    ingredientOverlap: report.ingredientOverlap,
    basketCostCents: plan.estimatedTotalCents,
    budgetCents: plan.budgetCents,
    budgetPasses: plan.estimatedTotalCents <= plan.budgetCents,
  };
}

describe("meal quality and content integrity", () => {
  it("keeps the five requested scenarios varied, reusable, and within budget", async () => {
    const scenarios: Record<string, PlannerRequest> = {
      "A · vegetarian high protein": request({ nutritionStyle: "high-protein", dietaryRestrictions: ["vegetarian"], dinnerCount: 5, budgetCents: 10_000 }),
      "B · vegetarian low budget": request({ nutritionStyle: "vegetarian", dinnerCount: 5, budgetCents: 6_000 }),
      "C · unrestricted balanced": request({ nutritionStyle: "balanced", dietaryRestrictions: [], dinnerCount: 7, budgetCents: 15_000 }),
      "D · Mexican preferred": request({ nutritionStyle: "balanced", preferredCuisines: ["Mexican"], dinnerCount: 5, budgetCents: 10_000 }),
      "E · high protein, no seafood": request({ nutritionStyle: "high-protein", dislikedFoods: ["seafood"], dinnerCount: 5, budgetCents: 10_000 }),
    };

    for (const [name, constraints] of Object.entries(scenarios)) {
      const plan = await generatePlan(constraints);
      const report = mealVarietyReport(plan.meals, constraints);
      console.log(JSON.stringify(summary(name, plan, report)));

      expect(plan.estimatedTotalCents).toBeLessThanOrEqual(plan.budgetCents);
      expect(plan.meals).toHaveLength(constraints.dinnerCount);
      expect(report.ingredientOverlap).toBeGreaterThan(0);
      expect(maximumUse(report.mealFormats)).toBeLessThanOrEqual(2);
      expect(plan.meals.every((meal) => meal.title.length <= 52 && meal.title.split(" ").length <= 8)).toBe(true);
      expect(plan.meals.every((meal) => meal.imageMatch === "exact" && Boolean(meal.imageKey))).toBe(true);
    }

    const vegetarianProtein = await generatePlan(scenarios["A · vegetarian high protein"]);
    const vegetarianReport = mealVarietyReport(vegetarianProtein.meals, vegetarianProtein.constraintsUsed);
    expect(maximumUse(vegetarianReport.primaryProteins)).toBeLessThanOrEqual(2);
    expect(maximumUse(vegetarianReport.primaryStarches)).toBeLessThanOrEqual(2);
    expect(vegetarianProtein.meals.reduce((sum, meal) => sum + meal.proteinGrams, 0) / vegetarianProtein.meals.length).toBeGreaterThanOrEqual(25);

    const lowBudget = await generatePlan(scenarios["B · vegetarian low budget"]);
    const lowBudgetReport = mealVarietyReport(lowBudget.meals, lowBudget.constraintsUsed);
    expect(maximumUse(lowBudgetReport.primaryProteins)).toBeLessThanOrEqual(2);
    expect(lowBudgetReport.ingredientOverlap).toBeGreaterThanOrEqual(8);

    const unrestricted = await generatePlan(scenarios["C · unrestricted balanced"]);
    const unrestrictedReport = mealVarietyReport(unrestricted.meals, unrestricted.constraintsUsed);
    expect(Object.keys(unrestrictedReport.mealFormats)).toHaveLength(6);
    expect(maximumUse(unrestrictedReport.primaryProteins)).toBeLessThanOrEqual(2);

    const mexican = await generatePlan(scenarios["D · Mexican preferred"]);
    const mexicanReport = mealVarietyReport(mexican.meals, mexican.constraintsUsed);
    expect(mexican.meals.filter((meal) => meal.cuisine.toLowerCase().includes("mexican"))).toHaveLength(2);
    expect(Object.keys(mexicanReport.mealFormats).length).toBeGreaterThanOrEqual(4);

    const noSeafood = await generatePlan(scenarios["E · high protein, no seafood"]);
    expect(maximumUse(mealVarietyReport(noSeafood.meals, noSeafood.constraintsUsed).primaryProteins)).toBeLessThanOrEqual(2);
  }, 30_000);

  it("uses exact or defensible category images and falls back for an unsupported dish", () => {
    const exact = prepareMealContent(DEMO_MEALS[0]);
    expect(exact).toMatchObject({ imageMatch: "exact", imageKey: "meal-pesto-rigatoni" });

    const generatedTacos = prepareMealContent({ ...DEMO_MEALS[1], id: "generated-chicken-tacos" });
    expect(generatedTacos).toMatchObject({ imageMatch: "category", imageKey: "meal-crispy-chicken-tacos" });

    const stuffedPeppers = prepareMealContent({
      ...DEMO_MEALS.find((meal) => meal.id === "lentil-rice-stuffed-peppers")!,
      id: "generated-stuffed-peppers",
      title: "Lentil Rice Stuffed Peppers",
      description: "Baked peppers filled with lentils and rice.",
      instructions: ["Fill the peppers with lentils and rice.", "Bake the stuffed peppers until tender."],
    });
    expect(stuffedPeppers).toMatchObject({ imageMatch: "fallback", imageKey: undefined });
  });

  it("shortens verbose AI-style titles without adding truncation text", () => {
    expect(normalizeMealTitle("Crispy Tofu and Black Bean Tacos with Lime Slaw and Herb Sauce")).toBe("Crispy Tofu and Black Bean Tacos");
    expect(normalizeMealTitle("Chickpea Coconut Curry")).toBe("Chickpea Coconut Curry");
  });

  it("returns swap options that differ from the current week and from each other", async () => {
    const plan = await generatePlan(request({ nutritionStyle: "high-protein", dietaryRestrictions: ["vegetarian"], dinnerCount: 5, budgetCents: 10_000 }));
    const current = plan.meals[0];
    const previews = await createSwapPreviews(plan, current.id);
    expect(previews.length).toBeGreaterThanOrEqual(2);
    for (const preview of previews) {
      expect(mealSimilarity(preview.meal, current)).toBeLessThan(0.72);
      expect(plan.meals.filter((meal) => meal.id !== current.id).every((meal) => mealSimilarity(preview.meal, meal) < 0.82)).toBe(true);
      expect(preview.resultingTotalCents).toBeLessThanOrEqual(plan.budgetCents);
    }
    for (let left = 0; left < previews.length; left += 1) {
      for (let right = left + 1; right < previews.length; right += 1) {
        expect(mealSimilarity(previews[left].meal, previews[right].meal)).toBeLessThan(0.72);
      }
    }
  }, 30_000);
});
