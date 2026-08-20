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

struct PricingProvenance: Codable, Equatable, Sendable {
    let pricingMode: String
    let provider: String
    let providerName: String
    let storeName: String
    let providerStoreID: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case pricingMode, provider, providerName, storeName, updatedAt
        case providerStoreID = "providerStoreId"
    }
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
    var imageKey: String? = nil
    var imageMatch: String? = nil
    let ingredients: [RecipeIngredient]
    let instructions: [String]

    var totalMinutes: Int { prepMinutes + cookMinutes }

    var specificImageAssetName: String? {
        if imageMatch == "fallback" { return nil }
        if let imageKey, Self.supportedImageAssets.contains(imageKey) { return imageKey }
        guard imageMatch == nil else { return nil }
        return Self.exactImageAssetsByMealID[id]
    }

    var imageAssetName: String { specificImageAssetName ?? "weektable-dinners" }

    private static let exactImageAssetsByMealID: [String: String] = [
        "pesto-rigatoni": "meal-pesto-rigatoni", "crispy-chicken-tacos": "meal-crispy-chicken-tacos",
        "turkey-rice-bowls": "meal-turkey-rice-bowls", "smoky-turkey-chili": "meal-smoky-turkey-chili",
        "sausage-pepper-pan": "meal-sausage-peppers", "turkey-tomato-rigatoni": "meal-turkey-rigatoni",
        "bean-pepper-quesadillas": "meal-black-bean-quesadillas", "tofu-rice-bowls": "meal-tofu-rice-bowls",
        "lentil-tomato-bowls": "meal-lentil-tomato-bowls", "chickpea-coconut-curry": "meal-chickpea-coconut-curry",
        "sweet-potato-tacos": "meal-sweet-potato-black-bean-tacos", "sweet-potato-black-bean-tacos": "meal-sweet-potato-black-bean-tacos",
        "mediterranean-quinoa": "meal-mediterranean-chickpea-quinoa", "mediterranean-chickpea-quinoa": "meal-mediterranean-chickpea-quinoa",
        "tofu-quinoa-skillet": "meal-tofu-quinoa-skillet", "lentil-rice-stuffed-peppers": "meal-lentil-rice-pepper-bowls",
        "egg-quinoa-vegetable-bowls": "meal-egg-quinoa-vegetable-bowls"
    ]
    private static let supportedImageAssets: Set<String> = Set(exactImageAssetsByMealID.values)
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
    let pricingProvenance: PricingProvenance?
    var meals: [Meal]
    var basket: [BasketItem]
    let createdAt: String
    let safetyNotice: String

    init(
        id: String, title: String, store: Store, constraintsUsed: PlannerRequest = PlannerRequest(),
        budgetCents: Int, internalTargetCents: Int? = nil, estimatedTotalCents: Int,
        priceCoverage: Double, priceKind: PriceKind, priceObservedAt: String = "", pricingProvenance: PricingProvenance? = nil,
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
        self.pricingProvenance = pricingProvenance
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
    case combining = "Building your grocery list"
    case packages = "Checking your store"
    case budget = "Balancing your budget"
    case finalizing = "Finishing your week"

    var id: String { rawValue }

    var supportingCopy: String {
        switch self {
        case .planning: "Finding meals that fit your preferences."
        case .combining: "Combining ingredients across the week."
        case .packages: "Matching ingredients to available products and prices."
        case .budget: "Making sure the basket fits your target."
        case .finalizing: "Putting everything together."
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "Combining ingredients": self = .combining
        case "Checking complete packages": self = .packages
        case "Finalizing your week": self = .finalizing
        default:
            guard let stage = Self(rawValue: value) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unknown generation stage: \(value)"
                )
            }
            self = stage
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
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
    let completedPlanID: String?
    let metadata: GenerationMetadata?

    init(jobID: String, stage: GenerationStage, completedPlanID: String?, metadata: GenerationMetadata? = nil) {
        self.jobID = jobID
        self.stage = stage
        self.completedPlanID = completedPlanID
        self.metadata = metadata
    }

    enum CodingKeys: String, CodingKey {
        case jobID = "jobId", stage, completedPlanID = "completedPlanId", metadata
    }
}

struct GenerationMetadata: Codable, Equatable, Sendable {
    let ingredientCount: Int?
    let productsMatched: Int?
    let reusedIngredientCount: Int?
    let underBudgetCents: Int?

    init(
        ingredientCount: Int? = nil,
        productsMatched: Int? = nil,
        reusedIngredientCount: Int? = nil,
        underBudgetCents: Int? = nil
    ) {
        self.ingredientCount = ingredientCount
        self.productsMatched = productsMatched
        self.reusedIngredientCount = reusedIngredientCount
        self.underBudgetCents = underBudgetCents
    }

    var isEmpty: Bool {
        ingredientCount == nil && productsMatched == nil && reusedIngredientCount == nil && underBudgetCents == nil
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
