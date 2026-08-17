import { INGREDIENT_ALLERGENS, INGREDIENT_DIETARY_TRAITS } from "./fixtures";
import { normalizeIngredientName } from "./engine";
import { PlanGenerationError, unitSchema, type Meal, type PlannerRequest } from "./types";

const meatWords = ["chicken", "turkey", "beef", "pork", "lamb", "sausage", "bacon", "ham", "fish", "salmon", "tuna", "shrimp", "crab", "lobster", "shellfish", "gelatin", "meat broth", "chicken broth", "beef broth"];
const animalWords = [...meatWords, "milk", "cream", "cheese", "parmesan", "cheddar", "yogurt", "egg", "honey"];
const seafoodWords = ["fish", "salmon", "tuna", "shrimp", "crab", "lobster", "shellfish", "seafood"];

export function normalizedRestrictions(request: PlannerRequest) {
  const restrictions = new Set(request.dietaryRestrictions.map((item) => item.toLowerCase()));
  if (request.nutritionStyle === "vegetarian") restrictions.add("vegetarian");
  if (restrictions.has("vegan")) restrictions.add("vegetarian");
  return restrictions;
}

export function requiredServings(request: PlannerRequest) {
  return request.householdSize + (request.leftovers.enabled ? request.leftovers.extraServings : 0);
}

function normalizedAllergies(request: PlannerRequest) {
  const result = new Set<string>();
  for (const allergy of request.allergies) {
    const normalized = allergy.toLowerCase();
    result.add(normalized);
    if (normalized === "dairy") result.add("milk");
    if (normalized === "milk") result.add("dairy");
    if (normalized === "eggs") result.add("egg");
    if (normalized === "egg") result.add("eggs");
    if (normalized === "peanuts") result.add("peanut");
    if (normalized === "peanut") result.add("peanuts");
    if (normalized === "wheat") result.add("gluten");
  }
  return result;
}

function ingredientText(meal: Meal, ingredientID: string, name: string) {
  return `${ingredientID.replaceAll("_", " ")} ${name} ${meal.title}`.toLowerCase();
}

function containsPhrase(text: string, phrase: string) {
  const escaped = phrase.replace(/[.*+?^${}()|[\]\\]/g, "\\$&").replaceAll(" ", "\\s+");
  return new RegExp(`\\b${escaped}\\b`, "i").test(text);
}

export function mealConstraintIssues(meal: Meal, request: PlannerRequest): string[] {
  const issues: string[] = [];
  const restrictions = normalizedRestrictions(request);
  const allergies = normalizedAllergies(request);
  const dislikes = request.dislikedFoods.map((item) => item.toLowerCase());
  const mealText = `${meal.title} ${meal.description} ${meal.instructions.join(" ")} ${meal.ingredients.map((item) => `${item.ingredientId.replaceAll("_", " ")} ${item.name}`).join(" ")}`.toLowerCase();

  if (meal.servings !== requiredServings(request)) issues.push(`${meal.title} serves ${meal.servings}, not ${requiredServings(request)}.`);
  if (meal.prepMinutes + meal.cookMinutes > request.maxCookingMinutes) issues.push(`${meal.title} exceeds ${request.maxCookingMinutes} total minutes.`);
  if (meal.instructions.length < 2 || meal.instructions.some((step) => step.trim().length < 8)) issues.push(`${meal.title} has incomplete instructions.`);
  if (meal.ingredients.length < 3) issues.push(`${meal.title} does not contain enough structured ingredients.`);
  if (request.customInstructions.toLowerCase().includes("don't use an oven") || request.customInstructions.toLowerCase().includes("no oven")) {
    if (meal.instructions.some((step) => /oven|bake|roast|sheet pan/i.test(step))) issues.push(`${meal.title} conflicts with the no-oven instruction.`);
  }

  for (const ingredient of meal.ingredients) {
    const text = ingredientText(meal, ingredient.ingredientId, ingredient.name);
    const traits = INGREDIENT_DIETARY_TRAITS[ingredient.ingredientId] ?? [];
    const ingredientAllergens = INGREDIENT_ALLERGENS[ingredient.ingredientId] ?? [];
    if (!(ingredient.quantity > 0) || !unitSchema.safeParse(ingredient.unit).success) issues.push(`${ingredient.name} has an invalid quantity or unit.`);
    if (restrictions.has("vegetarian") && (traits.includes("meat") || meatWords.some((word) => containsPhrase(text, word)))) issues.push(`${ingredient.name} is not vegetarian.`);
    const animalWordViolation = ingredient.ingredientId !== "coconut_milk" && animalWords.some((word) => containsPhrase(text, word));
    if (restrictions.has("vegan") && (traits.includes("animal-derived") || animalWordViolation)) issues.push(`${ingredient.name} is not vegan.`);
    if (ingredientAllergens.some((allergen) => allergies.has(allergen))) issues.push(`${ingredient.name} conflicts with an allergy.`);
    if (allergies.has("shellfish") && seafoodWords.slice(5).some((word) => text.includes(word))) issues.push(`${ingredient.name} conflicts with the shellfish allergy.`);
    if (allergies.has("fish") && seafoodWords.slice(0, 4).some((word) => text.includes(word))) issues.push(`${ingredient.name} conflicts with the fish allergy.`);
    if (allergies.has("peanut") && text.includes("peanut")) issues.push(`${ingredient.name} conflicts with the peanut allergy.`);
  }
  for (const dislike of dislikes) {
    const normalized = normalizeIngredientName(dislike).replaceAll("_", " ");
    if (containsPhrase(mealText, dislike) || containsPhrase(mealText, normalized) || (dislike === "seafood" && seafoodWords.some((word) => containsPhrase(mealText, word)))) {
      issues.push(`${meal.title} contains the disliked food ${dislike}.`);
    }
  }
  return [...new Set(issues)];
}

export function validatePlanOrThrow(meals: Meal[], request: PlannerRequest) {
  const issues: string[] = [];
  if (meals.length !== request.dinnerCount) issues.push(`Expected exactly ${request.dinnerCount} dinners, received ${meals.length}.`);
  const normalizedTitles = meals.map((meal) => meal.title.trim().toLowerCase());
  if (new Set(normalizedTitles).size !== normalizedTitles.length) issues.push("The week contains duplicate meals.");
  for (const meal of meals) issues.push(...mealConstraintIssues(meal, request));
  const chickenLimit = request.customInstructions.toLowerCase().match(/chicken\s+(?:no more than|at most)\s+(\d+)/);
  if (chickenLimit) {
    const maximum = Number(chickenLimit[1]);
    const chickenMeals = meals.filter((meal) => meal.ingredients.some((item) => /chicken/.test(`${item.ingredientId} ${item.name}`.toLowerCase()))).length;
    if (chickenMeals > maximum) issues.push(`Chicken appears in ${chickenMeals} meals, exceeding the requested maximum of ${maximum}.`);
  }
  if (issues.length > 0) {
    throw new PlanGenerationError(
      "CONSTRAINT_CONFLICT",
      `We couldn't create a safe week from those choices: ${issues.slice(0, 3).join(" ")}`,
      ["Increase the budget", "Reduce dinners", "Change non-safety preferences"],
    );
  }
}

export function preferenceScore(meals: Meal[], request: PlannerRequest) {
  const uniqueIngredients = new Set(meals.flatMap((meal) => meal.ingredients.map((item) => item.ingredientId))).size;
  const totalUses = meals.reduce((sum, meal) => sum + meal.ingredients.length, 0);
  const overlap = totalUses - uniqueIngredients;
  const averageProtein = meals.reduce((sum, meal) => sum + meal.proteinGrams, 0) / meals.length;
  const averageCalories = meals.reduce((sum, meal) => sum + meal.calories, 0) / meals.length;
  const averageTime = meals.reduce((sum, meal) => sum + meal.prepMinutes + meal.cookMinutes, 0) / meals.length;
  const averageIngredients = totalUses / meals.length;
  const cuisineMatches = request.preferredCuisines.length === 0 ? 0 : meals.filter((meal) => request.preferredCuisines.some((cuisine) => meal.cuisine.toLowerCase().includes(cuisine.toLowerCase()))).length;
  let score = overlap * 3 + cuisineMatches * 12;
  if (request.nutritionStyle === "high-protein") score += averageProtein * 2;
  if (request.nutritionStyle === "quick") score += (request.maxCookingMinutes - averageTime) * 2 - averageIngredients * 2;
  if (request.nutritionStyle === "budget-first") score += overlap * 8 - uniqueIngredients * 2;
  if (request.nutritionStyle === "lighter") score += Math.max(0, 700 - averageCalories) / 10;
  if (request.nutritionStyle === "balanced") score += new Set(meals.map((meal) => meal.cuisine)).size * 5;
  return score;
}
