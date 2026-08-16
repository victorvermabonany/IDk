import Foundation
import Observation
import UIKit

enum RootFlow: Equatable {
    case welcome
    case planner
    case generation
    case main
}

enum AppTab: Hashable {
    case week
    case groceries
    case plan
    case profile
}

@MainActor
@Observable
final class AppModel {
    var rootFlow: RootFlow = .welcome
    var selectedTab: AppTab = .week
    var plannerDraft = PlannerRequest()
    var plan: MealPlan?
    var groceryState = GroceryState()
    var generationStage: GenerationStage = .planning
    var generationProgress = 0.05
    var generationError: String?
    var pendingGenerationJob: GenerationJob?
    var swapMeal: Meal?
    var swapPreviews: [SwapPreview] = []
    var isLoadingSwaps = false
    var isApplyingSwap = false

    let persistence: PersistenceController
    private let repository: any PlanRepository
    private var generationTask: Task<Void, Never>?

    init(
        repository: any PlanRepository = DemoPlanRepository(),
        persistence: PersistenceController = PersistenceController()
    ) {
        self.repository = repository
        self.persistence = persistence
        restoreLocalState()
    }

    func showPlanner() {
        rootFlow = .planner
        Haptics.selection()
    }

    func updateDraft(_ draft: PlannerRequest) {
        plannerDraft = draft
        try? persistence.save(draft, key: PersistenceKey.plannerDraft)
    }

    func beginGeneration() {
        generationTask?.cancel()
        generationTask = nil
        generationError = nil
        generationStage = .planning
        generationProgress = 0.05
        rootFlow = .generation
        let request = plannerDraft

        generationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let job = try await repository.createPlan(request: request, idempotencyKey: UUID().uuidString)
                pendingGenerationJob = job
                try? persistence.save(job, key: PersistenceKey.generationJob)
                try await observeGeneration(job)
            } catch {
                generationError = error.localizedDescription
                Haptics.warning()
            }
        }
    }

    func resumeGenerationIfNeeded() {
        guard rootFlow == .generation, generationTask == nil, let job = pendingGenerationJob else { return }
        generationTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await observeGeneration(job)
            } catch {
                generationError = error.localizedDescription
                Haptics.warning()
            }
        }
    }

    func retryGeneration() {
        generationTask?.cancel()
        generationTask = nil
        generationError = nil
        if pendingGenerationJob != nil { resumeGenerationIfNeeded() }
        else { beginGeneration() }
    }

    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        pendingGenerationJob = nil
        try? persistence.remove(key: PersistenceKey.generationJob)
        rootFlow = .planner
    }

    func selectGroceries() {
        selectedTab = .groceries
        Haptics.selection()
    }

    func toggleChecked(_ itemID: String) {
        if groceryState.checkedItemIDs.contains(itemID) {
            groceryState.checkedItemIDs.remove(itemID)
        } else {
            groceryState.checkedItemIDs.insert(itemID)
        }
        persistGroceryState()
        Haptics.lightImpact()
    }

    func toggleOwned(_ itemID: String) {
        if groceryState.ownedItemIDs.contains(itemID) {
            groceryState.ownedItemIDs.remove(itemID)
        } else {
            groceryState.ownedItemIDs.insert(itemID)
        }
        persistGroceryState()
        Haptics.selection()
    }

    func openSwap(for meal: Meal) {
        swapMeal = meal
        swapPreviews = []
        isLoadingSwaps = true
        Task {
            do {
                swapPreviews = try await repository.swapPreviews(planID: plan?.id ?? "", mealID: meal.id)
            } catch {
                swapPreviews = []
            }
            isLoadingSwaps = false
        }
    }

    func applySwap(_ preview: SwapPreview) {
        guard let plan, let swapMeal else { return }
        isApplyingSwap = true
        Task {
            do {
                let updated = try await repository.applySwap(
                    planID: plan.id,
                    mealID: swapMeal.id,
                    previewID: preview.id
                )
                self.plan = updated
                try? persistence.save(updated, key: PersistenceKey.cachedPlan)
                self.swapMeal = nil
                Haptics.success()
                UIAccessibility.post(notification: .announcement, argument: "Meal swapped. New basket total \(updated.estimatedTotalCents.currency).")
            } catch {
                Haptics.warning()
            }
            isApplyingSwap = false
        }
    }

    func dismissSwap() { swapMeal = nil }

    func planAnotherWeek() {
        selectedTab = .week
        rootFlow = .planner
    }

    var groceryTotalCents: Int {
        guard let plan else { return 0 }
        return plan.basket.reduce(0) { total, item in
            let owned = groceryState.ownedItemIDs.contains(item.id)
            return total + (owned ? 0 : item.totalPriceCents)
        }
    }

    private func finishGeneration(planID: String) async throws {
        let generatedPlan = try await repository.plan(id: planID)
        plan = generatedPlan
        try? persistence.save(generatedPlan, key: PersistenceKey.cachedPlan)
        try? persistence.remove(key: PersistenceKey.generationJob)
        pendingGenerationJob = nil
        generationTask = nil
        groceryState = GroceryState(
            checkedItemIDs: [],
            ownedItemIDs: Set(generatedPlan.basket.filter(\.pantryStatus).map(\.id))
        )
        persistGroceryState()
        selectedTab = .week
        rootFlow = .main
        Haptics.success()
        UIAccessibility.post(notification: .screenChanged, argument: "Your week is ready")
    }

    private func restoreLocalState() {
        plannerDraft = (try? persistence.load(PlannerRequest.self, key: PersistenceKey.plannerDraft)) ?? PlannerRequest()
        let savedGroceryState = try? persistence.load(GroceryState.self, key: PersistenceKey.groceryState)
        groceryState = savedGroceryState ?? GroceryState()
        if let cached = try? persistence.load(MealPlan.self, key: PersistenceKey.cachedPlan) {
            plan = cached
            if savedGroceryState == nil {
                groceryState.ownedItemIDs = Set(cached.basket.filter(\.pantryStatus).map(\.id))
            }
            rootFlow = .main
        }
        if let job = try? persistence.load(GenerationJob.self, key: PersistenceKey.generationJob) {
            pendingGenerationJob = job
            rootFlow = .generation
        }
    }

    private func persistGroceryState() {
        try? persistence.save(groceryState, key: PersistenceKey.groceryState)
    }

    private func observeGeneration(_ job: GenerationJob) async throws {
        let updates = await repository.generationUpdates(jobID: job.id)
        for try await update in updates {
            guard !Task.isCancelled else { return }
            generationStage = update.stage
            generationProgress = update.progress
            UIAccessibility.post(notification: .announcement, argument: update.stage.rawValue)
            if let planID = update.completedPlanID {
                try await finishGeneration(planID: planID)
                return
            }
        }
    }
}
