import { INGREDIENT_ALIASES } from "./fixtures";
import type {
  BasketItem,
  GroceryProvider,
  GroceryRequirement,
  Meal,
  ProviderProduct,
  Unit,
} from "./types";

type Dimension = "weight" | "count" | "volume";

const unitDefinition: Record<Unit, { dimension: Dimension; factor: number }> = {
  oz: { dimension: "weight", factor: 1 },
  lb: { dimension: "weight", factor: 16 },
  count: { dimension: "count", factor: 1 },
  fl_oz: { dimension: "volume", factor: 1 },
  cup: { dimension: "volume", factor: 8 },
  tbsp: { dimension: "volume", factor: 0.5 },
  tsp: { dimension: "volume", factor: 1 / 6 },
};

function cleanName(value: string) {
  return value
    .toLowerCase()
    .replace(/\b(diced|sliced|chopped|fresh|medium|large|small)\b/g, "")
    .replace(/[^a-z0-9]+/g, " ")
    .trim()
    .replace(/\s+/g, " ");
}

export function normalizeIngredientName(value: string) {
  const cleaned = cleanName(value);
  return INGREDIENT_ALIASES[cleaned] ?? cleaned.replaceAll(" ", "_");
}

export function toBaseQuantity(quantity: number, unit: Unit) {
  return quantity * unitDefinition[unit].factor;
}

export function solvePackageCount(
  requiredQuantity: number,
  requiredUnit: Unit,
  product: ProviderProduct,
) {
  const required = unitDefinition[requiredUnit];
  const offered = unitDefinition[product.packageUnit];

  if (required.dimension !== offered.dimension) {
    throw new Error(
      `Cannot match ${requiredUnit} requirement to ${product.packageUnit} package.`,
    );
  }

  const requiredBase = requiredQuantity * required.factor;
  const packageBase = product.packageQuantity * offered.factor;
  return Math.max(1, Math.ceil(requiredBase / packageBase - 1e-9));
}

export function consolidateIngredients(meals: Meal[]): GroceryRequirement[] {
  const grouped = new Map<string, GroceryRequirement & { baseQuantity: number; dimension: Dimension }>();

  for (const meal of meals) {
    for (const ingredient of meal.ingredients) {
      const ingredientId = ingredient.ingredientId || normalizeIngredientName(ingredient.name);
      const definition = unitDefinition[ingredient.unit];
      const baseQuantity = ingredient.quantity * definition.factor;
      const existing = grouped.get(ingredientId);

      if (!existing) {
        grouped.set(ingredientId, {
          ingredientId,
          displayName: ingredient.name,
          quantity: baseQuantity,
          unit: definition.dimension === "weight" ? "oz" : definition.dimension === "volume" ? "fl_oz" : "count",
          mealIds: [meal.id],
          baseQuantity,
          dimension: definition.dimension,
        });
        continue;
      }

      if (existing.dimension !== definition.dimension) {
        throw new Error(`Incompatible units for ${ingredientId}.`);
      }

      existing.baseQuantity += baseQuantity;
      existing.quantity = existing.baseQuantity;
      if (!existing.mealIds.includes(meal.id)) existing.mealIds.push(meal.id);
    }
  }

  return [...grouped.values()].map((item) => ({
    ingredientId: item.ingredientId,
    displayName: item.displayName,
    quantity: item.quantity,
    unit: item.unit,
    mealIds: item.mealIds,
  }));
}

export async function buildBasket(input: {
  meals: Meal[];
  provider: GroceryProvider;
  storeId: string;
  pantryIngredientIds: string[];
}): Promise<BasketItem[]> {
  const pantry = new Set(input.pantryIngredientIds);
  const requirements = consolidateIngredients(input.meals);

  return Promise.all(
    requirements.map(async (requirement) => {
      const products = await input.provider.searchProducts({
        storeId: input.storeId,
        ingredientId: requirement.ingredientId,
      });
      const product = products.find((candidate) => candidate.availability !== "out_of_stock") ?? null;
      const pantryStatus = pantry.has(requirement.ingredientId) ? "already_have" : "needed";
      let packageCount = 0;
      let totalPriceCents: number | null = pantryStatus === "already_have" ? 0 : null;

      if (product) {
        packageCount = solvePackageCount(requirement.quantity, requirement.unit, product);
        if (pantryStatus === "needed") {
          const unitPrice = product.salePriceCents ?? product.regularPriceCents;
          totalPriceCents = packageCount * unitPrice;
        }
      }

      return {
        id: `basket-${requirement.ingredientId}`,
        ingredientId: requirement.ingredientId,
        displayName: requirement.displayName,
        requiredQuantity: requirement.quantity,
        requiredUnit: requirement.unit,
        requiredDisplay: `${Number(requirement.quantity.toFixed(2))} ${requirement.unit.replaceAll("_", " ")}`,
        mealIds: requirement.mealIds,
        product,
        productName: product?.name ?? "Unavailable",
        packageDisplay: product?.displayPackage ?? "Not priced",
        department: product?.department ?? "Other",
        packageCount,
        totalPriceCents,
        pantryStatus,
      } satisfies BasketItem;
    }),
  );
}

export function basketTotal(basket: BasketItem[]) {
  return basket.reduce((total, item) => total + (item.totalPriceCents ?? 0), 0);
}

export function priceCoverage(basket: BasketItem[]) {
  const needed = basket.filter((item) => item.pantryStatus === "needed");
  if (needed.length === 0) return 1;
  return needed.filter((item) => item.totalPriceCents !== null).length / needed.length;
}

export function scaleMeals(meals: Meal[], servings: number, dinnerCount: number) {
  const scale = servings / 2;
  return meals.slice(0, dinnerCount).map((meal) => ({
    ...meal,
    servings,
    ingredients: meal.ingredients.map((ingredient) => ({
      ...ingredient,
      quantity: Number((ingredient.quantity * scale).toFixed(3)),
    })),
  }));
}

export function scaleMeal(meal: Meal, servings: number): Meal {
  const scale = servings / meal.servings;
  return {
    ...meal,
    servings,
    ingredients: meal.ingredients.map((ingredient) => ({
      ...ingredient,
      quantity: Number((ingredient.quantity * scale).toFixed(3)),
    })),
  };
}
