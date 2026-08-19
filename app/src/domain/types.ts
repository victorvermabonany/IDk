import { z } from "zod";

export const unitSchema = z.enum(["oz", "lb", "count", "fl_oz", "cup", "tbsp", "tsp"]);
export type Unit = z.infer<typeof unitSchema>;

const normalizedStringArray = (maximum: number) =>
  z.array(z.string().trim().min(1).max(80)).max(maximum).default([])
    .transform((items) => [...new Set(items.map((item) => item.toLowerCase()))]);

export const plannerRequestSchema = z.object({
  store: z.object({
    id: z.string().min(1).max(120),
    locationId: z.string().min(1).max(120),
    postalCode: z.string().regex(/^\d{5}$/, "Enter a five-digit ZIP code."),
  }).strict(),
  budgetCents: z.number().int().min(2_000).max(50_000),
  householdSize: z.number().int().min(1).max(8),
  dinnerCount: z.number().int().min(3).max(7),
  leftovers: z.object({
    enabled: z.boolean(),
    extraServings: z.number().int().min(0).max(8),
  }).superRefine((value, context) => {
    if (!value.enabled && value.extraServings !== 0) context.addIssue({ code: "custom", message: "Disabled leftovers cannot add servings." });
    if (value.enabled && value.extraServings < 1) context.addIssue({ code: "custom", message: "Enabled leftovers require at least one extra serving." });
  }),
  nutritionStyle: z.enum(["balanced", "high-protein", "vegetarian", "quick", "budget-first", "lighter"]),
  dietaryRestrictions: normalizedStringArray(12),
  allergies: normalizedStringArray(12),
  dislikedFoods: normalizedStringArray(20),
  preferredCuisines: normalizedStringArray(10),
  maxCookingMinutes: z.number().int().min(15).max(90),
  pantryItems: normalizedStringArray(50),
  customInstructions: z.string().trim().max(400).default(""),
}).strict();

export type PlannerRequest = z.infer<typeof plannerRequestSchema>;
export type Department = "Produce" | "Meat" | "Dairy & eggs" | "Pantry" | "Canned goods" | "Bakery" | "Seasonings" | "Other";

export interface RecipeIngredient { ingredientId: string; name: string; quantity: number; unit: Unit; }
export interface Meal {
  id: string; day: string; title: string; description: string; servings: number;
  prepMinutes: number; cookMinutes: number; calories: number; proteinGrams: number;
  cuisine: string; tags: string[]; ingredients: RecipeIngredient[]; instructions: string[]; imagePosition: string;
  imageKey?: string; imageMatch?: "exact" | "category" | "fallback";
}
export interface ProviderStore {
  id: string; providerStoreId: string; name: string; retailer: string; address: string; zipCode: string;
  priceKind: "live" | "feed" | "estimated" | "fixture";
}
export interface ProviderProduct {
  id: string; ingredientId: string; provider: string; providerProductId: string; storeId: string;
  name: string; brand: string; displayPackage: string; packageQuantity: number; packageUnit: Unit;
  regularPriceCents: number; salePriceCents: number | null; availability: "in_stock" | "out_of_stock" | "unknown";
  department: Department; priceKind: "live" | "feed" | "estimated" | "fixture"; observedAt: string;
}
export interface PricingProvenance {
  pricingMode: "live" | "estimated" | "fixture";
  provider: "kroger" | "cove_estimate" | "fixture";
  providerName: string;
  storeName: string;
  providerStoreId: string;
  updatedAt: string;
}
export interface GroceryProvider {
  readonly id: string; readonly displayName: string;
  findStores(zipCode: string): Promise<ProviderStore[]>;
  searchProducts(input: { storeId: string; ingredientId: string }): Promise<ProviderProduct[]>;
  getProduct(input: { storeId: string; productId: string }): Promise<ProviderProduct | null>;
}
export interface GroceryRequirement { ingredientId: string; displayName: string; quantity: number; unit: Unit; mealIds: string[]; }
export interface BasketItem {
  id: string; ingredientId: string; displayName: string; requiredQuantity: number; requiredUnit: Unit;
  requiredDisplay: string; mealIds: string[]; product: ProviderProduct | null; productName: string;
  packageDisplay: string; department: Department; packageCount: number; totalPriceCents: number | null;
  pantryStatus: "needed" | "already_have";
}
export interface MealPlan {
  id: string; title: string; store: ProviderStore; constraintsUsed: PlannerRequest; budgetCents: number;
  internalTargetCents: number; estimatedTotalCents: number; priceCoverage: number;
  priceKind: ProviderStore["priceKind"]; priceObservedAt: string; meals: Meal[]; basket: BasketItem[];
  pricingProvenance: PricingProvenance;
  createdAt: string; safetyNotice: string;
}
export interface SwapPreview {
  id: string; meal: Meal; deltaCents: number; reusedIngredientCount: number; resultingTotalCents: number;
}

export class PlanGenerationError extends Error {
  constructor(
    public readonly code: "CONSTRAINT_CONFLICT" | "UNPRICED_BASKET" | "BUDGET_TOO_LOW" | "PROVIDER_UNAVAILABLE" | "MODEL_FAILURE",
    message: string,
    public readonly suggestions: string[] = [],
  ) { super(message); this.name = "PlanGenerationError"; }
}
