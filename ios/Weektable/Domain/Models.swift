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

struct PlannerStoreConstraint: Codable, Equatable, Sendable {
    var id = "demo-kroger-45202"
    var locationID = "fixture-45202"
    var postalCode = "45202"
    enum CodingKeys: String, CodingKey { case id, locationID = "locationId", postalCode }
}

struct LeftoverConstraint: Codable, Equatable, Sendable {
    var enabled = false
    var extraServings = 0
}

struct PlannerRequest: Codable, Equatable, Sendable {
    var store = PlannerStoreConstraint()
    var budgetCents = 10_000
    var householdSize = 2
    var dinnerCount = 5
    var leftovers = LeftoverConstraint()
    var nutritionStyle: NutritionStyle = .highProtein
    var dietaryRestrictions: Set<String> = []
    var allergies: Set<String> = []
    var dislikedFoodItems: Set<String> = ["mushrooms", "seafood"]
    var preferredCuisines: Set<String> = []
    var maxCookingMinutes = 40
    var pantryItems: Set<String> = ["olive oil", "salt", "black pepper"]
    var customInstructions = ""

    var zipCode: String {
        get { store.postalCode }
        set { store.postalCode = newValue }
    }
    var storeID: String {
        get { store.id }
        set { store.id = newValue }
    }
    var budgetDollars: Int {
        get { budgetCents / 100 }
        set { budgetCents = newValue * 100 }
    }
    var plannedLeftovers: Bool {
        get { leftovers.enabled }
        set { leftovers = LeftoverConstraint(enabled: newValue, extraServings: newValue ? max(1, leftovers.extraServings) : 0) }
    }
    var customInstruction: String? {
        get { customInstructions.isEmpty ? nil : customInstructions }
        set { customInstructions = newValue ?? "" }
    }
    var dislikedFoods: String {
        get { dislikedFoodItems.sorted().joined(separator: ", ") }
        set {
            dislikedFoodItems = Set(newValue.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }.filter { !$0.isEmpty })
        }
    }

    enum CodingKeys: String, CodingKey {
        case store, budgetCents, householdSize, dinnerCount, leftovers
        case nutritionStyle, dietaryRestrictions, allergies
        case dislikedFoodItems = "dislikedFoods", preferredCuisines, maxCookingMinutes, pantryItems
        case customInstructions
    }
}

enum PriceKind: String, Codable, Hashable, Sendable {
    case live, feed, estimated, fixture
}

struct Store: Codable, Hashable, Sendable {
    let id: String
    let providerStoreID: String
    let name: String
    let retailer: String
    let address: String
    let zipCode: String
    let priceKind: PriceKind

    init(id: String, providerStoreID: String = "fixture-45202", name: String, retailer: String, address: String, zipCode: String, priceKind: PriceKind) {
        self.id = id
        self.providerStoreID = providerStoreID
        self.name = name
        self.retailer = retailer
        self.address = address
        self.zipCode = zipCode
        self.priceKind = priceKind
    }

    enum CodingKeys: String, CodingKey {
        case id, providerStoreID = "providerStoreId", name, retailer, address, zipCode, priceKind
    }
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

    var specificImageAssetName: String? {
        switch title.lowercased() {
        case let value where value.contains("pesto rigatoni"): "meal-pesto-rigatoni"
        case let value where value.contains("chicken tacos"): "meal-crispy-chicken-tacos"
        case let value where value.contains("turkey rice bowls"): "meal-turkey-rice-bowls"
        case let value where value.contains("turkey chili"): "meal-smoky-turkey-chili"
        case let value where value.contains("sausage") && value.contains("peppers"): "meal-sausage-peppers"
        case let value where value.contains("turkey rigatoni"): "meal-turkey-rigatoni"
        case let value where value.contains("black bean") && value.contains("quesadilla"): "meal-black-bean-quesadillas"
        default: nil
        }
    }

    var imageAssetName: String { specificImageAssetName ?? "weektable-dinners" }
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
    let constraintsUsed: PlannerRequest
    let budgetCents: Int
    let internalTargetCents: Int
    var estimatedTotalCents: Int
    let priceCoverage: Double
    let priceKind: PriceKind
    let priceObservedAt: String
    var meals: [Meal]
    var basket: [BasketItem]
    let createdAt: String
    let safetyNotice: String

    init(
        id: String, title: String, store: Store, constraintsUsed: PlannerRequest = PlannerRequest(),
        budgetCents: Int, internalTargetCents: Int? = nil, estimatedTotalCents: Int,
        priceCoverage: Double, priceKind: PriceKind, priceObservedAt: String = "",
        meals: [Meal], basket: [BasketItem], createdAt: String = "", safetyNotice: String = ""
    ) {
        self.id = id
        self.title = title
        self.store = store
        self.constraintsUsed = constraintsUsed
        self.budgetCents = budgetCents
        self.internalTargetCents = internalTargetCents ?? Int(Double(budgetCents) * 0.94)
        self.estimatedTotalCents = estimatedTotalCents
        self.priceCoverage = priceCoverage
        self.priceKind = priceKind
        self.priceObservedAt = priceObservedAt
        self.meals = meals
        self.basket = basket
        self.createdAt = createdAt
        self.safetyNotice = safetyNotice
    }

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
