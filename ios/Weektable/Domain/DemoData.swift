import Foundation

enum DemoData {
    static let store = Store(
        id: "demo-kroger-45202",
        name: "Central Market · Estimated catalog",
        retailer: "Cove development fixture",
        address: "Sample market for ZIP 45202",
        zipCode: "45202",
        priceKind: .fixture
    )

    static let valueStore = Store(
        id: "demo-value-45202",
        providerStoreID: "fixture-value-45202",
        name: "Cove value fixture · Sample catalog",
        retailer: "Cove development fixture",
        address: "Cincinnati, OH 45202",
        zipCode: "45202",
        priceKind: .fixture
    )

    static let stores = [store, valueStore]

    private static let seasoning: [RecipeIngredient] = [
        .init(ingredientID: "olive_oil", name: "Olive oil", quantity: 1, unit: "tbsp"),
        .init(ingredientID: "kosher_salt", name: "Kosher salt", quantity: 0.5, unit: "tsp"),
        .init(ingredientID: "black_pepper", name: "Black pepper", quantity: 0.25, unit: "tsp")
    ]

    static let meals: [Meal] = [
        Meal(
            id: "pesto-rigatoni", day: "Monday", title: "Chicken pesto rigatoni",
            description: "Golden chicken, zucchini, basil pesto, and parmesan folded through ridged pasta.",
            servings: 2, prepMinutes: 10, cookMinutes: 20, calories: 640, proteinGrams: 46, imageAlignment: 0.08,
            ingredients: [
                .init(ingredientID: "chicken_breast", name: "Boneless chicken breast", quantity: 1.5, unit: "lb"),
                .init(ingredientID: "rigatoni", name: "Rigatoni", quantity: 8, unit: "oz"),
                .init(ingredientID: "basil_pesto", name: "Basil pesto", quantity: 3, unit: "oz"),
                .init(ingredientID: "parmesan", name: "Parmesan", quantity: 2, unit: "oz"),
                .init(ingredientID: "zucchini", name: "Zucchini", quantity: 1, unit: "count")
            ] + seasoning,
            instructions: [
                "Bring a pot of salted water to a boil and cook the rigatoni until just tender. Reserve a little pasta water.",
                "Slice the chicken and zucchini. Season, then sear until the chicken is cooked through and the zucchini is golden.",
                "Fold the pasta, pesto, and a splash of pasta water into the skillet. Finish with parmesan and black pepper."
            ]
        ),
        Meal(
            id: "crispy-chicken-tacos", day: "Tuesday", title: "Crispy chicken tacos",
            description: "Seared chicken, sweet peppers, crunchy romaine, lime, and a cool yogurt finish.",
            servings: 2, prepMinutes: 12, cookMinutes: 15, calories: 590, proteinGrams: 43, imageAlignment: 0.30,
            ingredients: [
                .init(ingredientID: "chicken_breast", name: "Boneless chicken breast", quantity: 1, unit: "lb"),
                .init(ingredientID: "flour_tortillas", name: "Flour tortillas", quantity: 6, unit: "count"),
                .init(ingredientID: "bell_pepper", name: "Bell pepper", quantity: 1, unit: "count"),
                .init(ingredientID: "greek_yogurt", name: "Plain Greek yogurt", quantity: 4, unit: "oz"),
                .init(ingredientID: "romaine", name: "Romaine lettuce", quantity: 0.5, unit: "count"),
                .init(ingredientID: "lime", name: "Lime", quantity: 1, unit: "count")
            ] + seasoning,
            instructions: [
                "Slice the chicken, pepper, and onion into thin strips. Season generously.",
                "Sear the chicken until crisp at the edges. Add the vegetables and cook until just tender.",
                "Warm the tortillas, fill, and finish with romaine, yogurt, and lime."
            ]
        ),
        Meal(
            id: "turkey-rice-bowls", day: "Wednesday", title: "Turkey rice bowls",
            description: "Savory turkey, brown rice, black beans, and crisp peppers with tangy yogurt.",
            servings: 2, prepMinutes: 10, cookMinutes: 20, calories: 610, proteinGrams: 45, imageAlignment: 0.50,
            ingredients: [
                .init(ingredientID: "ground_turkey", name: "Lean ground turkey", quantity: 1, unit: "lb"),
                .init(ingredientID: "brown_rice", name: "Brown rice", quantity: 8, unit: "oz"),
                .init(ingredientID: "black_beans", name: "Black beans", quantity: 15, unit: "oz"),
                .init(ingredientID: "bell_pepper", name: "Bell pepper", quantity: 1, unit: "count"),
                .init(ingredientID: "greek_yogurt", name: "Plain Greek yogurt", quantity: 4, unit: "oz")
            ] + seasoning,
            instructions: [
                "Cook the rice according to the package directions.",
                "Brown the turkey. Add diced pepper and onion, then season.",
                "Warm the beans and divide everything among bowls with yogurt."
            ]
        ),
        Meal(
            id: "smoky-turkey-chili", day: "Thursday", title: "Smoky turkey chili",
            description: "A deeply savory chili built from turkey, beans, tomatoes, and sweet peppers.",
            servings: 2, prepMinutes: 10, cookMinutes: 25, calories: 530, proteinGrams: 47, imageAlignment: 0.70,
            ingredients: [
                .init(ingredientID: "ground_turkey", name: "Lean ground turkey", quantity: 1, unit: "lb"),
                .init(ingredientID: "black_beans", name: "Black beans", quantity: 15, unit: "oz"),
                .init(ingredientID: "crushed_tomatoes", name: "Crushed tomatoes", quantity: 28, unit: "oz"),
                .init(ingredientID: "bell_pepper", name: "Bell pepper", quantity: 1, unit: "count"),
                .init(ingredientID: "smoked_paprika", name: "Smoked paprika", quantity: 2, unit: "tsp")
            ] + seasoning,
            instructions: [
                "Dice the onion and pepper and soften them in olive oil.",
                "Add the turkey and cook until browned. Stir in the seasonings.",
                "Add tomatoes and beans. Simmer until thick and spoonable."
            ]
        ),
        Meal(
            id: "sausage-pepper-pan", day: "Friday", title: "Sheet-pan sausage & peppers",
            description: "Roasted chicken sausage, peppers, zucchini, and onion over warm brown rice.",
            servings: 2, prepMinutes: 10, cookMinutes: 25, calories: 570, proteinGrams: 33, imageAlignment: 0.94,
            ingredients: [
                .init(ingredientID: "chicken_sausage", name: "Chicken sausage", quantity: 12, unit: "oz"),
                .init(ingredientID: "bell_pepper", name: "Bell peppers", quantity: 2, unit: "count"),
                .init(ingredientID: "zucchini", name: "Zucchini", quantity: 1, unit: "count"),
                .init(ingredientID: "brown_rice", name: "Brown rice", quantity: 8, unit: "oz")
            ] + seasoning,
            instructions: [
                "Heat the oven to 425°F. Cut the sausage and vegetables into bite-size pieces.",
                "Toss everything with olive oil, salt, and pepper. Spread on a sheet pan.",
                "Roast until browned at the edges and serve over warm brown rice."
            ]
        ),
        Meal(
            id: "turkey-tomato-rigatoni", day: "Saturday", title: "Roasted pepper turkey rigatoni",
            description: "Bright tomato pasta with browned turkey, roasted peppers, and parmesan.",
            servings: 2, prepMinutes: 8, cookMinutes: 22, calories: 650, proteinGrams: 44, imageAlignment: 0.16,
            ingredients: [
                .init(ingredientID: "ground_turkey", name: "Lean ground turkey", quantity: 0.75, unit: "lb"),
                .init(ingredientID: "rigatoni", name: "Rigatoni", quantity: 8, unit: "oz"),
                .init(ingredientID: "crushed_tomatoes", name: "Crushed tomatoes", quantity: 14, unit: "oz"),
                .init(ingredientID: "bell_pepper", name: "Bell pepper", quantity: 1, unit: "count")
            ] + seasoning,
            instructions: ["Cook the rigatoni.", "Brown turkey and pepper, then add tomatoes.", "Toss together and finish with parmesan."]
        ),
        Meal(
            id: "bean-pepper-quesadillas", day: "Sunday", title: "Black bean quesadillas",
            description: "Crisp tortillas layered with beans, sweet peppers, cheddar, and lime yogurt.",
            servings: 2, prepMinutes: 10, cookMinutes: 15, calories: 610, proteinGrams: 29, imageAlignment: 0.34,
            ingredients: [
                .init(ingredientID: "flour_tortillas", name: "Flour tortillas", quantity: 4, unit: "count"),
                .init(ingredientID: "black_beans", name: "Black beans", quantity: 15, unit: "oz"),
                .init(ingredientID: "bell_pepper", name: "Bell pepper", quantity: 1, unit: "count"),
                .init(ingredientID: "cheddar", name: "Sharp cheddar", quantity: 4, unit: "oz")
            ] + seasoning,
            instructions: ["Cook diced pepper with the beans.", "Layer tortillas with cheddar and filling, then crisp in a skillet.", "Serve with lime yogurt."]
        ),
        Meal(
            id: "tofu-rice-bowls", day: "Monday", title: "Ginger tofu rice bowls",
            description: "Crisp tofu, brown rice, broccoli, and peppers with a savory ginger-soy glaze.",
            servings: 2, prepMinutes: 10, cookMinutes: 18, calories: 540, proteinGrams: 29, imageAlignment: 0.46,
            ingredients: [
                .init(ingredientID: "tofu", name: "Extra-firm tofu", quantity: 14, unit: "oz"),
                .init(ingredientID: "brown_rice", name: "Brown rice", quantity: 8, unit: "oz"),
                .init(ingredientID: "broccoli", name: "Broccoli", quantity: 1, unit: "count"),
                .init(ingredientID: "bell_pepper", name: "Bell pepper", quantity: 1, unit: "count"),
                .init(ingredientID: "soy_sauce", name: "Soy sauce", quantity: 2, unit: "tbsp")
            ] + seasoning,
            instructions: ["Cook the rice.", "Sear cubed tofu until crisp, then add broccoli and pepper.", "Add soy sauce and serve over rice."]
        ),
        Meal(
            id: "lentil-tomato-bowls", day: "Tuesday", title: "Smoky lentil tomato bowls",
            description: "Tender lentils and tomatoes with peppers, spinach, and warm smoked paprika.",
            servings: 2, prepMinutes: 8, cookMinutes: 20, calories: 470, proteinGrams: 25, imageAlignment: 0.58,
            ingredients: [
                .init(ingredientID: "lentils", name: "Cooked lentils", quantity: 15, unit: "oz"),
                .init(ingredientID: "crushed_tomatoes", name: "Crushed tomatoes", quantity: 14, unit: "oz"),
                .init(ingredientID: "spinach", name: "Baby spinach", quantity: 5, unit: "oz"),
                .init(ingredientID: "bell_pepper", name: "Bell pepper", quantity: 1, unit: "count"),
                .init(ingredientID: "smoked_paprika", name: "Smoked paprika", quantity: 1, unit: "tsp")
            ] + seasoning,
            instructions: ["Soften diced pepper in olive oil.", "Add lentils, tomatoes, and paprika; simmer until thick.", "Fold in spinach and season."]
        ),
        Meal(
            id: "chickpea-coconut-curry", day: "Wednesday", title: "Chickpea coconut curry",
            description: "A quick, mild chickpea curry with tomatoes and spinach over brown rice.",
            servings: 2, prepMinutes: 8, cookMinutes: 20, calories: 560, proteinGrams: 22, imageAlignment: 0.62,
            ingredients: [
                .init(ingredientID: "chickpeas", name: "Chickpeas", quantity: 15, unit: "oz"),
                .init(ingredientID: "coconut_milk", name: "Coconut milk", quantity: 13.5, unit: "fl_oz"),
                .init(ingredientID: "crushed_tomatoes", name: "Crushed tomatoes", quantity: 14, unit: "oz"),
                .init(ingredientID: "spinach", name: "Baby spinach", quantity: 5, unit: "oz"),
                .init(ingredientID: "brown_rice", name: "Brown rice", quantity: 8, unit: "oz")
            ] + seasoning,
            instructions: ["Cook the rice.", "Simmer chickpeas, coconut milk, and tomatoes until thickened.", "Fold in spinach and serve over rice."]
        ),
        Meal(
            id: "sweet-potato-tacos", day: "Thursday", title: "Sweet potato black bean tacos",
            description: "Skillet sweet potato, black beans, peppers, and lime in warm corn tortillas.",
            servings: 2, prepMinutes: 10, cookMinutes: 20, calories: 510, proteinGrams: 19, imageAlignment: 0.38,
            ingredients: [
                .init(ingredientID: "sweet_potato", name: "Sweet potato", quantity: 1, unit: "lb"),
                .init(ingredientID: "black_beans", name: "Black beans", quantity: 15, unit: "oz"),
                .init(ingredientID: "corn_tortillas", name: "Corn tortillas", quantity: 6, unit: "count"),
                .init(ingredientID: "bell_pepper", name: "Bell pepper", quantity: 1, unit: "count"),
                .init(ingredientID: "lime", name: "Lime", quantity: 1, unit: "count")
            ] + seasoning,
            instructions: ["Dice and skillet-cook the sweet potato until tender.", "Add pepper and beans and season.", "Fill warm corn tortillas and finish with lime."]
        ),
        Meal(
            id: "mediterranean-quinoa", day: "Friday", title: "Mediterranean chickpea quinoa",
            description: "Fluffy quinoa, chickpeas, spinach, peppers, and bright lemony seasoning.",
            servings: 2, prepMinutes: 10, cookMinutes: 18, calories: 500, proteinGrams: 23, imageAlignment: 0.52,
            ingredients: [
                .init(ingredientID: "quinoa", name: "Quinoa", quantity: 8, unit: "oz"),
                .init(ingredientID: "chickpeas", name: "Chickpeas", quantity: 15, unit: "oz"),
                .init(ingredientID: "spinach", name: "Baby spinach", quantity: 5, unit: "oz"),
                .init(ingredientID: "bell_pepper", name: "Bell pepper", quantity: 1, unit: "count"),
                .init(ingredientID: "lime", name: "Lime", quantity: 1, unit: "count")
            ] + seasoning,
            instructions: ["Cook the quinoa until fluffy.", "Warm chickpeas and pepper in a skillet.", "Fold in spinach, quinoa, and lime."]
        ),
        Meal(
            id: "tofu-quinoa-skillet", day: "Saturday", title: "Crispy tofu quinoa skillet",
            description: "Protein-rich tofu and quinoa with broccoli and a savory soy finish.",
            servings: 2, prepMinutes: 8, cookMinutes: 20, calories: 530, proteinGrams: 32, imageAlignment: 0.42,
            ingredients: [
                .init(ingredientID: "tofu", name: "Extra-firm tofu", quantity: 14, unit: "oz"),
                .init(ingredientID: "quinoa", name: "Quinoa", quantity: 8, unit: "oz"),
                .init(ingredientID: "broccoli", name: "Broccoli", quantity: 1, unit: "count"),
                .init(ingredientID: "soy_sauce", name: "Soy sauce", quantity: 2, unit: "tbsp")
            ] + seasoning,
            instructions: ["Cook the quinoa.", "Sear cubed tofu and broccoli until browned.", "Add soy sauce and fold in quinoa."]
        ),
        Meal(
            id: "lentil-rice-peppers", day: "Sunday", title: "Lentil rice pepper bowls",
            description: "Brown rice, lentils, peppers, spinach, and smoky seasoning in one quick bowl.",
            servings: 2, prepMinutes: 8, cookMinutes: 20, calories: 490, proteinGrams: 26, imageAlignment: 0.56,
            ingredients: [
                .init(ingredientID: "lentils", name: "Cooked lentils", quantity: 15, unit: "oz"),
                .init(ingredientID: "brown_rice", name: "Brown rice", quantity: 8, unit: "oz"),
                .init(ingredientID: "bell_pepper", name: "Bell pepper", quantity: 1, unit: "count"),
                .init(ingredientID: "spinach", name: "Baby spinach", quantity: 5, unit: "oz"),
                .init(ingredientID: "smoked_paprika", name: "Smoked paprika", quantity: 1, unit: "tsp")
            ] + seasoning,
            instructions: ["Cook the rice.", "Warm lentils with pepper and paprika.", "Fold in spinach and serve over rice."]
        ),
        Meal(
            id: "egg-quinoa-bowls", day: "Monday", title: "Egg and quinoa power bowls",
            description: "Jammy eggs, quinoa, spinach, and crisp peppers with a bright lime finish.",
            servings: 2, prepMinutes: 8, cookMinutes: 15, calories: 480, proteinGrams: 28, imageAlignment: 0.48,
            ingredients: [
                .init(ingredientID: "eggs", name: "Eggs", quantity: 4, unit: "count"),
                .init(ingredientID: "quinoa", name: "Quinoa", quantity: 8, unit: "oz"),
                .init(ingredientID: "spinach", name: "Baby spinach", quantity: 5, unit: "oz"),
                .init(ingredientID: "bell_pepper", name: "Bell pepper", quantity: 1, unit: "count"),
                .init(ingredientID: "lime", name: "Lime", quantity: 1, unit: "count")
            ] + seasoning,
            instructions: ["Cook the quinoa and eggs.", "Quickly sauté pepper and spinach.", "Build bowls and finish with lime."]
        )
    ]

    private static func item(
        _ id: String, _ ingredient: String, _ product: String, _ package: String,
        _ required: String, _ count: Int, _ cents: Int, _ department: Department,
        _ meals: [String], owned: Bool = false
    ) -> BasketItem {
        BasketItem(id: "basket-\(id)", ingredientID: id, displayName: ingredient, productName: product,
                   packageDisplay: package, requiredDisplay: required, packageCount: count,
                   totalPriceCents: cents, department: department, mealIDs: meals, pantryStatus: owned)
    }

    static let basket: [BasketItem] = [
        item("zucchini", "Zucchini", "Zucchini squash", "2 count", "2 count", 1, 249, .produce, ["pesto-rigatoni", "sausage-pepper-pan"]),
        item("bell_pepper", "Bell pepper", "Tri-color bell peppers", "3 count", "5 count", 2, 798, .produce, ["crispy-chicken-tacos", "turkey-rice-bowls", "smoky-turkey-chili", "sausage-pepper-pan"]),
        item("yellow_onion", "Yellow onion", "Yellow onions", "3 count bag", "3 count", 1, 249, .produce, ["crispy-chicken-tacos", "turkey-rice-bowls", "smoky-turkey-chili", "sausage-pepper-pan"]),
        item("romaine", "Romaine", "Romaine lettuce", "1 head", "0.5 count", 1, 229, .produce, ["crispy-chicken-tacos"]),
        item("lime", "Lime", "Fresh limes", "3 count", "1 count", 1, 179, .produce, ["crispy-chicken-tacos"]),
        item("chicken_breast", "Chicken breast", "Boneless skinless chicken breast", "about 2.25 lb", "2.5 lb", 2, 2396, .meat, ["pesto-rigatoni", "crispy-chicken-tacos"]),
        item("ground_turkey", "Ground turkey", "93% lean ground turkey", "1 lb", "2 lb", 2, 1098, .meat, ["turkey-rice-bowls", "smoky-turkey-chili"]),
        item("chicken_sausage", "Chicken sausage", "Roasted garlic chicken sausage", "12 oz · 4 links", "12 oz", 1, 499, .meat, ["sausage-pepper-pan"]),
        item("parmesan", "Parmesan", "Freshly shredded parmesan", "6 oz", "2 oz", 1, 449, .dairy, ["pesto-rigatoni"]),
        item("greek_yogurt", "Greek yogurt", "Plain Greek yogurt", "16 oz tub", "8 oz", 1, 429, .dairy, ["crispy-chicken-tacos", "turkey-rice-bowls"]),
        item("flour_tortillas", "Flour tortillas", "Soft taco flour tortillas", "10 count", "6 count", 1, 269, .bakery, ["crispy-chicken-tacos"]),
        item("rigatoni", "Rigatoni", "Rigatoni pasta", "16 oz", "8 oz", 1, 179, .pantry, ["pesto-rigatoni"]),
        item("basil_pesto", "Basil pesto", "Basil pesto", "6 oz jar", "3 oz", 1, 429, .pantry, ["pesto-rigatoni"]),
        item("olive_oil", "Olive oil", "Extra virgin olive oil", "17 fl oz bottle", "5 tbsp", 1, 899, .pantry, meals.map(\.id), owned: true),
        item("brown_rice", "Brown rice", "Long grain brown rice", "32 oz", "1 lb", 1, 349, .pantry, ["turkey-rice-bowls", "sausage-pepper-pan"]),
        item("black_beans", "Black beans", "No-salt-added black beans", "15 oz can", "1.88 lb", 2, 198, .canned, ["turkey-rice-bowls", "smoky-turkey-chili"]),
        item("crushed_tomatoes", "Crushed tomatoes", "Crushed tomatoes", "28 oz can", "1.75 lb", 1, 189, .canned, ["smoky-turkey-chili"]),
        item("kosher_salt", "Kosher salt", "Kosher salt", "26 oz canister", "2.5 tsp", 1, 299, .seasonings, meals.map(\.id), owned: true),
        item("black_pepper", "Black pepper", "Ground black pepper", "3 oz jar", "1.25 tsp", 1, 449, .seasonings, meals.map(\.id), owned: true),
        item("smoked_paprika", "Smoked paprika", "Smoked paprika", "1.8 oz jar", "2 tsp", 1, 349, .seasonings, ["smoky-turkey-chili"])
    ]

    static var plan: MealPlan {
        MealPlan(id: "demo", title: "This week", store: store, budgetCents: 10_000,
                 estimatedTotalCents: 8_537, priceCoverage: 1, priceKind: .fixture,
                 meals: Array(meals.prefix(5)), basket: basket)
    }
}
