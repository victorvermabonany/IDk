import { describe, expect, it } from "vitest";
import { DEMO_MEALS } from "./fixtures";
import { HIGH_PROTEIN_ACCEPTABLE_MINIMUM_GRAMS, HIGH_PROTEIN_IDEAL_GRAMS, validateHighProteinTarget, weeklyNutritionSummary } from "./nutrition";
import type { Meal, NutritionProvenance } from "./types";

const authoritative: NutritionProvenance = { kind: "authoritative", source: "verified-nutrition-dataset" };

function macros(protein: number): Meal {
  return { ...DEMO_MEALS[0], id: `protein-${protein}`, proteinGrams: protein, carbohydrateGrams: 52, fatGrams: 18, fiberGrams: 9 };
}

describe("authoritative nutrition gates", () => {
  it("enforces the measurable high-protein dinner target only for authoritative data", () => {
    const passing = validateHighProteinTarget([macros(30), macros(35), macros(40)], authoritative);
    expect(passing.supported).toBe(true);
    expect(passing.meetsTarget).toBe(true);
    expect(passing.averageProteinGrams).toBe(HIGH_PROTEIN_IDEAL_GRAMS);

    const low = validateHighProteinTarget([macros(HIGH_PROTEIN_ACCEPTABLE_MINIMUM_GRAMS - 1), macros(41)], authoritative);
    expect(low.meetsTarget).toBe(false);
    expect(low.mealsBelowAcceptableMinimum).toEqual([`protein-${HIGH_PROTEIN_ACCEPTABLE_MINIMUM_GRAMS - 1}`]);

    expect(validateHighProteinTarget([macros(40)], { kind: "unverified", source: "model" })).toMatchObject({ supported: false, meetsTarget: false });
  });

  it("builds all five weekly macros only from complete authoritative data", () => {
    expect(weeklyNutritionSummary([macros(35), macros(39)], authoritative)).toEqual({
      averageCaloriesPerServing: DEMO_MEALS[0].calories,
      averageProteinGramsPerServing: 37,
      averageCarbohydrateGramsPerServing: 52,
      averageFatGramsPerServing: 18,
      averageFiberGramsPerServing: 9,
    });
    expect(weeklyNutritionSummary([macros(35)], { kind: "unverified", source: "model" })).toBeUndefined();
  });
});
