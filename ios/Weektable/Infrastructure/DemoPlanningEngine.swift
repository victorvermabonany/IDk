import Foundation

enum DemoPlanningError: LocalizedError {
    case unsatisfiable

    var errorDescription: String? {
        "We couldn’t build this many dinners inside the fixture budget while keeping every restriction. Increase the budget, reduce dinners, or adjust a preference."
    }
}

/// Deterministic fixture-mode engine used only when no live API URL is configured.
/// Production generation and pricing remain server-authoritative in APIPlanRepository.
enum DemoPlanningEngine {
    private struct Product {
        let ingredientID: String
        let name: String
        let packageQuantity: Double
        let unit: String
        let packageDisplay: String
        let priceCents: Int
        let department: Department
        let allergens: Set<String>
        let animalDerived: Bool
        let vegetarian: Bool
    }

    private static let products: [String: Product] = {
        let values: [Product] = [
            .init(ingredientID: "chicken_breast", name: "Boneless skinless chicken breast", packageQuantity: 1.5, unit: "lb", packageDisplay: "about 1.5 lb", priceCents: 899, department: .meat, allergens: [], animalDerived: true, vegetarian: false),
            .init(ingredientID: "ground_turkey", name: "93% lean ground turkey", packageQuantity: 1, unit: "lb", packageDisplay: "1 lb", priceCents: 549, department: .meat, allergens: [], animalDerived: true, vegetarian: false),
            .init(ingredientID: "chicken_sausage", name: "Roasted garlic chicken sausage", packageQuantity: 12, unit: "oz", packageDisplay: "12 oz · 4 links", priceCents: 499, department: .meat, allergens: [], animalDerived: true, vegetarian: false),
            .init(ingredientID: "tofu", name: "Extra-firm tofu", packageQuantity: 14, unit: "oz", packageDisplay: "14 oz", priceCents: 299, department: .produce, allergens: ["soy"], animalDerived: false, vegetarian: true),
            .init(ingredientID: "eggs", name: "Large eggs", packageQuantity: 12, unit: "count", packageDisplay: "12 count", priceCents: 399, department: .dairy, allergens: ["eggs"], animalDerived: true, vegetarian: true),
            .init(ingredientID: "greek_yogurt", name: "Plain Greek yogurt", packageQuantity: 16, unit: "oz", packageDisplay: "16 oz tub", priceCents: 429, department: .dairy, allergens: ["milk"], animalDerived: true, vegetarian: true),
            .init(ingredientID: "parmesan", name: "Freshly shredded parmesan", packageQuantity: 6, unit: "oz", packageDisplay: "6 oz", priceCents: 449, department: .dairy, allergens: ["milk"], animalDerived: true, vegetarian: true),
            .init(ingredientID: "cheddar", name: "Sharp cheddar", packageQuantity: 8, unit: "oz", packageDisplay: "8 oz", priceCents: 379, department: .dairy, allergens: ["milk"], animalDerived: true, vegetarian: true),
            .init(ingredientID: "rigatoni", name: "Rigatoni pasta", packageQuantity: 16, unit: "oz", packageDisplay: "16 oz", priceCents: 179, department: .pantry, allergens: ["wheat"], animalDerived: false, vegetarian: true),
            .init(ingredientID: "flour_tortillas", name: "Soft taco flour tortillas", packageQuantity: 10, unit: "count", packageDisplay: "10 count", priceCents: 269, department: .bakery, allergens: ["wheat"], animalDerived: false, vegetarian: true),
            .init(ingredientID: "corn_tortillas", name: "Corn tortillas", packageQuantity: 12, unit: "count", packageDisplay: "12 count", priceCents: 249, department: .bakery, allergens: [], animalDerived: false, vegetarian: true),
            .init(ingredientID: "brown_rice", name: "Long grain brown rice", packageQuantity: 32, unit: "oz", packageDisplay: "32 oz", priceCents: 349, department: .pantry, allergens: [], animalDerived: false, vegetarian: true),
            .init(ingredientID: "quinoa", name: "Quinoa", packageQuantity: 16, unit: "oz", packageDisplay: "16 oz", priceCents: 499, department: .pantry, allergens: [], animalDerived: false, vegetarian: true),
            .init(ingredientID: "black_beans", name: "No-salt-added black beans", packageQuantity: 15, unit: "oz", packageDisplay: "15 oz can", priceCents: 99, department: .canned, allergens: [], animalDerived: false, vegetarian: true),
            .init(ingredientID: "chickpeas", name: "No-salt-added chickpeas", packageQuantity: 15, unit: "oz", packageDisplay: "15 oz can", priceCents: 109, department: .canned, allergens: [], animalDerived: false, vegetarian: true),
            .init(ingredientID: "lentils", name: "Cooked lentils", packageQuantity: 15, unit: "oz", packageDisplay: "15 oz can", priceCents: 139, department: .canned, allergens: [], animalDerived: false, vegetarian: true),
            .init(ingredientID: "crushed_tomatoes", name: "Crushed tomatoes", packageQuantity: 28, unit: "oz", packageDisplay: "28 oz can", priceCents: 189, department: .canned, allergens: [], animalDerived: false, vegetarian: true),
            .init(ingredientID: "coconut_milk", name: "Coconut milk", packageQuantity: 13.5, unit: "fl_oz", packageDisplay: "13.5 fl oz can", priceCents: 229, department: .canned, allergens: [], animalDerived: false, vegetarian: true),
            .init(ingredientID: "basil_pesto", name: "Basil pesto", packageQuantity: 6, unit: "oz", packageDisplay: "6 oz jar", priceCents: 429, department: .pantry, allergens: ["milk"], animalDerived: true, vegetarian: true),
            .init(ingredientID: "soy_sauce", name: "Soy sauce", packageQuantity: 15, unit: "tbsp", packageDisplay: "15 fl oz bottle", priceCents: 299, department: .pantry, allergens: ["soy", "wheat"], animalDerived: false, vegetarian: true),
            .init(ingredientID: "zucchini", name: "Zucchini squash", packageQuantity: 1, unit: "count", packageDisplay: "1 count", priceCents: 129, department: .produce, allergens: [], animalDerived: false, vegetarian: true),
            .init(ingredientID: "bell_pepper", name: "Tri-color bell peppers", packageQuantity: 3, unit: "count", packageDisplay: "3 count", priceCents: 399, department: .produce, allergens: [], animalDerived: false, vegetarian: true),
            .init(ingredientID: "romaine", name: "Romaine lettuce", packageQuantity: 1, unit: "count", packageDisplay: "1 head", priceCents: 229, department: .produce, allergens: [], animalDerived: false, vegetarian: true),
            .init(ingredientID: "lime", name: "Fresh limes", packageQuantity: 3, unit: "count", packageDisplay: "3 count", priceCents: 179, department: .produce, allergens: [], animalDerived: false, vegetarian: true),
            .init(ingredientID: "broccoli", name: "Broccoli crown", packageQuantity: 1, unit: "count", packageDisplay: "1 crown", priceCents: 199, department: .produce, allergens: [], animalDerived: false, vegetarian: true),
            .init(ingredientID: "spinach", name: "Baby spinach", packageQuantity: 5, unit: "oz", packageDisplay: "5 oz", priceCents: 299, department: .produce, allergens: [], animalDerived: false, vegetarian: true),
            .init(ingredientID: "sweet_potato", name: "Sweet potato", packageQuantity: 1, unit: "lb", packageDisplay: "about 1 lb", priceCents: 149, department: .produce, allergens: [], animalDerived: false, vegetarian: true),
            .init(ingredientID: "olive_oil", name: "Extra virgin olive oil", packageQuantity: 34, unit: "tbsp", packageDisplay: "17 fl oz bottle", priceCents: 899, department: .pantry, allergens: [], animalDerived: false, vegetarian: true),
            .init(ingredientID: "kosher_salt", name: "Kosher salt", packageQuantity: 156, unit: "tsp", packageDisplay: "26 oz canister", priceCents: 299, department: .seasonings, allergens: [], animalDerived: false, vegetarian: true),
            .init(ingredientID: "black_pepper", name: "Ground black pepper", packageQuantity: 34, unit: "tsp", packageDisplay: "3 oz jar", priceCents: 449, department: .seasonings, allergens: [], animalDerived: false, vegetarian: true),
            .init(ingredientID: "smoked_paprika", name: "Smoked paprika", packageQuantity: 12, unit: "tsp", packageDisplay: "1.8 oz jar", priceCents: 349, department: .seasonings, allergens: [], animalDerived: false, vegetarian: true)
        ]
        return Dictionary(uniqueKeysWithValues: values.map { ($0.ingredientID, $0) })
    }()

    static func stores(postalCode: String) -> [Store] {
        DemoData.stores.map { store in
            Store(id: store.id, providerStoreID: store.providerStoreID, name: store.name,
                  retailer: store.retailer, address: "Cincinnati, OH \(postalCode)",
                  zipCode: postalCode, priceKind: .fixture)
        }
    }

    static func makePlan(request: PlannerRequest) throws -> MealPlan {
        let requiredServings = request.householdSize + (request.leftovers.enabled ? max(1, request.leftovers.extraServings) : 0)
        let candidates = DemoData.meals.filter { validates($0, request: request) }
        guard candidates.count >= request.dinnerCount else { throw DemoPlanningError.unsatisfiable }

        var best: (meals: [Meal], basket: [BasketItem], total: Int, score: Double)?
        combinations(candidates, taking: request.dinnerCount).forEach { rawMeals in
            guard validatesCustomCombination(rawMeals, request: request) else { return }
            let meals = rawMeals.enumerated().map { index, meal in scale(meal, servings: requiredServings, dayIndex: index) }
            let basket = buildBasket(meals: meals, request: request)
            let total = basket.reduce(0) { $0 + ($1.pantryStatus ? 0 : $1.totalPriceCents) }
            guard total <= request.budgetCents else { return }
            let target = Double(request.budgetCents) * 0.94
            let targetScore = -abs(Double(total) - target) / 100
            let score = targetScore + preferenceScore(meals, request: request) + overlapScore(meals)
            if best == nil || score > best!.score { best = (meals, basket, total, score) }
        }
        guard let best else { throw DemoPlanningError.unsatisfiable }
        let selectedStore = stores(postalCode: request.store.postalCode).first(where: { $0.id == request.store.id }) ?? stores(postalCode: request.store.postalCode)[0]
        return MealPlan(
            id: "demo-\(UUID().uuidString)", title: "This week", store: selectedStore,
            constraintsUsed: request, budgetCents: request.budgetCents,
            internalTargetCents: Int(Double(request.budgetCents) * 0.94), estimatedTotalCents: best.total,
            priceCoverage: 1, priceKind: .fixture, priceObservedAt: ISO8601DateFormatter().string(from: .now),
            meals: best.meals, basket: best.basket, createdAt: ISO8601DateFormatter().string(from: .now),
            safetyNotice: "Fixture allergen data is limited. Always verify packaged-food labels and cross-contact warnings."
        )
    }

    static func swapCandidates(plan: MealPlan, mealID: String) -> [SwapPreview] {
        guard let index = plan.meals.firstIndex(where: { $0.id == mealID }) else { return [] }
        let usedIDs = Set(plan.meals.map(\.id))
        let current = plan.meals[index]
        return DemoData.meals
            .filter { !usedIDs.contains($0.id) && validates($0, request: plan.constraintsUsed) }
            .compactMap { raw -> SwapPreview? in
                let candidate = scale(raw, servings: current.servings, dayIndex: index, identity: current.id)
                var meals = plan.meals
                meals[index] = candidate
                guard validatesCustomCombination(meals, request: plan.constraintsUsed) else { return nil }
                let basket = buildBasket(meals: meals, request: plan.constraintsUsed)
                let total = basket.reduce(0) { $0 + ($1.pantryStatus ? 0 : $1.totalPriceCents) }
                guard total <= plan.budgetCents else { return nil }
                let oldIngredients = Set(plan.basket.map(\.ingredientID))
                let reused = Set(candidate.ingredients.map(\.ingredientID)).intersection(oldIngredients).count
                return SwapPreview(id: "\(mealID)-\(raw.id)-\(UUID().uuidString)", meal: candidate,
                                   deltaCents: total - plan.estimatedTotalCents,
                                   reusedIngredientCount: reused, resultingTotalCents: total)
            }
            .sorted { $0.deltaCents < $1.deltaCents }
            .prefix(3).map { $0 }
    }

    static func replacing(plan: MealPlan, mealID: String, with preview: SwapPreview) -> MealPlan {
        var meals = plan.meals
        guard let index = meals.firstIndex(where: { $0.id == mealID }) else { return plan }
        meals[index] = preview.meal
        let basket = buildBasket(meals: meals, request: plan.constraintsUsed)
        return MealPlan(id: plan.id, title: plan.title, store: plan.store, constraintsUsed: plan.constraintsUsed,
                        budgetCents: plan.budgetCents, internalTargetCents: plan.internalTargetCents,
                        estimatedTotalCents: basket.reduce(0) { $0 + ($1.pantryStatus ? 0 : $1.totalPriceCents) },
                        priceCoverage: plan.priceCoverage, priceKind: plan.priceKind,
                        priceObservedAt: ISO8601DateFormatter().string(from: .now), meals: meals, basket: basket,
                        createdAt: plan.createdAt, safetyNotice: plan.safetyNotice)
    }

    static func updatingGroceryState(plan: MealPlan, state: GroceryState) -> MealPlan {
        var basket = plan.basket
        for index in basket.indices { basket[index].pantryStatus = state.ownedItemIDs.contains(basket[index].id) }
        return MealPlan(id: plan.id, title: plan.title, store: plan.store, constraintsUsed: plan.constraintsUsed,
                        budgetCents: plan.budgetCents, internalTargetCents: plan.internalTargetCents,
                        estimatedTotalCents: basket.reduce(0) { $0 + ($1.pantryStatus ? 0 : $1.totalPriceCents) },
                        priceCoverage: plan.priceCoverage, priceKind: plan.priceKind,
                        priceObservedAt: ISO8601DateFormatter().string(from: .now), meals: plan.meals, basket: basket,
                        createdAt: plan.createdAt, safetyNotice: plan.safetyNotice)
    }

    private static func validates(_ meal: Meal, request: PlannerRequest) -> Bool {
        guard meal.totalMinutes <= request.maxCookingMinutes else { return false }
        let ingredientProducts = meal.ingredients.compactMap { products[$0.ingredientID] }
        let restrictions = Set(request.dietaryRestrictions.map(normalize))
        let vegetarian = request.nutritionStyle == .vegetarian || restrictions.contains("vegetarian") || restrictions.contains("vegan")
        if vegetarian && ingredientProducts.contains(where: { !$0.vegetarian }) { return false }
        if restrictions.contains("vegan") && ingredientProducts.contains(where: \.animalDerived) { return false }
        if restrictions.contains("dairy free") && ingredientProducts.contains(where: { $0.allergens.contains("milk") }) { return false }
        if restrictions.contains("gluten free") && ingredientProducts.contains(where: { $0.allergens.contains("wheat") }) { return false }
        let allergies = Set(request.allergies.map(normalize))
        if ingredientProducts.contains(where: { !$0.allergens.intersection(allergies).isEmpty }) { return false }
        let searchable = normalize(([meal.title, meal.description] + meal.ingredients.map { $0.name + " " + $0.ingredientID }).joined(separator: " "))
        if request.dislikedFoodItems.map(normalize).contains(where: { !$0.isEmpty && searchable.contains($0) }) { return false }
        let custom = normalize(request.customInstructions)
        if (custom.contains("no oven") || custom.contains("don't use an oven") || custom.contains("do not use an oven")),
           meal.instructions.contains(where: { normalize($0).contains("oven") || normalize($0).contains("roast") }) { return false }
        return meal.ingredients.allSatisfy { $0.quantity > 0 && products[$0.ingredientID] != nil }
    }

    private static func validatesCustomCombination(_ meals: [Meal], request: PlannerRequest) -> Bool {
        let custom = normalize(request.customInstructions)
        if custom.contains("chicken no more than twice") || custom.contains("chicken at most twice") {
            return meals.filter { $0.ingredients.contains(where: { $0.ingredientID.contains("chicken") }) }.count <= 2
        }
        return true
    }

    private static func scale(_ meal: Meal, servings: Int, dayIndex: Int, identity: String? = nil) -> Meal {
        let factor = Double(servings) / Double(meal.servings)
        let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        return Meal(id: identity ?? meal.id, day: days[dayIndex % days.count], title: meal.title,
                    description: meal.description, servings: servings, prepMinutes: meal.prepMinutes,
                    cookMinutes: meal.cookMinutes, calories: meal.calories, proteinGrams: meal.proteinGrams,
                    imageAlignment: meal.imageAlignment,
                    ingredients: meal.ingredients.map { RecipeIngredient(ingredientID: $0.ingredientID, name: $0.name, quantity: $0.quantity * factor, unit: $0.unit) },
                    instructions: meal.instructions)
    }

    private static func buildBasket(meals: [Meal], request: PlannerRequest) -> [BasketItem] {
        var required: [String: (quantity: Double, unit: String, mealIDs: [String])] = [:]
        for meal in meals {
            for ingredient in meal.ingredients {
                let existing = required[ingredient.ingredientID]
                required[ingredient.ingredientID] = ((existing?.quantity ?? 0) + ingredient.quantity,
                                                     ingredient.unit, (existing?.mealIDs ?? []) + [meal.id])
            }
        }
        let pantry = Set(request.pantryItems.map(normalize))
        let factor = request.store.id == DemoData.valueStore.id ? 0.86 : 1.0
        return required.compactMap { ingredientID, value -> BasketItem? in
            guard let product = products[ingredientID], product.unit == value.unit else { return nil }
            let count = max(1, Int(ceil(value.quantity / product.packageQuantity)))
            let owned = pantry.contains(normalize(ingredientID)) || pantry.contains(normalize(product.name)) || pantry.contains(normalize(ingredientID.replacingOccurrences(of: "_", with: " ")))
            return BasketItem(id: "basket-\(ingredientID)", ingredientID: ingredientID,
                              displayName: value.mealIDs.isEmpty ? product.name : (meals.flatMap(\.ingredients).first(where: { $0.ingredientID == ingredientID })?.name ?? product.name),
                              productName: product.name, packageDisplay: product.packageDisplay,
                              requiredDisplay: "\(format(value.quantity)) \(value.unit.replacingOccurrences(of: "_", with: " "))",
                              packageCount: count, totalPriceCents: Int((Double(product.priceCents * count) * factor).rounded()),
                              department: product.department, mealIDs: Array(Set(value.mealIDs)).sorted(), pantryStatus: owned)
        }.sorted { lhs, rhs in
            let left = Department.allCases.firstIndex(of: lhs.department) ?? 99
            let right = Department.allCases.firstIndex(of: rhs.department) ?? 99
            return left == right ? lhs.displayName < rhs.displayName : left < right
        }
    }

    private static func preferenceScore(_ meals: [Meal], request: PlannerRequest) -> Double {
        let cuisines = Set(request.preferredCuisines.map(normalize))
        let cuisineMatches = meals.filter { meal in cuisines.contains(cuisine(for: meal)) }.count
        var score = Double(cuisineMatches * 8)
        switch request.nutritionStyle {
        case .highProtein: score += Double(meals.reduce(0) { $0 + $1.proteinGrams }) / 4
        case .quick: score -= Double(meals.reduce(0) { $0 + $1.totalMinutes + $1.ingredients.count }) / 5
        case .budgetFirst: score += overlapScore(meals) * 2
        case .lighter: score -= Double(meals.reduce(0) { $0 + $1.calories }) / 80
        case .balanced: score += Double(Set(meals.map(cuisine)).count * 4)
        case .vegetarian: score += Double(meals.reduce(0) { $0 + $1.proteinGrams }) / 8
        }
        if normalize(request.customInstructions).contains("reheat well") {
            score += Double(meals.filter { meal in
                ["chili", "curry", "lentil"].contains(where: { keyword in meal.title.lowercased().contains(keyword) })
            }.count * 4)
        }
        return score
    }

    private static func overlapScore(_ meals: [Meal]) -> Double {
        let all = meals.flatMap { $0.ingredients.map(\.ingredientID) }
        return Double(all.count - Set(all).count) * 2
    }

    private static func cuisine(for meal: Meal) -> String {
        let id = meal.id
        if id.contains("taco") || id.contains("quesadilla") || id.contains("chili") || id.contains("rice-bowl") { return "mexican" }
        if id.contains("rigatoni") || id.contains("pesto") { return "italian" }
        if id.contains("mediterranean") || id.contains("quinoa") { return "mediterranean" }
        if id.contains("tofu") || id.contains("coconut") { return "asian inspired" }
        return "american"
    }

    private static func normalize(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func format(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.2g", value)
    }

    private static func combinations<T>(_ values: [T], taking count: Int) -> [[T]] {
        guard count > 0 else { return [[]] }
        guard values.count >= count else { return [] }
        if count == 1 { return values.map { [$0] } }
        var result: [[T]] = []
        for index in 0...(values.count - count) {
            for tail in combinations(Array(values[(index + 1)...]), taking: count - 1) {
                result.append([values[index]] + tail)
            }
        }
        return result
    }
}
