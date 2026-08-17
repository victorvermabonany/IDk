import type { Meal, ProviderProduct, ProviderStore } from "./types";

export const DEMO_STORE: ProviderStore = {
  id: "demo-kroger-45202",
  providerStoreId: "fixture-45202",
  name: "Central Market · Estimated catalog",
  retailer: "Cove development fixture",
  address: "Sample market for ZIP 45202",
  zipCode: "45202",
  priceKind: "fixture",
};

const observedAt = "2026-08-15T12:00:00.000Z";

function product(
  input: Omit<
    ProviderProduct,
    | "provider"
    | "providerProductId"
    | "storeId"
    | "salePriceCents"
    | "availability"
    | "priceKind"
    | "observedAt"
  >,
): ProviderProduct {
  return {
    ...input,
    brand: input.department === "Produce" ? "Fresh produce fixture" : "Fixture catalog",
    provider: "fixture",
    providerProductId: `fixture-${input.id}`,
    storeId: DEMO_STORE.id,
    salePriceCents: null,
    availability: "in_stock",
    priceKind: "fixture",
    observedAt,
  };
}

const BASE_DEMO_PRODUCTS: ProviderProduct[] = [
  product({ id: "chicken-225", ingredientId: "chicken_breast", name: "Boneless skinless chicken breast", brand: "Kroger", displayPackage: "about 2.25 lb", packageQuantity: 2.25, packageUnit: "lb", regularPriceCents: 1198, department: "Meat" }),
  product({ id: "turkey-1", ingredientId: "ground_turkey", name: "93% lean ground turkey", brand: "Simple Truth", displayPackage: "1 lb", packageQuantity: 1, packageUnit: "lb", regularPriceCents: 549, department: "Meat" }),
  product({ id: "sausage-12", ingredientId: "chicken_sausage", name: "Roasted garlic chicken sausage", brand: "Private Selection", displayPackage: "12 oz · 4 links", packageQuantity: 12, packageUnit: "oz", regularPriceCents: 499, department: "Meat" }),
  product({ id: "rigatoni-16", ingredientId: "rigatoni", name: "Rigatoni pasta", brand: "Kroger", displayPackage: "16 oz", packageQuantity: 16, packageUnit: "oz", regularPriceCents: 179, department: "Pantry" }),
  product({ id: "rice-32", ingredientId: "brown_rice", name: "Long grain brown rice", brand: "Kroger", displayPackage: "32 oz", packageQuantity: 32, packageUnit: "oz", regularPriceCents: 349, department: "Pantry" }),
  product({ id: "tortillas-10", ingredientId: "flour_tortillas", name: "Soft taco flour tortillas", brand: "Kroger", displayPackage: "10 count", packageQuantity: 10, packageUnit: "count", regularPriceCents: 269, department: "Bakery" }),
  product({ id: "pesto-6", ingredientId: "basil_pesto", name: "Basil pesto", brand: "Private Selection", displayPackage: "6 oz jar", packageQuantity: 6, packageUnit: "oz", regularPriceCents: 429, department: "Pantry" }),
  product({ id: "parmesan-6", ingredientId: "parmesan", name: "Freshly shredded parmesan", brand: "Murray's", displayPackage: "6 oz", packageQuantity: 6, packageUnit: "oz", regularPriceCents: 449, department: "Dairy & eggs" }),
  product({ id: "cheddar-8", ingredientId: "cheddar", name: "Sharp cheddar, shredded", brand: "Kroger", displayPackage: "8 oz", packageQuantity: 8, packageUnit: "oz", regularPriceCents: 349, department: "Dairy & eggs" }),
  product({ id: "yogurt-16", ingredientId: "greek_yogurt", name: "Plain Greek yogurt", brand: "Simple Truth", displayPackage: "16 oz tub", packageQuantity: 16, packageUnit: "oz", regularPriceCents: 429, department: "Dairy & eggs" }),
  product({ id: "beans-15", ingredientId: "black_beans", name: "No-salt-added black beans", brand: "Kroger", displayPackage: "15 oz can", packageQuantity: 15, packageUnit: "oz", regularPriceCents: 99, department: "Canned goods" }),
  product({ id: "tomatoes-28", ingredientId: "crushed_tomatoes", name: "Crushed tomatoes", brand: "Kroger", displayPackage: "28 oz can", packageQuantity: 28, packageUnit: "oz", regularPriceCents: 189, department: "Canned goods" }),
  product({ id: "peppers-3", ingredientId: "bell_pepper", name: "Tri-color bell peppers", brand: "Fresh", displayPackage: "3 count", packageQuantity: 3, packageUnit: "count", regularPriceCents: 399, department: "Produce" }),
  product({ id: "onions-3", ingredientId: "yellow_onion", name: "Yellow onions", brand: "Fresh", displayPackage: "3 count bag", packageQuantity: 3, packageUnit: "count", regularPriceCents: 249, department: "Produce" }),
  product({ id: "zucchini-2", ingredientId: "zucchini", name: "Zucchini squash", brand: "Fresh", displayPackage: "2 count", packageQuantity: 2, packageUnit: "count", regularPriceCents: 249, department: "Produce" }),
  product({ id: "lettuce-1", ingredientId: "romaine", name: "Romaine lettuce", brand: "Fresh", displayPackage: "1 head", packageQuantity: 1, packageUnit: "count", regularPriceCents: 229, department: "Produce" }),
  product({ id: "limes-3", ingredientId: "lime", name: "Fresh limes", brand: "Fresh", displayPackage: "3 count", packageQuantity: 3, packageUnit: "count", regularPriceCents: 179, department: "Produce" }),
  product({ id: "oil-34", ingredientId: "olive_oil", name: "Extra virgin olive oil", brand: "Kroger", displayPackage: "17 fl oz bottle", packageQuantity: 34, packageUnit: "tbsp", regularPriceCents: 899, department: "Pantry" }),
  product({ id: "salt-150", ingredientId: "kosher_salt", name: "Kosher salt", brand: "Morton", displayPackage: "26 oz canister", packageQuantity: 150, packageUnit: "tsp", regularPriceCents: 299, department: "Seasonings" }),
  product({ id: "pepper-36", ingredientId: "black_pepper", name: "Ground black pepper", brand: "Kroger", displayPackage: "3 oz jar", packageQuantity: 36, packageUnit: "tsp", regularPriceCents: 449, department: "Seasonings" }),
  product({ id: "paprika-20", ingredientId: "smoked_paprika", name: "Smoked paprika", brand: "Private Selection", displayPackage: "1.8 oz jar", packageQuantity: 20, packageUnit: "tsp", regularPriceCents: 349, department: "Seasonings" }),
  product({ id: "tofu-14", ingredientId: "extra_firm_tofu", name: "Extra-firm tofu", brand: "Simple Truth", displayPackage: "14 oz", packageQuantity: 14, packageUnit: "oz", regularPriceCents: 249, department: "Produce" }),
  product({ id: "lentils-16", ingredientId: "dry_lentils", name: "Brown lentils", brand: "Kroger", displayPackage: "16 oz", packageQuantity: 16, packageUnit: "oz", regularPriceCents: 179, department: "Pantry" }),
  product({ id: "chickpeas-15", ingredientId: "chickpeas", name: "No-salt-added chickpeas", brand: "Kroger", displayPackage: "15 oz can", packageQuantity: 15, packageUnit: "oz", regularPriceCents: 99, department: "Canned goods" }),
  product({ id: "quinoa-16", ingredientId: "quinoa", name: "White quinoa", brand: "Simple Truth", displayPackage: "16 oz", packageQuantity: 16, packageUnit: "oz", regularPriceCents: 499, department: "Pantry" }),
  product({ id: "spinach-8", ingredientId: "baby_spinach", name: "Baby spinach", brand: "Fresh", displayPackage: "8 oz", packageQuantity: 8, packageUnit: "oz", regularPriceCents: 299, department: "Produce" }),
  product({ id: "broccoli-2", ingredientId: "broccoli", name: "Broccoli crowns", brand: "Fresh", displayPackage: "2 count", packageQuantity: 2, packageUnit: "count", regularPriceCents: 279, department: "Produce" }),
  product({ id: "sweet-potato-3", ingredientId: "sweet_potato", name: "Sweet potatoes", brand: "Fresh", displayPackage: "3 count", packageQuantity: 3, packageUnit: "count", regularPriceCents: 299, department: "Produce" }),
  product({ id: "corn-tortillas-12", ingredientId: "corn_tortillas", name: "Corn tortillas", brand: "Kroger", displayPackage: "12 count", packageQuantity: 12, packageUnit: "count", regularPriceCents: 199, department: "Bakery" }),
  product({ id: "coconut-milk-14", ingredientId: "coconut_milk", name: "Unsweetened coconut milk", brand: "Kroger", displayPackage: "14 oz can", packageQuantity: 14, packageUnit: "oz", regularPriceCents: 229, department: "Canned goods" }),
  product({ id: "soy-sauce-20", ingredientId: "soy_sauce", name: "Reduced-sodium soy sauce", brand: "Kroger", displayPackage: "20 fl oz", packageQuantity: 20, packageUnit: "fl_oz", regularPriceCents: 299, department: "Pantry" }),
  product({ id: "eggs-12", ingredientId: "eggs", name: "Large eggs", brand: "Kroger", displayPackage: "12 count", packageQuantity: 12, packageUnit: "count", regularPriceCents: 329, department: "Dairy & eggs" }),
];

export const VALUE_STORE: ProviderStore = {
  id: "demo-value-45202",
  providerStoreId: "fixture-value-45202",
  name: "Value Market · Estimated catalog",
  retailer: "Cove development fixture",
  address: "Sample value market for ZIP 45202",
  zipCode: "45202",
  priceKind: "fixture",
};

const valueProducts = BASE_DEMO_PRODUCTS.map((item) => ({
  ...item,
  id: `value-${item.id}`,
  providerProductId: `fixture-value-${item.id}`,
  storeId: VALUE_STORE.id,
  brand: item.department === "Produce" ? item.brand : "Estimated value catalog",
  regularPriceCents: Math.max(79, Math.round(item.regularPriceCents * 0.86)),
}));

export const DEMO_STORES = [DEMO_STORE, VALUE_STORE];
export const DEMO_PRODUCTS: ProviderProduct[] = [...BASE_DEMO_PRODUCTS, ...valueProducts];

const commonSeasoning = [
  { ingredientId: "olive_oil", name: "olive oil", quantity: 1, unit: "tbsp" as const },
  { ingredientId: "kosher_salt", name: "kosher salt", quantity: 0.5, unit: "tsp" as const },
  { ingredientId: "black_pepper", name: "black pepper", quantity: 0.25, unit: "tsp" as const },
];

export const DEMO_MEALS: Meal[] = [
  {
    id: "pesto-rigatoni", day: "Monday", title: "Chicken pesto rigatoni", description: "Golden chicken, ribbons of zucchini, basil pesto, and parmesan folded through ridged pasta.", servings: 2, prepMinutes: 10, cookMinutes: 20, calories: 640, proteinGrams: 46, cuisine: "Italian", tags: ["high-protein"], imagePosition: "8% 50%",
    ingredients: [
      { ingredientId: "chicken_breast", name: "boneless chicken breast", quantity: 1.5, unit: "lb" },
      { ingredientId: "rigatoni", name: "rigatoni", quantity: 8, unit: "oz" },
      { ingredientId: "basil_pesto", name: "basil pesto", quantity: 3, unit: "oz" },
      { ingredientId: "parmesan", name: "parmesan", quantity: 2, unit: "oz" },
      { ingredientId: "zucchini", name: "zucchini", quantity: 1, unit: "count" },
      ...commonSeasoning,
    ],
    instructions: ["Bring a pot of salted water to a boil and cook the rigatoni until just tender. Reserve a little pasta water.", "Slice the chicken and zucchini. Season, then sear in olive oil until the chicken is cooked through and the zucchini is golden.", "Fold the pasta, pesto, and a splash of pasta water into the skillet. Finish with parmesan and black pepper."],
  },
  {
    id: "crispy-chicken-tacos", day: "Tuesday", title: "Crispy chicken tacos", description: "Seared chicken, sweet peppers, crunchy romaine, lime, and a cool yogurt finish.", servings: 2, prepMinutes: 12, cookMinutes: 15, calories: 590, proteinGrams: 43, cuisine: "Mexican", tags: ["high-protein", "quick"], imagePosition: "30% 50%",
    ingredients: [
      { ingredientId: "chicken_breast", name: "boneless chicken breast", quantity: 1, unit: "lb" },
      { ingredientId: "flour_tortillas", name: "flour tortillas", quantity: 6, unit: "count" },
      { ingredientId: "bell_pepper", name: "bell pepper", quantity: 1, unit: "count" },
      { ingredientId: "yellow_onion", name: "yellow onion", quantity: 0.5, unit: "count" },
      { ingredientId: "greek_yogurt", name: "plain Greek yogurt", quantity: 4, unit: "oz" },
      { ingredientId: "romaine", name: "romaine lettuce", quantity: 0.5, unit: "count" },
      { ingredientId: "lime", name: "lime", quantity: 1, unit: "count" },
      ...commonSeasoning,
    ],
    instructions: ["Slice the chicken, pepper, and onion into thin strips. Season generously.", "Sear the chicken in olive oil until crisp at the edges. Add the pepper and onion and cook until just tender.", "Warm the tortillas. Fill with chicken and vegetables, then finish with romaine, yogurt, and lime."],
  },
  {
    id: "turkey-rice-bowls", day: "Wednesday", title: "Turkey rice bowls", description: "Savory turkey, brown rice, black beans, and crisp peppers with a tangy yogurt spoonful.", servings: 2, prepMinutes: 10, cookMinutes: 20, calories: 610, proteinGrams: 45, cuisine: "Mexican", tags: ["high-protein"], imagePosition: "50% 50%",
    ingredients: [
      { ingredientId: "ground_turkey", name: "lean ground turkey", quantity: 1, unit: "lb" },
      { ingredientId: "brown_rice", name: "brown rice", quantity: 8, unit: "oz" },
      { ingredientId: "black_beans", name: "black beans", quantity: 15, unit: "oz" },
      { ingredientId: "bell_pepper", name: "bell pepper", quantity: 1, unit: "count" },
      { ingredientId: "yellow_onion", name: "yellow onion", quantity: 0.5, unit: "count" },
      { ingredientId: "greek_yogurt", name: "plain Greek yogurt", quantity: 4, unit: "oz" },
      ...commonSeasoning,
    ],
    instructions: ["Cook the rice according to the package directions.", "Brown the turkey in olive oil. Add diced pepper and onion, then season with salt and black pepper.", "Warm the black beans. Divide the rice among bowls and top with turkey, vegetables, beans, and yogurt."],
  },
  {
    id: "smoky-turkey-chili", day: "Thursday", title: "Smoky turkey & black bean chili", description: "A quick, deeply savory chili built from turkey, beans, tomatoes, and sweet peppers.", servings: 2, prepMinutes: 10, cookMinutes: 25, calories: 530, proteinGrams: 47, cuisine: "American", tags: ["high-protein", "budget-first"], imagePosition: "70% 50%",
    ingredients: [
      { ingredientId: "ground_turkey", name: "lean ground turkey", quantity: 1, unit: "lb" },
      { ingredientId: "black_beans", name: "black beans", quantity: 15, unit: "oz" },
      { ingredientId: "crushed_tomatoes", name: "crushed tomatoes", quantity: 28, unit: "oz" },
      { ingredientId: "yellow_onion", name: "yellow onion", quantity: 1, unit: "count" },
      { ingredientId: "bell_pepper", name: "bell pepper", quantity: 1, unit: "count" },
      { ingredientId: "smoked_paprika", name: "smoked paprika", quantity: 2, unit: "tsp" },
      ...commonSeasoning,
    ],
    instructions: ["Dice the onion and pepper. Soften them in olive oil in a medium pot.", "Add the turkey and cook until browned. Stir in the paprika, salt, and black pepper.", "Add the tomatoes and drained beans. Simmer until thick and spoonable, about 15 minutes."],
  },
  {
    id: "sausage-pepper-pan", day: "Friday", title: "Sheet-pan sausage & peppers", description: "Roasted chicken sausage, peppers, zucchini, and onion over warm brown rice.", servings: 2, prepMinutes: 10, cookMinutes: 25, calories: 570, proteinGrams: 33, cuisine: "American", tags: ["balanced"], imagePosition: "94% 50%",
    ingredients: [
      { ingredientId: "chicken_sausage", name: "chicken sausage", quantity: 12, unit: "oz" },
      { ingredientId: "bell_pepper", name: "bell peppers", quantity: 2, unit: "count" },
      { ingredientId: "zucchini", name: "zucchini", quantity: 1, unit: "count" },
      { ingredientId: "yellow_onion", name: "yellow onion", quantity: 1, unit: "count" },
      { ingredientId: "brown_rice", name: "brown rice", quantity: 8, unit: "oz" },
      ...commonSeasoning,
    ],
    instructions: ["Heat the oven to 425°F. Cut the sausage and vegetables into bite-size pieces.", "Toss everything with olive oil, salt, and black pepper. Spread on a sheet pan.", "Roast until browned at the edges, about 22 minutes. Serve over warm brown rice."],
  },
  {
    id: "turkey-tomato-rigatoni", day: "Saturday", title: "Roasted pepper turkey rigatoni", description: "A bright tomato pasta with browned turkey, roasted peppers, and parmesan.", servings: 2, prepMinutes: 8, cookMinutes: 22, calories: 650, proteinGrams: 44, cuisine: "Italian", tags: ["high-protein"], imagePosition: "12% 50%",
    ingredients: [
      { ingredientId: "ground_turkey", name: "lean ground turkey", quantity: 0.75, unit: "lb" },
      { ingredientId: "rigatoni", name: "rigatoni", quantity: 8, unit: "oz" },
      { ingredientId: "crushed_tomatoes", name: "crushed tomatoes", quantity: 14, unit: "oz" },
      { ingredientId: "bell_pepper", name: "bell pepper", quantity: 1, unit: "count" },
      { ingredientId: "parmesan", name: "parmesan", quantity: 2, unit: "oz" },
      ...commonSeasoning,
    ],
    instructions: ["Cook the rigatoni until just tender.", "Brown the turkey and sliced pepper in olive oil, then add the tomatoes and simmer briefly.", "Toss with the pasta and finish with parmesan."],
  },
  {
    id: "bean-pepper-quesadillas", day: "Sunday", title: "Black bean pepper quesadillas", description: "Crisp tortillas layered with beans, sweet peppers, sharp cheddar, and lime yogurt.", servings: 2, prepMinutes: 10, cookMinutes: 15, calories: 610, proteinGrams: 29, cuisine: "Mexican", tags: ["vegetarian", "quick", "budget-first"], imagePosition: "31% 50%",
    ingredients: [
      { ingredientId: "flour_tortillas", name: "flour tortillas", quantity: 4, unit: "count" },
      { ingredientId: "black_beans", name: "black beans", quantity: 15, unit: "oz" },
      { ingredientId: "bell_pepper", name: "bell pepper", quantity: 1, unit: "count" },
      { ingredientId: "yellow_onion", name: "yellow onion", quantity: 0.5, unit: "count" },
      { ingredientId: "cheddar", name: "sharp cheddar", quantity: 4, unit: "oz" },
      { ingredientId: "greek_yogurt", name: "plain Greek yogurt", quantity: 3, unit: "oz" },
      { ingredientId: "lime", name: "lime", quantity: 1, unit: "count" },
      ...commonSeasoning,
    ],
    instructions: ["Cook the diced pepper and onion in olive oil until tender, then fold in the drained beans.", "Layer tortillas with cheddar and the bean mixture. Cook in a dry skillet until crisp and melted.", "Stir lime into the yogurt and serve alongside the quesadillas."],
  },
  {
    id: "tofu-rice-bowls", day: "Monday", title: "Crispy tofu rice bowls", description: "Golden tofu, brown rice, broccoli, and peppers with a savory soy glaze.", servings: 2, prepMinutes: 10, cookMinutes: 18, calories: 520, proteinGrams: 30, cuisine: "Asian-inspired", tags: ["vegan", "vegetarian", "high-protein", "quick"], imagePosition: "45% 50%",
    ingredients: [
      { ingredientId: "extra_firm_tofu", name: "extra-firm tofu", quantity: 14, unit: "oz" },
      { ingredientId: "brown_rice", name: "brown rice", quantity: 8, unit: "oz" },
      { ingredientId: "broccoli", name: "broccoli", quantity: 1, unit: "count" },
      { ingredientId: "bell_pepper", name: "bell pepper", quantity: 1, unit: "count" },
      { ingredientId: "soy_sauce", name: "soy sauce", quantity: 1, unit: "fl_oz" }, ...commonSeasoning,
    ],
    instructions: ["Cook the rice according to its package directions.", "Sear cubed tofu in olive oil until crisp, then add broccoli and pepper.", "Add soy sauce, toss until glossy, and serve over the rice."],
  },
  {
    id: "lentil-tomato-bowls", day: "Tuesday", title: "Smoky lentil tomato bowls", description: "Tender lentils simmered with tomatoes, spinach, peppers, and warm smoked paprika.", servings: 2, prepMinutes: 8, cookMinutes: 22, calories: 470, proteinGrams: 27, cuisine: "Mediterranean", tags: ["vegan", "vegetarian", "high-protein", "budget-first"], imagePosition: "55% 50%",
    ingredients: [
      { ingredientId: "dry_lentils", name: "brown lentils", quantity: 8, unit: "oz" },
      { ingredientId: "crushed_tomatoes", name: "crushed tomatoes", quantity: 14, unit: "oz" },
      { ingredientId: "baby_spinach", name: "baby spinach", quantity: 4, unit: "oz" },
      { ingredientId: "bell_pepper", name: "bell pepper", quantity: 1, unit: "count" },
      { ingredientId: "smoked_paprika", name: "smoked paprika", quantity: 1, unit: "tsp" }, ...commonSeasoning,
    ],
    instructions: ["Rinse the lentils and simmer until nearly tender.", "Add tomatoes, diced pepper, paprika, salt, and black pepper.", "Fold in spinach and simmer until the lentils are tender and the sauce is thick."],
  },
  {
    id: "chickpea-coconut-curry", day: "Wednesday", title: "Chickpea coconut curry", description: "Creamy chickpeas, tomatoes, spinach, and peppers over warm brown rice.", servings: 2, prepMinutes: 8, cookMinutes: 20, calories: 540, proteinGrams: 23, cuisine: "Indian-inspired", tags: ["vegan", "vegetarian", "quick"], imagePosition: "65% 50%",
    ingredients: [
      { ingredientId: "chickpeas", name: "chickpeas", quantity: 15, unit: "oz" },
      { ingredientId: "coconut_milk", name: "coconut milk", quantity: 7, unit: "oz" },
      { ingredientId: "crushed_tomatoes", name: "crushed tomatoes", quantity: 14, unit: "oz" },
      { ingredientId: "baby_spinach", name: "baby spinach", quantity: 4, unit: "oz" },
      { ingredientId: "brown_rice", name: "brown rice", quantity: 8, unit: "oz" }, ...commonSeasoning,
    ],
    instructions: ["Cook the rice according to package directions.", "Simmer chickpeas, tomatoes, coconut milk, salt, and pepper until thickened.", "Fold in spinach until wilted and spoon the curry over rice."],
  },
  {
    id: "sweet-potato-black-bean-tacos", day: "Thursday", title: "Sweet potato black bean tacos", description: "Crisp corn tortillas filled with smoky sweet potato, black beans, romaine, and lime.", servings: 2, prepMinutes: 10, cookMinutes: 20, calories: 500, proteinGrams: 22, cuisine: "Mexican", tags: ["vegan", "vegetarian", "budget-first"], imagePosition: "75% 50%",
    ingredients: [
      { ingredientId: "sweet_potato", name: "sweet potato", quantity: 2, unit: "count" },
      { ingredientId: "black_beans", name: "black beans", quantity: 15, unit: "oz" },
      { ingredientId: "corn_tortillas", name: "corn tortillas", quantity: 6, unit: "count" },
      { ingredientId: "romaine", name: "romaine lettuce", quantity: 0.5, unit: "count" },
      { ingredientId: "lime", name: "lime", quantity: 1, unit: "count" },
      { ingredientId: "smoked_paprika", name: "smoked paprika", quantity: 1, unit: "tsp" }, ...commonSeasoning,
    ],
    instructions: ["Dice the sweet potato and cook it in olive oil until tender and browned.", "Warm the black beans with paprika, salt, and black pepper.", "Fill warm tortillas with sweet potato, beans, romaine, and lime."],
  },
  {
    id: "mediterranean-chickpea-quinoa", day: "Friday", title: "Mediterranean chickpea quinoa", description: "Fluffy quinoa, chickpeas, zucchini, spinach, peppers, and bright lime.", servings: 2, prepMinutes: 10, cookMinutes: 18, calories: 510, proteinGrams: 25, cuisine: "Mediterranean", tags: ["vegan", "vegetarian", "balanced", "quick"], imagePosition: "85% 50%",
    ingredients: [
      { ingredientId: "quinoa", name: "quinoa", quantity: 8, unit: "oz" },
      { ingredientId: "chickpeas", name: "chickpeas", quantity: 15, unit: "oz" },
      { ingredientId: "zucchini", name: "zucchini", quantity: 1, unit: "count" },
      { ingredientId: "baby_spinach", name: "baby spinach", quantity: 4, unit: "oz" },
      { ingredientId: "bell_pepper", name: "bell pepper", quantity: 1, unit: "count" },
      { ingredientId: "lime", name: "lime", quantity: 1, unit: "count" }, ...commonSeasoning,
    ],
    instructions: ["Cook the quinoa until fluffy.", "Sauté zucchini and pepper in olive oil, then add chickpeas and spinach.", "Fold in quinoa, season, and finish with fresh lime."],
  },
  {
    id: "tofu-quinoa-skillet", day: "Saturday", title: "Tofu quinoa vegetable skillet", description: "Protein-rich tofu and quinoa with zucchini, spinach, and sweet peppers.", servings: 2, prepMinutes: 10, cookMinutes: 20, calories: 530, proteinGrams: 34, cuisine: "American", tags: ["vegan", "vegetarian", "high-protein", "balanced"], imagePosition: "25% 50%",
    ingredients: [
      { ingredientId: "extra_firm_tofu", name: "extra-firm tofu", quantity: 14, unit: "oz" },
      { ingredientId: "quinoa", name: "quinoa", quantity: 8, unit: "oz" },
      { ingredientId: "zucchini", name: "zucchini", quantity: 1, unit: "count" },
      { ingredientId: "baby_spinach", name: "baby spinach", quantity: 4, unit: "oz" },
      { ingredientId: "bell_pepper", name: "bell pepper", quantity: 1, unit: "count" }, ...commonSeasoning,
    ],
    instructions: ["Cook the quinoa until tender.", "Sear cubed tofu until crisp, then add zucchini and pepper.", "Fold in spinach and quinoa, season, and cook until hot."],
  },
  {
    id: "lentil-rice-stuffed-peppers", day: "Sunday", title: "Lentil rice pepper bowls", description: "Savory lentils and brown rice with tender peppers, tomatoes, and spinach.", servings: 2, prepMinutes: 8, cookMinutes: 22, calories: 490, proteinGrams: 26, cuisine: "Mediterranean", tags: ["vegan", "vegetarian", "budget-first"], imagePosition: "15% 50%",
    ingredients: [
      { ingredientId: "dry_lentils", name: "brown lentils", quantity: 6, unit: "oz" },
      { ingredientId: "brown_rice", name: "brown rice", quantity: 6, unit: "oz" },
      { ingredientId: "bell_pepper", name: "bell peppers", quantity: 2, unit: "count" },
      { ingredientId: "crushed_tomatoes", name: "crushed tomatoes", quantity: 14, unit: "oz" },
      { ingredientId: "baby_spinach", name: "baby spinach", quantity: 4, unit: "oz" }, ...commonSeasoning,
    ],
    instructions: ["Cook the lentils and rice until tender.", "Sauté diced peppers, then add tomatoes, salt, and black pepper.", "Fold in spinach, lentils, and rice and simmer until cohesive."],
  },
  {
    id: "egg-quinoa-vegetable-bowls", day: "Monday", title: "Egg quinoa vegetable bowls", description: "Jammy eggs, quinoa, spinach, broccoli, and peppers in a fast skillet bowl.", servings: 2, prepMinutes: 8, cookMinutes: 15, calories: 480, proteinGrams: 31, cuisine: "American", tags: ["vegetarian", "high-protein", "quick", "lighter"], imagePosition: "40% 50%",
    ingredients: [
      { ingredientId: "eggs", name: "eggs", quantity: 4, unit: "count" },
      { ingredientId: "quinoa", name: "quinoa", quantity: 8, unit: "oz" },
      { ingredientId: "baby_spinach", name: "baby spinach", quantity: 4, unit: "oz" },
      { ingredientId: "broccoli", name: "broccoli", quantity: 1, unit: "count" },
      { ingredientId: "bell_pepper", name: "bell pepper", quantity: 1, unit: "count" }, ...commonSeasoning,
    ],
    instructions: ["Cook the quinoa and boil the eggs to your preferred doneness.", "Sauté broccoli and pepper in olive oil, then wilt in the spinach.", "Divide into bowls with quinoa and halved eggs; season well."],
  },
];

export const INGREDIENT_ALIASES: Record<string, string> = {
  onion: "yellow_onion",
  "yellow onion": "yellow_onion",
  "medium onion": "yellow_onion",
  peppers: "bell_pepper",
  "bell peppers": "bell_pepper",
  "chicken breast": "chicken_breast",
  chicken: "chicken_breast",
  rice: "brown_rice",
  "brown rice": "brown_rice",
  tofu: "extra_firm_tofu",
  lentils: "dry_lentils",
  spinach: "baby_spinach",
  "sweet potato": "sweet_potato",
  "soy sauce": "soy_sauce",
  eggs: "eggs",
  "greek yogurt": "greek_yogurt",
  "black beans": "black_beans",
  "olive oil": "olive_oil",
  salt: "kosher_salt",
  pepper: "black_pepper",
};

export const INGREDIENT_ALLERGENS: Record<string, string[]> = {
  flour_tortillas: ["wheat", "gluten"],
  rigatoni: ["wheat", "gluten"],
  parmesan: ["milk", "dairy"],
  cheddar: ["milk", "dairy"],
  greek_yogurt: ["milk", "dairy"],
  extra_firm_tofu: ["soy"],
  soy_sauce: ["soy", "wheat", "gluten"],
  eggs: ["egg", "eggs"],
};

export const INGREDIENT_DIETARY_TRAITS: Record<string, string[]> = {
  chicken_breast: ["meat", "animal-derived"],
  ground_turkey: ["meat", "animal-derived"],
  chicken_sausage: ["meat", "animal-derived"],
  parmesan: ["dairy", "animal-derived"],
  cheddar: ["dairy", "animal-derived"],
  greek_yogurt: ["dairy", "animal-derived"],
  eggs: ["egg", "animal-derived"],
};
