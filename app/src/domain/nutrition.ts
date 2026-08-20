import type { Meal, NutritionProvenance, WeeklyNutritionSummary } from "./types";

export const HIGH_PROTEIN_IDEAL_GRAMS = 35;
export const HIGH_PROTEIN_ACCEPTABLE_MINIMUM_GRAMS = 30;

export interface HighProteinValidation {
  supported: boolean;
  meetsTarget: boolean;
  averageProteinGrams: number | null;
  mealsBelowAcceptableMinimum: string[];
}

export function validateHighProteinTarget(
  meals: Meal[],
  provenance?: NutritionProvenance,
): HighProteinValidation {
  if (provenance?.kind !== "authoritative" || meals.length === 0) {
    return { supported: false, meetsTarget: false, averageProteinGrams: null, mealsBelowAcceptableMinimum: [] };
  }
  const averageProteinGrams = meals.reduce((total, meal) => total + meal.proteinGrams, 0) / meals.length;
  const mealsBelowAcceptableMinimum = meals
    .filter((meal) => meal.proteinGrams < HIGH_PROTEIN_ACCEPTABLE_MINIMUM_GRAMS)
    .map((meal) => meal.id);
  return {
    supported: true,
    meetsTarget: averageProteinGrams >= HIGH_PROTEIN_IDEAL_GRAMS && mealsBelowAcceptableMinimum.length === 0,
    averageProteinGrams,
    mealsBelowAcceptableMinimum,
  };
}

export function weeklyNutritionSummary(
  meals: Meal[],
  provenance?: NutritionProvenance,
): WeeklyNutritionSummary | undefined {
  if (provenance?.kind !== "authoritative" || meals.length === 0) return undefined;
  if (meals.some((meal) => meal.carbohydrateGrams === undefined || meal.fatGrams === undefined || meal.fiberGrams === undefined)) return undefined;
  const average = (values: number[]) => Math.round(values.reduce((sum, value) => sum + value, 0) / values.length);
  return {
    averageCaloriesPerServing: average(meals.map((meal) => meal.calories)),
    averageProteinGramsPerServing: average(meals.map((meal) => meal.proteinGrams)),
    averageCarbohydrateGramsPerServing: average(meals.map((meal) => meal.carbohydrateGrams!)),
    averageFatGramsPerServing: average(meals.map((meal) => meal.fatGrams!)),
    averageFiberGramsPerServing: average(meals.map((meal) => meal.fiberGrams!)),
  };
}
