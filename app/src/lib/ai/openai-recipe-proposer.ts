import OpenAI from "openai";
import { zodTextFormat } from "openai/helpers/zod";
import { z } from "zod";

import { DEMO_PRODUCTS } from "../../domain/fixtures";
import { requiredServings } from "../../domain/constraints";
import type { Meal, PlannerRequest, RecipeIngredient } from "../../domain/types";

const schemaProducts = [...new Map(DEMO_PRODUCTS.map((product) => [product.ingredientId, product])).values()];
const ingredientVariants = schemaProducts.map((product) => z.object({
  ingredientId: z.literal(product.ingredientId),
  name: z.string().min(2).max(80),
  quantity: z.number().positive().max(1000),
  unit: z.literal(product.packageUnit),
}));
const catalogIngredientSchema: z.ZodType<RecipeIngredient> = z.discriminatedUnion(
  "ingredientId",
  ingredientVariants as [(typeof ingredientVariants)[number], (typeof ingredientVariants)[number], ...(typeof ingredientVariants)[number][]],
);
const proposalSchema = z.object({
  meals: z.array(z.object({
    day: z.string().min(3).max(12), title: z.string().min(4).max(80), description: z.string().min(20).max(180),
    servings: z.number().int().min(1).max(16), prepMinutes: z.number().int().min(0).max(60),
    cookMinutes: z.number().int().min(1).max(90), calories: z.number().int().min(200).max(1200),
    proteinGrams: z.number().int().min(5).max(120), cuisine: z.string().min(3).max(40),
    tags: z.array(z.string().min(2).max(40)).min(1).max(8),
    ingredients: z.array(catalogIngredientSchema).min(3).max(14),
    instructions: z.array(z.string().min(12).max(300)).min(2).max(8),
  })).min(3).max(12),
});

function slug(value: string) { return value.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, ""); }

export async function proposeMeals(request: PlannerRequest, repairFeedback?: string): Promise<Meal[]> {
  const timeout = Math.min(120_000, Math.max(5_000, Number(process.env.WEEKTABLE_MODEL_TIMEOUT_MS ?? 45_000)));
  const maxOutputTokens = Math.min(12_000, Math.max(1_000, Number(process.env.WEEKTABLE_MODEL_MAX_OUTPUT_TOKENS ?? 6_000)));
  const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY, timeout, maxRetries: 1 });
  const storeProducts = DEMO_PRODUCTS.filter((product) => product.storeId === request.store.id);
  const availableCatalog = storeProducts.map((product) => ({
    ingredientId: product.ingredientId, name: product.name, package: product.displayPackage,
    recipeUnit: product.packageUnit, department: product.department,
  }));
  const candidateCount = Math.min(12, Math.max(request.dinnerCount + 4, 8));
  const response = await openai.responses.parse({
    model: process.env.OPENAI_PLANNER_MODEL ?? "gpt-5.6-luna",
    max_output_tokens: maxOutputTokens,
    input: [
      {
        role: "system",
        content: [
          "You propose diverse practical weeknight dinner candidates for a grocery constraint engine.",
          "Allergies, vegetarian/vegan restrictions, servings, meal candidate count, total cooking time, positive quantities, and catalog ingredient IDs are hard constraints.",
          "Hard constraints always override custom instructions and preferences. Never invent prices, packages, products, availability, or nutrition provenance.",
          "Use only ingredient IDs and recipe units in the supplied selected-store catalog.",
          "Treat prepMinutes plus cookMinutes as total cooking time. Prefer ingredient reuse, complete-package efficiency, cuisine preferences, and the requested nutrition style.",
          "Quick means fewer ingredients and simple methods. Budget-first means low-cost proteins and high reuse. Balanced means reasonable variety. Lighter is a style preference, not calorie restriction.",
          "Return structured recipe facts only.",
        ].join(" "),
      },
      {
        role: "user",
        content: JSON.stringify({
          candidateCount,
          requiredServingsPerDinner: requiredServings(request),
          constraints: request,
          selectedStoreCatalog: availableCatalog,
          repairFeedback: repairFeedback ?? null,
        }),
      },
    ],
    text: { format: zodTextFormat(proposalSchema, "weektable_meal_candidates") },
  }, { timeout });
  const parsed = response.output_parsed;
  if (!parsed || parsed.meals.length < request.dinnerCount) throw new Error("The model did not return enough structured candidates.");
  const imagePositions = ["8% 50%", "20% 50%", "32% 50%", "44% 50%", "56% 50%", "68% 50%", "80% 50%", "92% 50%"];
  return parsed.meals.map((meal, index) => ({ ...meal, id: `${slug(meal.title)}-${index + 1}`, imagePosition: imagePositions[index % imagePositions.length] }));
}
