import Foundation

protocol PlanRepository: Sendable {
    func createPlan(request: PlannerRequest, idempotencyKey: String) async throws -> GenerationJob
    func generationUpdates(jobID: String) async -> AsyncThrowingStream<GenerationUpdate, Error>
    func plan(id: String) async throws -> MealPlan
    func swapPreviews(planID: String, mealID: String) async throws -> [SwapPreview]
    func applySwap(planID: String, mealID: String, previewID: String) async throws -> MealPlan
}

actor DemoPlanRepository: PlanRepository {
    private var currentPlan = DemoData.plan
    private var previewsByID: [String: SwapPreview] = [:]

    func createPlan(request: PlannerRequest, idempotencyKey: String) async throws -> GenerationJob {
        var plan = DemoData.plan
        plan = MealPlan(
            id: plan.id,
            title: plan.title,
            store: plan.store,
            budgetCents: request.budgetDollars * 100,
            estimatedTotalCents: plan.estimatedTotalCents,
            priceCoverage: plan.priceCoverage,
            priceKind: plan.priceKind,
            meals: Array(DemoData.meals.prefix(request.dinnerCount)),
            basket: plan.basket
        )
        currentPlan = plan
        return GenerationJob(id: "demo-\(idempotencyKey)", planID: plan.id)
    }

    func generationUpdates(jobID: String) async -> AsyncThrowingStream<GenerationUpdate, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                for (index, stage) in GenerationStage.allCases.enumerated() {
                    try await Task.sleep(for: .milliseconds(520))
                    try Task.checkCancellation()
                    continuation.yield(
                        GenerationUpdate(
                            jobID: jobID,
                            stage: stage,
                            progress: Double(index + 1) / Double(GenerationStage.allCases.count),
                            completedPlanID: index == GenerationStage.allCases.count - 1 ? currentPlan.id : nil
                        )
                    )
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func plan(id: String) async throws -> MealPlan { currentPlan }

    func swapPreviews(planID: String, mealID: String) async throws -> [SwapPreview] {
        guard let currentMeal = currentPlan.meals.first(where: { $0.id == mealID }) else { return [] }
        let usedTitles = Set(currentPlan.meals.map(\.title))
        let candidates = DemoData.meals.filter { !usedTitles.contains($0.title) }.prefix(2)
        let deltas = [-889, -1558]
        let previews = candidates.enumerated().map { index, candidate in
            let replacement = Meal(
                id: currentMeal.id, day: currentMeal.day, title: candidate.title,
                description: candidate.description, servings: currentMeal.servings,
                prepMinutes: candidate.prepMinutes, cookMinutes: candidate.cookMinutes,
                calories: candidate.calories, proteinGrams: candidate.proteinGrams,
                imageAlignment: candidate.imageAlignment, ingredients: candidate.ingredients,
                instructions: candidate.instructions
            )
            return SwapPreview(
                id: "\(mealID)-\(candidate.id)", meal: replacement, deltaCents: deltas[index],
                reusedIngredientCount: index == 0 ? 8 : 9,
                resultingTotalCents: currentPlan.estimatedTotalCents + deltas[index]
            )
        }
        previews.forEach { previewsByID[$0.id] = $0 }
        return previews
    }

    func applySwap(planID: String, mealID: String, previewID: String) async throws -> MealPlan {
        guard let preview = previewsByID[previewID] else { return currentPlan }
        currentPlan.meals = currentPlan.meals.map { $0.id == mealID ? preview.meal : $0 }
        currentPlan.estimatedTotalCents = preview.resultingTotalCents
        return currentPlan
    }
}

actor APIPlanRepository: PlanRepository {
    private let client: APIClient

    init(client: APIClient) { self.client = client }

    private struct JobEnvelope: Decodable { let job: GenerationJob }
    private struct PlanEnvelope: Decodable { let plan: MealPlan }
    private struct UpdatesEnvelope: Decodable { let updates: [GenerationUpdate] }
    private struct SwapEnvelope: Decodable { let previews: [SwapPreview] }
    private struct SwapRequest: Encodable {
        let previewID: String
        enum CodingKeys: String, CodingKey { case previewID = "previewId" }
    }
    private struct PlannerRequestPayload: Encodable {
        let zipCode: String
        let storeId: String
        let budgetDollars: Int
        let householdSize: Int
        let dinnerCount: Int
        let plannedLeftovers: Bool
        let nutritionStyle: NutritionStyle
        let dietaryRestrictions: [String]
        let allergies: [String]
        let dislikedFoods: [String]
        let preferredCuisines: [String]
        let maxCookingMinutes: Int
        let pantryItems: [String]
        let customInstruction: String

        init(_ request: PlannerRequest) {
            zipCode = request.zipCode
            storeId = request.storeID
            budgetDollars = request.budgetDollars
            householdSize = request.householdSize
            dinnerCount = request.dinnerCount
            plannedLeftovers = request.plannedLeftovers
            nutritionStyle = request.nutritionStyle
            dietaryRestrictions = request.dietaryRestrictions.sorted()
            allergies = request.allergies.sorted()
            dislikedFoods = request.dislikedFoods
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            preferredCuisines = request.preferredCuisines.sorted()
            maxCookingMinutes = request.maxCookingMinutes
            pantryItems = request.pantryItems.sorted()
            customInstruction = ""
        }
    }

    func createPlan(request: PlannerRequest, idempotencyKey: String) async throws -> GenerationJob {
        let response: JobEnvelope = try await client.send(
            "/v1/plan-requests", method: "POST", body: PlannerRequestPayload(request), idempotencyKey: idempotencyKey
        )
        return response.job
    }

    func generationUpdates(jobID: String) async -> AsyncThrowingStream<GenerationUpdate, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var finished = false
                    while !finished {
                        let response: UpdatesEnvelope = try await client.send("/v1/generation-jobs/\(jobID)")
                        for update in response.updates {
                            continuation.yield(update)
                            finished = update.completedPlanID != nil
                        }
                        if !finished { try await Task.sleep(for: .seconds(1)) }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func plan(id: String) async throws -> MealPlan {
        let response: PlanEnvelope = try await client.send("/v1/plans/\(id)")
        return response.plan
    }

    func swapPreviews(planID: String, mealID: String) async throws -> [SwapPreview] {
        let response: SwapEnvelope = try await client.send("/v1/plans/\(planID)/meals/\(mealID)/swap-previews")
        return response.previews
    }

    func applySwap(planID: String, mealID: String, previewID: String) async throws -> MealPlan {
        let response: PlanEnvelope = try await client.send(
            "/v1/plans/\(planID)/meals/\(mealID)/swap",
            method: "POST",
            body: SwapRequest(previewID: previewID),
            idempotencyKey: UUID().uuidString
        )
        return response.plan
    }
}
