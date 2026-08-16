import Foundation

enum NutritionStyle: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case balanced
    case highProtein = "high-protein"
    case vegetarian
    case quick
    case budgetFirst = "budget-first"
    case lighter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .balanced: "Balanced"
        case .highProtein: "High protein"
        case .vegetarian: "Vegetarian"
        case .quick: "Quick & easy"
        case .budgetFirst: "Budget first"
        case .lighter: "Lighter"
        }
    }

    var subtitle: String {
        switch self {
        case .balanced: "A little of everything"
        case .highProtein: "Protein-forward dinners"
        case .vegetarian: "No meat or seafood"
        case .quick: "Fewer steps and less cleanup"
        case .budgetFirst: "Stretch every package"
        case .lighter: "Fresh, unfussy meals"
        }
    }

    var symbol: String {
        switch self {
        case .balanced: "circle.grid.2x2.fill"
        case .highProtein: "bolt.fill"
        case .vegetarian: "leaf.fill"
        case .quick: "timer"
        case .budgetFirst: "dollarsign.circle.fill"
        case .lighter: "sun.max.fill"
        }
    }
}

struct PlannerRequest: Codable, Equatable, Sendable {
    var zipCode = "45202"
    var storeID = "demo-kroger-45202"
    var budgetDollars = 100
    var householdSize = 2
    var dinnerCount = 5
    var plannedLeftovers = false
    var nutritionStyle: NutritionStyle = .highProtein
    var dietaryRestrictions: Set<String> = []
    var allergies: Set<String> = []
    var dislikedFoods = "mushrooms, seafood"
    var preferredCuisines: Set<String> = []
    var maxCookingMinutes = 40
    var pantryItems: Set<String> = ["olive oil", "salt", "black pepper"]
    var customPantryItems = ""

    enum CodingKeys: String, CodingKey {
        case zipCode, storeID = "storeId", budgetDollars, householdSize, dinnerCount
        case plannedLeftovers, nutritionStyle, dietaryRestrictions, allergies
        case dislikedFoods, preferredCuisines, maxCookingMinutes, pantryItems
        case customPantryItems
    }
}

enum PriceKind: String, Codable, Hashable, Sendable {
    case live, feed, estimated, fixture
}

struct Store: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let retailer: String
    let address: String
    let zipCode: String
    let priceKind: PriceKind
}

struct RecipeIngredient: Codable, Hashable, Identifiable, Sendable {
    let ingredientID: String
    let name: String
    let quantity: Double
    let unit: String

    var id: String { "\(ingredientID)-\(quantity)-\(unit)" }
    var formattedQuantity: String {
        let value = quantity.rounded() == quantity ? String(Int(quantity)) : String(format: "%.2g", quantity)
        return "\(value) \(unit.replacingOccurrences(of: "_", with: " "))"
    }

    enum CodingKeys: String, CodingKey {
        case ingredientID = "ingredientId", name, quantity, unit
    }
}

struct Meal: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let day: String
    let title: String
    let description: String
    let servings: Int
    let prepMinutes: Int
    let cookMinutes: Int
    let calories: Int
    let proteinGrams: Int
    let imageAlignment: Double
    let ingredients: [RecipeIngredient]
    let instructions: [String]

    var totalMinutes: Int { prepMinutes + cookMinutes }
}

enum Department: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case produce = "Produce"
    case meat = "Meat"
    case dairy = "Dairy & eggs"
    case bakery = "Bakery"
    case pantry = "Pantry"
    case canned = "Canned goods"
    case seasonings = "Seasonings"
    case other = "Other"

    var id: String { rawValue }
}

struct BasketItem: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let ingredientID: String
    let displayName: String
    let productName: String
    let packageDisplay: String
    let requiredDisplay: String
    let packageCount: Int
    let totalPriceCents: Int
    let department: Department
    let mealIDs: [String]
    var pantryStatus: Bool

    enum CodingKeys: String, CodingKey {
        case id, ingredientID = "ingredientId", displayName, productName, packageDisplay
        case requiredDisplay, packageCount, totalPriceCents, department
        case mealIDs = "mealIds", pantryStatus
    }
}

struct MealPlan: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let store: Store
    let budgetCents: Int
    var estimatedTotalCents: Int
    let priceCoverage: Double
    let priceKind: PriceKind
    var meals: [Meal]
    var basket: [BasketItem]

    var remainingCents: Int { budgetCents - estimatedTotalCents }
    var totalMinutes: Int { meals.reduce(0) { $0 + $1.totalMinutes } }
}

enum GenerationStage: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case planning = "Planning your meals"
    case combining = "Combining ingredients"
    case packages = "Checking complete packages"
    case budget = "Balancing your budget"
    case finalizing = "Finalizing your week"

    var id: String { rawValue }
}

struct GenerationJob: Codable, Sendable {
    let id: String
    let planID: String

    enum CodingKeys: String, CodingKey {
        case id, planID = "planId"
    }
}

struct GenerationUpdate: Codable, Sendable {
    let jobID: String
    let stage: GenerationStage
    let progress: Double
    let completedPlanID: String?

    enum CodingKeys: String, CodingKey {
        case jobID = "jobId", stage, progress, completedPlanID = "completedPlanId"
    }
}

struct SwapPreview: Codable, Identifiable, Sendable {
    let id: String
    let meal: Meal
    let deltaCents: Int
    let reusedIngredientCount: Int
    let resultingTotalCents: Int
}

extension Int {
    var currency: String {
        (Double(self) / 100).formatted(.currency(code: "USD"))
    }
}
