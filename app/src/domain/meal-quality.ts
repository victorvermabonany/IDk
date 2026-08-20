import type { Meal, PlannerRequest } from "./types";

const STAPLES = new Set(["olive_oil", "kosher_salt", "black_pepper"]);

const PROTEINS: Record<string, string> = {
  chicken_breast: "chicken",
  ground_turkey: "turkey",
  chicken_sausage: "chicken sausage",
  extra_firm_tofu: "tofu",
  dry_lentils: "lentils",
  chickpeas: "chickpeas",
  black_beans: "black beans",
  eggs: "eggs",
};

const STARCHES: Record<string, string> = {
  rigatoni: "pasta",
  brown_rice: "rice",
  quinoa: "quinoa",
  flour_tortillas: "tortillas",
  corn_tortillas: "tortillas",
  sweet_potato: "sweet potato",
};

const VEGETABLES: Record<string, string> = {
  bell_pepper: "bell pepper",
  broccoli: "broccoli",
  baby_spinach: "spinach",
  zucchini: "zucchini",
  sweet_potato: "sweet potato",
  crushed_tomatoes: "tomato",
  romaine: "romaine",
  yellow_onion: "onion",
};

const EXACT_IMAGE_KEYS: Record<string, string> = {
  "pesto-rigatoni": "meal-pesto-rigatoni",
  "crispy-chicken-tacos": "meal-crispy-chicken-tacos",
  "turkey-rice-bowls": "meal-turkey-rice-bowls",
  "smoky-turkey-chili": "meal-smoky-turkey-chili",
  "sausage-pepper-pan": "meal-sausage-peppers",
  "turkey-tomato-rigatoni": "meal-turkey-rigatoni",
  "bean-pepper-quesadillas": "meal-black-bean-quesadillas",
  "tofu-rice-bowls": "meal-tofu-rice-bowls",
  "lentil-tomato-bowls": "meal-lentil-tomato-bowls",
  "chickpea-coconut-curry": "meal-chickpea-coconut-curry",
  "sweet-potato-black-bean-tacos": "meal-sweet-potato-black-bean-tacos",
  "mediterranean-chickpea-quinoa": "meal-mediterranean-chickpea-quinoa",
  "tofu-quinoa-skillet": "meal-tofu-quinoa-skillet",
  "lentil-rice-stuffed-peppers": "meal-lentil-rice-pepper-bowls",
  "egg-quinoa-vegetable-bowls": "meal-egg-quinoa-vegetable-bowls",
};

export interface MealQualityProfile {
  primaryProtein: string;
  primaryStarch: string;
  dominantVegetable: string;
  cookingMethod: string;
  cuisine: string;
  flavorProfile: string;
  mealFormat: string;
}

export interface MealVarietyReport {
  primaryProteins: Record<string, number>;
  primaryStarches: Record<string, number>;
  dominantVegetables: Record<string, number>;
  cookingMethods: Record<string, number>;
  cuisines: Record<string, number>;
  flavorProfiles: Record<string, number>;
  mealFormats: Record<string, number>;
  uniqueIngredientCount: number;
  ingredientOverlap: number;
  reuseScore: number;
  varietyScore: number;
}

function firstIngredientGroup(meal: Meal, groups: Record<string, string>, fallback: string) {
  for (const ingredient of meal.ingredients) {
    const group = groups[ingredient.ingredientId];
    if (group) return group;
  }
  return fallback;
}

function mealText(meal: Meal) {
  return `${meal.title} ${meal.description} ${meal.instructions.join(" ")}`.toLowerCase();
}

function mealFormat(meal: Meal) {
  const text = mealText(meal);
  if (/stuffed\s+(pepper|vegetable)/.test(text)) return "stuffed vegetables";
  if (/quesadilla/.test(text)) return "quesadillas";
  if (/taco/.test(text)) return "tacos";
  if (/wrap/.test(text)) return "wraps";
  if (/curry/.test(text)) return "curry";
  if (/chili/.test(text)) return "chili";
  if (/pasta|rigatoni|spaghetti|noodle/.test(text)) return "pasta";
  if (/sheet[ -]?pan/.test(text)) return "sheet pan";
  if (/skillet/.test(text)) return "skillet";
  if (/soup|stew/.test(text)) return "soup or stew";
  if (/salad/.test(text)) return "salad";
  if (/bowl/.test(text)) return "bowls";
  if (meal.ingredients.some((item) => item.ingredientId === "brown_rice" || item.ingredientId === "quinoa")) return "grain bowls";
  return "plated dinner";
}

function cookingMethod(meal: Meal) {
  const text = mealText(meal);
  if (/sheet[ -]?pan|roast|oven|bake/.test(text)) return "roasted";
  if (/grill/.test(text)) return "grilled";
  if (/simmer|stew|chili|curry/.test(text)) return "simmered";
  if (/sear|saut[eé]|skillet|pan-fry|crisp/.test(text)) return "skillet-cooked";
  if (/boil|cook the (rice|quinoa|pasta|rigatoni)/.test(text)) return "boiled";
  return "mixed method";
}

function flavorProfile(meal: Meal) {
  const ids = new Set(meal.ingredients.map((item) => item.ingredientId));
  const cuisine = meal.cuisine.toLowerCase().replace(/[- ]inspired/g, "").trim();
  if (ids.has("basil_pesto")) return "herby pesto";
  if (ids.has("soy_sauce")) return "savory soy";
  if (ids.has("coconut_milk")) return "creamy coconut spice";
  if (ids.has("smoked_paprika")) return "smoky paprika";
  if (ids.has("lime") && cuisine.includes("mexican")) return "bright lime";
  if (ids.has("crushed_tomatoes") && cuisine.includes("italian")) return "tomato herb";
  if (ids.has("cheddar") || ids.has("greek_yogurt")) return "creamy savory";
  return cuisine || "savory";
}

export function profileMeal(meal: Meal): MealQualityProfile {
  return {
    primaryProtein: firstIngredientGroup(meal, PROTEINS, "other"),
    primaryStarch: firstIngredientGroup(meal, STARCHES, "none"),
    dominantVegetable: firstIngredientGroup(meal, VEGETABLES, "none"),
    cookingMethod: cookingMethod(meal),
    cuisine: meal.cuisine.toLowerCase().replace(/[- ]inspired/g, "").trim() || "other",
    flavorProfile: flavorProfile(meal),
    mealFormat: mealFormat(meal),
  };
}

function countValues(values: string[]) {
  const counts: Record<string, number> = {};
  for (const value of values) counts[value] = (counts[value] ?? 0) + 1;
  return counts;
}

function escalatingRepeatPenalty(counts: Record<string, number>, weight: number) {
  return Object.values(counts).reduce((total, count) => {
    let penalty = 0;
    for (let use = 2; use <= count; use += 1) penalty += weight * (use - 1) ** 2;
    return total + penalty;
  }, 0);
}

export function meaningfulIngredientIDs(meals: Meal[]) {
  return meals.flatMap((meal) => meal.ingredients.map((item) => item.ingredientId)).filter((id) => !STAPLES.has(id));
}

function ingredientReuseScore(meals: Meal[]) {
  const counts = countValues(meaningfulIngredientIDs(meals));
  return Object.values(counts).reduce((score, count) => {
    if (count < 2) return score;
    const usefulReuse = 5 + Math.max(0, Math.min(count, 3) - 2) * 2;
    const excessiveReuse = count > 3 ? (count - 3) ** 2 * 3 : 0;
    return score + usefulReuse - excessiveReuse;
  }, 0);
}

function rawVarietyScore(profiles: MealQualityProfile[], request: PlannerRequest) {
  const proteins = countValues(profiles.map((profile) => profile.primaryProtein));
  const starches = countValues(profiles.map((profile) => profile.primaryStarch));
  const vegetables = countValues(profiles.map((profile) => profile.dominantVegetable));
  const methods = countValues(profiles.map((profile) => profile.cookingMethod));
  const cuisines = countValues(profiles.map((profile) => profile.cuisine));
  const flavors = countValues(profiles.map((profile) => profile.flavorProfile));
  const formats = countValues(profiles.map((profile) => profile.mealFormat));
  const uniquenessReward = new Set(profiles.map((profile) => profile.primaryProtein)).size * 3
    + new Set(profiles.map((profile) => profile.primaryStarch)).size * 2
    + new Set(profiles.map((profile) => profile.mealFormat)).size * 4
    + new Set(profiles.map((profile) => profile.flavorProfile)).size * 3
    + new Set(profiles.map((profile) => profile.cookingMethod)).size * 2
    + new Set(profiles.map((profile) => profile.cuisine)).size * (request.preferredCuisines.length === 0 ? 2 : 0.5);
  const repetitionPenalty = escalatingRepeatPenalty(proteins, 4)
    + escalatingRepeatPenalty(starches, 3)
    + escalatingRepeatPenalty(vegetables, 2)
    + escalatingRepeatPenalty(methods, 2.5)
    + escalatingRepeatPenalty(flavors, 4)
    + escalatingRepeatPenalty(formats, 4)
    + escalatingRepeatPenalty(cuisines, request.preferredCuisines.length === 0 ? 2.5 : 0.5);
  return uniquenessReward - repetitionPenalty;
}

export function mealVarietyReport(meals: Meal[], request: PlannerRequest): MealVarietyReport {
  const profiles = meals.map(profileMeal);
  const ingredients = meaningfulIngredientIDs(meals);
  const uniqueIngredients = new Set(ingredients);
  return {
    primaryProteins: countValues(profiles.map((profile) => profile.primaryProtein)),
    primaryStarches: countValues(profiles.map((profile) => profile.primaryStarch)),
    dominantVegetables: countValues(profiles.map((profile) => profile.dominantVegetable)),
    cookingMethods: countValues(profiles.map((profile) => profile.cookingMethod)),
    cuisines: countValues(profiles.map((profile) => profile.cuisine)),
    flavorProfiles: countValues(profiles.map((profile) => profile.flavorProfile)),
    mealFormats: countValues(profiles.map((profile) => profile.mealFormat)),
    uniqueIngredientCount: uniqueIngredients.size,
    ingredientOverlap: ingredients.length - uniqueIngredients.size,
    reuseScore: ingredientReuseScore(meals),
    varietyScore: rawVarietyScore(profiles, request),
  };
}

export function mealQualityScore(meals: Meal[], request: PlannerRequest) {
  const report = mealVarietyReport(meals, request);
  const servings = request.householdSize + (request.leftovers.enabled ? request.leftovers.extraServings : 0);
  const centsPerServingDinner = request.budgetCents / Math.max(1, request.dinnerCount * servings);
  const tightBudget = request.nutritionStyle === "budget-first" || centsPerServingDinner < 650;
  const varietyWeight = tightBudget ? 0.55 : 1;
  const reuseWeight = request.nutritionStyle === "budget-first" ? 1.8 : tightBudget ? 1.35 : 1;
  return report.varietyScore * varietyWeight + report.reuseScore * reuseWeight;
}

export function normalizeMealTitle(value: string) {
  const cleaned = value.replace(/\s+/g, " ").replace(/\s+([,:])/g, "$1").trim();
  const words = cleaned.split(" ");
  if (cleaned.length <= 52 && words.length <= 8) return cleaned;

  const leadingDish = cleaned.split(/\s+(?:served with|topped with|finished with|with)\s+/i)[0].replace(/[,;:]$/, "");
  if (leadingDish.split(" ").length >= 2 && leadingDish.length <= 52) return leadingDish;

  const clipped = words.slice(0, 7);
  while (clipped.length > 2 && /^(and|with|of|in|on|&|a|the)$/i.test(clipped.at(-1) ?? "")) clipped.pop();
  return clipped.join(" ").replace(/[,;:]$/, "");
}

function categoryImageKey(profile: MealQualityProfile, meal: Meal) {
  const ids = new Set(meal.ingredients.map((item) => item.ingredientId));
  if (profile.mealFormat === "tacos" && profile.primaryProtein === "chicken") return "meal-crispy-chicken-tacos";
  if (profile.mealFormat === "tacos" && ids.has("sweet_potato") && ids.has("black_beans")) return "meal-sweet-potato-black-bean-tacos";
  if (profile.mealFormat === "quesadillas" && ids.has("black_beans")) return "meal-black-bean-quesadillas";
  if (profile.mealFormat === "curry" && ids.has("chickpeas") && ids.has("coconut_milk")) return "meal-chickpea-coconut-curry";
  if (profile.mealFormat === "chili" && profile.primaryProtein === "turkey") return "meal-smoky-turkey-chili";
  if (profile.mealFormat === "pasta" && profile.primaryProtein === "chicken" && ids.has("basil_pesto")) return "meal-pesto-rigatoni";
  if (profile.mealFormat === "pasta" && profile.primaryProtein === "turkey") return "meal-turkey-rigatoni";
  if (profile.mealFormat === "sheet pan" && profile.primaryProtein === "chicken sausage") return "meal-sausage-peppers";
  if ((profile.mealFormat === "bowls" || profile.mealFormat === "grain bowls") && profile.primaryProtein === "tofu" && profile.primaryStarch === "rice") return "meal-tofu-rice-bowls";
  if ((profile.mealFormat === "bowls" || profile.mealFormat === "grain bowls") && profile.primaryProtein === "turkey" && profile.primaryStarch === "rice") return "meal-turkey-rice-bowls";
  if ((profile.mealFormat === "bowls" || profile.mealFormat === "grain bowls") && profile.primaryProtein === "lentils" && ids.has("crushed_tomatoes")) return "meal-lentil-tomato-bowls";
  if ((profile.mealFormat === "bowls" || profile.mealFormat === "grain bowls") && profile.primaryProtein === "eggs" && profile.primaryStarch === "quinoa") return "meal-egg-quinoa-vegetable-bowls";
  if ((profile.mealFormat === "bowls" || profile.mealFormat === "grain bowls") && profile.primaryProtein === "chickpeas" && profile.primaryStarch === "quinoa") return "meal-mediterranean-chickpea-quinoa";
  if (profile.mealFormat === "skillet" && profile.primaryProtein === "tofu" && profile.primaryStarch === "quinoa") return "meal-tofu-quinoa-skillet";
  return undefined;
}

export function prepareMealContent(meal: Meal): Meal {
  const title = normalizeMealTitle(meal.title);
  // Nutrition values are not yet backed by an authoritative dataset, so meals
  // must not carry a factual high-protein label even when the planner uses the
  // recipe estimate as a soft ranking preference.
  const normalized = { ...meal, title, tags: meal.tags.filter((tag) => tag.toLowerCase() !== "high-protein") };
  const exactImage = EXACT_IMAGE_KEYS[meal.id];
  if (exactImage) return { ...normalized, imageKey: exactImage, imageMatch: "exact" };
  const categoryImage = categoryImageKey(profileMeal(normalized), normalized);
  if (categoryImage) return { ...normalized, imageKey: categoryImage, imageMatch: "category" };
  return { ...normalized, imageKey: undefined, imageMatch: "fallback" };
}

export function mealSimilarity(left: Meal, right: Meal) {
  if (left.title.trim().toLowerCase() === right.title.trim().toLowerCase()) return 1;
  const leftIngredients = new Set(meaningfulIngredientIDs([left]));
  const rightIngredients = new Set(meaningfulIngredientIDs([right]));
  const union = new Set([...leftIngredients, ...rightIngredients]);
  const intersection = [...leftIngredients].filter((item) => rightIngredients.has(item)).length;
  const ingredientSimilarity = union.size === 0 ? 0 : intersection / union.size;
  const a = profileMeal(left);
  const b = profileMeal(right);
  const profileSimilarity = (a.primaryProtein === b.primaryProtein ? 0.15 : 0)
    + (a.primaryStarch === b.primaryStarch ? 0.1 : 0)
    + (a.mealFormat === b.mealFormat ? 0.15 : 0)
    + (a.cookingMethod === b.cookingMethod ? 0.05 : 0)
    + (a.cuisine === b.cuisine ? 0.05 : 0)
    + (a.flavorProfile === b.flavorProfile ? 0.05 : 0);
  return ingredientSimilarity * 0.45 + profileSimilarity;
}
