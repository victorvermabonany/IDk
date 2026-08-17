import type { PlannerRequest } from "@/domain/types";

export const CLIENT_DEFAULT_REQUEST: PlannerRequest = {
  store: { id: "", locationId: "", postalCode: "45202" },
  budgetCents: 10_000,
  householdSize: 2,
  dinnerCount: 5,
  leftovers: { enabled: false, extraServings: 0 },
  nutritionStyle: "high-protein",
  dietaryRestrictions: [],
  allergies: [],
  dislikedFoods: ["mushrooms", "seafood"],
  preferredCuisines: [],
  maxCookingMinutes: 40,
  pantryItems: ["olive oil", "salt", "black pepper"],
  customInstructions: "",
};
