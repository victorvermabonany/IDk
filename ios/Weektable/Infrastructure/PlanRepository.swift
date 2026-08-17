import Foundation

protocol PlanRepository: Sendable {
    func findStores(postalCode: String) async throws -> [Store]
    func createPlan(request: PlannerRequest, idempotencyKey: String) async throws -> GenerationJob
    func generationUpdates(jobID: String) async -> AsyncThrowingStream<GenerationUpdate, Error>
    func plan(id: String) async throws -> MealPlan
    func swapPreviews(planID: String, mealID: String) async throws -> [SwapPreview]
    func applySwap(planID: String, mealID: String, previewID: String) async throws -> MealPlan
    func updateGroceryState(planID: String, state: GroceryState) async throws -> MealPlan
}

actor UnavailablePlanRepository: PlanRepository {
    let reason: String
    init(reason: String) { self.reason = reason }
    func findStores(postalCode: String) async throws -> [Store] { throw APIError.configuration(reason) }
    func createPlan(request: PlannerRequest, idempotencyKey: String) async throws -> GenerationJob { throw APIError.configuration(reason) }
    func generationUpdates(jobID: String) async -> AsyncThrowingStream<GenerationUpdate, Error> {
        AsyncThrowingStream { $0.finish(throwing: APIError.configuration(reason)) }
    }
    func plan(id: String) async throws -> MealPlan { throw APIError.configuration(reason) }
    func swapPreviews(planID: String, mealID: String) async throws -> [SwapPreview] { throw APIError.configuration(reason) }
    func applySwap(planID: String, mealID: String, previewID: String) async throws -> MealPlan { throw APIError.configuration(reason) }
    func updateGroceryState(planID: String, state: GroceryState) async throws -> MealPlan { throw APIError.configuration(reason) }
}

actor DemoPlanRepository: PlanRepository {
    private var currentPlan = DemoData.plan
    private var previewsByID: [String: SwapPreview] = [:]

    func findStores(postalCode: String) async throws -> [Store] {
        DemoPlanningEngine.stores(postalCode: postalCode)
    }

    func createPlan(request: PlannerRequest, idempotencyKey: String) async throws -> GenerationJob {
        let plan = try DemoPlanningEngine.makePlan(request: request)
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
        let previews = DemoPlanningEngine.swapCandidates(plan: currentPlan, mealID: mealID)
        previews.forEach { previewsByID[$0.id] = $0 }
        return previews
    }

    func applySwap(planID: String, mealID: String, previewID: String) async throws -> MealPlan {
        guard let preview = previewsByID[previewID] else { return currentPlan }
        currentPlan = DemoPlanningEngine.replacing(plan: currentPlan, mealID: mealID, with: preview)
        return currentPlan
    }

    func updateGroceryState(planID: String, state: GroceryState) async throws -> MealPlan {
        currentPlan = DemoPlanningEngine.updatingGroceryState(plan: currentPlan, state: state)
        return currentPlan
    }
}

actor APIPlanRepository: PlanRepository {
    private let client: APIClient

    init(client: APIClient) { self.client = client }

    func findStores(postalCode: String) async throws -> [Store] {
        let encoded = postalCode.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? postalCode
        let response: StoresEnvelope = try await client.send("/v1/stores?postalCode=\(encoded)")
        return response.stores
    }

    private struct JobEnvelope: Decodable { let job: GenerationJob }
    private struct StoresEnvelope: Decodable { let stores: [Store] }
    private struct PlanEnvelope: Decodable { let plan: MealPlan }
    private struct UpdatesEnvelope: Decodable { let updates: [GenerationUpdate] }
    private struct SwapEnvelope: Decodable { let previews: [SwapPreview] }
    private struct SwapRequest: Encodable {
        let previewID: String
        enum CodingKeys: String, CodingKey { case previewID = "previewId" }
    }
    func createPlan(request: PlannerRequest, idempotencyKey: String) async throws -> GenerationJob {
        let response: JobEnvelope = try await client.send(
            "/v1/plan-requests", method: "POST", body: request, idempotencyKey: idempotencyKey
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

    func updateGroceryState(planID: String, state: GroceryState) async throws -> MealPlan {
        let response: PlanEnvelope = try await client.send("/v1/plans/\(planID)/grocery-state", method: "PATCH", body: state)
        return response.plan
    }
}
