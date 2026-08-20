import Foundation
import Observation
import UIKit

enum RootFlow: Equatable {
    case welcome
    case planner
    case generation
    case main

    static func restored(
        hasCompletedWelcome: Bool,
        hasCachedPlan: Bool,
        hasPendingGeneration: Bool
    ) -> RootFlow {
        if hasPendingGeneration { return .generation }
        if hasCachedPlan { return .main }
        return hasCompletedWelcome ? .main : .welcome
    }
}

enum AppTab: Hashable {
    case home
    case week
    case groceries
    case pantry
}

enum StoreSearchState: Equatable {
    case idle
    case loading
    case loaded
    case unsupported
    case failed
}

enum PlannerEntryPoint: Equatable {
    case store
    case food
}

@MainActor
@Observable
final class AppModel {
    var rootFlow: RootFlow = .welcome
    var selectedTab: AppTab = .home
    var plannerDraft = PlannerRequest()
    var plan: MealPlan?
    var groceryState = GroceryState()
    var generationStage: GenerationStage = .planning
    var generationMetadata: GenerationMetadata?
    var generationFailure: GenerationFailure?
    var plannerEntryPoint: PlannerEntryPoint = .store
    var pendingGenerationJob: GenerationJob?
    var swapMeal: Meal?
    var swapPreviews: [SwapPreview] = []
    var isLoadingSwaps = false
    var isApplyingSwap = false
    var applyingSwapPreviewID: String?
    var swapErrorMessage: String?
    var weekNavigationPath: [String] = []
    var paywallTrigger: PremiumFeature?
    var settingsPresented = false
    var assistantPresented = false
    var completedPlanCount = 0
    var completedSwapCount = 0
    var entitlementCache = EntitlementCache()
    var availableStores: [Store] = []
    var storeSearchState: StoreSearchState = .idle
    var storeErrorMessage: String?

    let persistence: PersistenceController
    let subscriptions: SubscriptionService
    private let analytics: any AnalyticsClient
    private let repository: any PlanRepository
    private var generationTask: Task<Void, Never>?
#if DEBUG
    private var generationObservationPausedForUITests = false
#endif

    init(
        repository: any PlanRepository,
        persistence: PersistenceController,
        subscriptions: SubscriptionService,
        analytics: any AnalyticsClient = NoOpAnalyticsClient()
    ) {
        self.repository = repository
        self.persistence = persistence
        self.subscriptions = subscriptions
        self.analytics = analytics
        restoreLocalState()
#if DEBUG
        applyDebugLaunchState()
#endif
    }

    func prepareForUse() async {
        await analytics.track(.appOpened)
        guard FeatureFlags.subscriptionsEnabled else { return }
        await subscriptions.prepare()
        entitlementCache = EntitlementCache(
            productIDs: subscriptions.verifiedProductIDs,
            verifiedAt: .now
        )
        try? persistence.save(entitlementCache, key: PersistenceKey.entitlementCache)
    }

    func showPlanner() {
        try? persistence.save(true, key: PersistenceKey.hasCompletedWelcome)
        plannerEntryPoint = .store
        rootFlow = .planner
        Task { await analytics.track(.plannerStarted) }
        Haptics.selection()
    }

    func completeWelcome() {
        try? persistence.save(true, key: PersistenceKey.hasCompletedWelcome)
        selectedTab = .home
        rootFlow = .main
        Haptics.selection()
    }

    func findStores(postalCode: String) async {
        guard postalCode.count == 5, postalCode.allSatisfy(\.isNumber) else {
            availableStores = []
            storeSearchState = .idle
            return
        }
        storeSearchState = .loading
        storeErrorMessage = nil
        do {
            let stores = try await repository.findStores(postalCode: postalCode)
            availableStores = stores
            storeSearchState = stores.isEmpty ? .unsupported : .loaded
            if !stores.contains(where: { $0.id == plannerDraft.storeID }), let first = stores.first {
                plannerDraft.store = PlannerStoreConstraint(id: first.id, locationID: first.providerStoreID, postalCode: postalCode)
            }
        } catch {
            availableStores = []
            storeSearchState = .failed
            storeErrorMessage = userFacingMessage(for: error)
        }
    }

    func updateDraft(_ draft: PlannerRequest) {
        var normalized = draft
        if let selectedStore = availableStores.first(where: { $0.id == draft.storeID }) {
            normalized.store = PlannerStoreConstraint(id: selectedStore.id, locationID: selectedStore.providerStoreID, postalCode: draft.zipCode)
        }
        plannerDraft = normalized
        try? persistence.save(normalized, key: PersistenceKey.plannerDraft)
    }

    func beginGeneration() {
        guard generationTask == nil else { return }
        generationTask?.cancel()
        generationTask = nil
        generationFailure = nil
        generationStage = .planning
        generationMetadata = nil
        try? persistence.remove(key: PersistenceKey.generationUpdate)
        rootFlow = .generation
        Task { await analytics.track(.generationStarted) }
        let request = plannerDraft

        generationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let idempotencyKey = (try? persistence.load(String.self, key: PersistenceKey.generationSubmissionKey)) ?? UUID().uuidString
                try? persistence.save(idempotencyKey, key: PersistenceKey.generationSubmissionKey)
                let job = try await repository.createPlan(request: request, idempotencyKey: idempotencyKey)
                pendingGenerationJob = job
                try? persistence.save(job, key: PersistenceKey.generationJob)
                try? persistence.save(
                    GenerationUpdate(jobID: job.id, stage: .planning, completedPlanID: nil),
                    key: PersistenceKey.generationUpdate
                )
                try? persistence.remove(key: PersistenceKey.generationSubmissionKey)
                try await observeGeneration(job)
            } catch {
                generationTask = nil
                clearTerminalGenerationJob(for: error)
                generationFailure = GenerationFailure.userFacing(for: error, request: request)
                await analytics.track(.generationFailed)
                Haptics.warning()
            }
        }
    }

    func resumeGenerationIfNeeded() {
#if DEBUG
        guard !generationObservationPausedForUITests else { return }
#endif
        guard rootFlow == .generation, generationTask == nil, let job = pendingGenerationJob else { return }
        generationTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await observeGeneration(job)
            } catch {
                generationTask = nil
                clearTerminalGenerationJob(for: error)
                generationFailure = GenerationFailure.userFacing(for: error, request: plannerDraft)
                Haptics.warning()
            }
        }
    }

    func retryGeneration() {
        generationTask?.cancel()
        generationTask = nil
        generationFailure = nil
        if pendingGenerationJob != nil { resumeGenerationIfNeeded() }
        else { beginGeneration() }
    }

    func cancelGeneration() {
        returnToPlanner(at: .store)
    }

    func reviewGenerationBudget() {
        returnToPlanner(at: .store)
    }

    func reviewGenerationPreferences() {
        returnToPlanner(at: .food)
    }

    private func returnToPlanner(at entryPoint: PlannerEntryPoint) {
        generationTask?.cancel()
        generationTask = nil
        pendingGenerationJob = nil
        try? persistence.remove(key: PersistenceKey.generationJob)
        try? persistence.remove(key: PersistenceKey.generationUpdate)
        try? persistence.remove(key: PersistenceKey.generationSubmissionKey)
        plannerEntryPoint = entryPoint
        rootFlow = .planner
    }

    func selectGroceries() {
        selectedTab = .groceries
        Haptics.selection()
    }

    func selectWeek() {
        selectedTab = .week
        Haptics.selection()
    }

    func selectPantry() {
        selectedTab = .pantry
        Haptics.selection()
    }

    func presentAssistant() {
        assistantPresented = true
        Haptics.selection()
    }

    func toggleChecked(_ itemID: String) {
        let previousState = groceryState
        if groceryState.checkedItemIDs.contains(itemID) {
            groceryState.checkedItemIDs.remove(itemID)
        } else {
            groceryState.checkedItemIDs.insert(itemID)
        }
        persistGroceryState()
        Haptics.lightImpact()
        Task { await analytics.track(.groceryItemChecked) }
        synchronizeGroceryState(previousState: previousState, failureAnnouncement: "The checkoff could not be saved")
    }

    func toggleOwned(_ itemID: String) {
        let previousState = groceryState
        if groceryState.ownedItemIDs.contains(itemID) {
            groceryState.ownedItemIDs.remove(itemID)
        } else {
            groceryState.ownedItemIDs.insert(itemID)
        }
        persistGroceryState()
        Haptics.selection()
        Task { await analytics.track(.pantryItemChanged) }
        synchronizeGroceryState(previousState: previousState, failureAnnouncement: "The pantry change could not be saved", announceBasket: true)
    }

    func openSwap(for meal: Meal) {
        guard !FeatureFlags.subscriptionsEnabled || subscriptions.isPro || completedSwapCount == 0 else {
            presentPaywall(for: .additionalSwap)
            return
        }
        swapMeal = meal
        Task { await analytics.track(.swapOpened) }
        swapPreviews = []
        swapErrorMessage = nil
        isLoadingSwaps = true
        Task {
            do {
                swapPreviews = try await repository.swapPreviews(planID: plan?.id ?? "", mealID: meal.id)
            } catch {
                swapPreviews = []
                swapErrorMessage = "Alternatives could not be loaded. Check your connection and try again."
                Haptics.warning()
            }
            isLoadingSwaps = false
        }
    }

    func applySwap(_ preview: SwapPreview) {
        guard let plan, let swapMeal else { return }
        isApplyingSwap = true
        applyingSwapPreviewID = preview.id
        swapErrorMessage = nil
        Task {
            do {
                let updated = try await repository.applySwap(
                    planID: plan.id,
                    mealID: swapMeal.id,
                    previewID: preview.id
                )
                self.plan = updated
                try? persistence.save(updated, key: PersistenceKey.cachedPlan)
                completedSwapCount += 1
                try? persistence.save(completedSwapCount, key: PersistenceKey.completedSwapCount)
                self.swapMeal = nil
                await analytics.track(.swapCompleted)
                Haptics.success()
                UIAccessibility.post(notification: .announcement, argument: "Meal swapped. Estimated basket updated to \(updated.estimatedTotalCents.currency).")
            } catch {
                swapErrorMessage = "We couldn’t update the estimated basket. Your original meal is unchanged. Try again."
                Haptics.warning()
            }
            isApplyingSwap = false
            applyingSwapPreviewID = nil
        }
    }

    func dismissSwap() { swapMeal = nil }

    func planAnotherWeek() {
        guard !FeatureFlags.subscriptionsEnabled || subscriptions.isPro || completedPlanCount == 0 else {
            presentPaywall(for: .anotherWeek)
            return
        }
        startPlannerForAnotherWeek()
    }

    func startPlannerForAnotherWeek() {
        paywallTrigger = nil
        weekNavigationPath.removeAll()
        selectedTab = .home
        plannerEntryPoint = .store
        rootFlow = .planner
    }

    func presentSettings() {
        settingsPresented = true
        Haptics.selection()
    }

    func presentPaywall(for feature: PremiumFeature) {
        paywallTrigger = feature
        Haptics.selection()
        Task { await analytics.track(.paywallViewed) }
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
        try? persistence.remove(key: PersistenceKey.generationUpdate)
        try? persistence.remove(key: PersistenceKey.generationSubmissionKey)
        pendingGenerationJob = nil
        generationTask = nil
        groceryState = GroceryState(
            checkedItemIDs: [],
            ownedItemIDs: Set(generatedPlan.basket.filter(\.pantryStatus).map(\.id))
        )
        persistGroceryState()
        selectedTab = .week
        rootFlow = .main
        completedPlanCount += 1
        try? persistence.save(completedPlanCount, key: PersistenceKey.completedPlanCount)
        Haptics.success()
        await analytics.track(.generationCompleted)
        UIAccessibility.post(notification: .screenChanged, argument: "Your week is ready")
    }

    private func restoreLocalState() {
        plannerDraft = (try? persistence.load(PlannerRequest.self, key: PersistenceKey.plannerDraft)) ?? PlannerRequest()
        completedPlanCount = (try? persistence.load(Int.self, key: PersistenceKey.completedPlanCount)) ?? 0
        completedSwapCount = (try? persistence.load(Int.self, key: PersistenceKey.completedSwapCount)) ?? 0
        entitlementCache = (try? persistence.load(EntitlementCache.self, key: PersistenceKey.entitlementCache)) ?? EntitlementCache()
        let completedWelcome = (try? persistence.load(Bool.self, key: PersistenceKey.hasCompletedWelcome)) ?? false
        let savedGroceryState = try? persistence.load(GroceryState.self, key: PersistenceKey.groceryState)
        groceryState = savedGroceryState ?? GroceryState()
        if let cached = try? persistence.load(MealPlan.self, key: PersistenceKey.cachedPlan) {
            plan = cached
            if completedPlanCount == 0 {
                completedPlanCount = 1
                try? persistence.save(completedPlanCount, key: PersistenceKey.completedPlanCount)
            }
            if savedGroceryState == nil {
                groceryState.ownedItemIDs = Set(cached.basket.filter(\.pantryStatus).map(\.id))
            }
        }
        if let job = try? persistence.load(GenerationJob.self, key: PersistenceKey.generationJob) {
            pendingGenerationJob = job
            if let update = try? persistence.load(GenerationUpdate.self, key: PersistenceKey.generationUpdate),
               update.jobID == job.id {
                generationStage = update.stage
                generationMetadata = update.metadata
            }
        }
        rootFlow = .restored(
            hasCompletedWelcome: completedWelcome,
            hasCachedPlan: plan != nil,
            hasPendingGeneration: pendingGenerationJob != nil
        )
    }

    private func persistGroceryState() {
        try? persistence.save(groceryState, key: PersistenceKey.groceryState)
    }

#if DEBUG
    private func applyDebugLaunchState() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-cove-ui-test-pause-generation") { generationObservationPausedForUITests = true }
        if arguments.contains("-cove-ui-test-week") { selectedTab = .week }
        if arguments.contains("-cove-ui-test-groceries") { selectedTab = .groceries }
        if arguments.contains("-cove-ui-test-pantry") { selectedTab = .pantry }
        if arguments.contains("-cove-ui-test-recipe"), let meal = plan?.meals.first {
            selectedTab = .week
            weekNavigationPath = [meal.id]
        }
        if arguments.contains("-cove-ui-test-assistant") { assistantPresented = true }
    }
#endif

    private func synchronizeGroceryState(
        previousState: GroceryState,
        failureAnnouncement: String,
        announceBasket: Bool = false
    ) {
        guard let plan else { return }
        let stateToSync = groceryState
        Task {
            do {
                let updatedPlan = try await repository.updateGroceryState(planID: plan.id, state: stateToSync)
                self.plan = updatedPlan
                try? persistence.save(updatedPlan, key: PersistenceKey.cachedPlan)
                if announceBasket {
                    UIAccessibility.post(notification: .announcement, argument: "Estimated basket updated to \(groceryTotalCents.currency)")
                }
            } catch {
                guard groceryState == stateToSync else { return }
                groceryState = previousState
                persistGroceryState()
                Haptics.warning()
                UIAccessibility.post(notification: .announcement, argument: failureAnnouncement)
            }
        }
    }

    private func observeGeneration(_ job: GenerationJob) async throws {
        let updates = await repository.generationUpdates(jobID: job.id)
        for try await update in updates {
            guard !Task.isCancelled else { return }
            let currentIndex = GenerationStage.allCases.firstIndex(of: generationStage) ?? 0
            let updateIndex = GenerationStage.allCases.firstIndex(of: update.stage) ?? 0
            guard updateIndex >= currentIndex else { continue }
            generationStage = update.stage
            generationMetadata = update.metadata
            try? persistence.save(update, key: PersistenceKey.generationUpdate)
            UIAccessibility.post(notification: .announcement, argument: update.stage.rawValue)
            if let planID = update.completedPlanID {
                try await finishGeneration(planID: planID)
                return
            }
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        if let planningError = error as? DemoPlanningError {
            return planningError.localizedDescription
        }
        if let apiError = error as? APIError {
            switch apiError {
            case .configuration(let message):
                return message
            case .invalidResponse:
                return "Cove received an incomplete response. Your answers are saved—please try again."
            case .server(let status, _, _):
                if status == 409 { return "These choices could not produce a safe week within the budget. Review your answers and try again." }
                if status == 422 { return "One or more choices need attention. Review your planner answers and try again." }
                if status == 429 { return "Cove is receiving many requests. Your answers are saved—wait a moment and try again." }
                if status == 404 { return "This saved plan has expired. Your preferences are still saved, so you can build a fresh week." }
                if status >= 500 { return "Cove is temporarily unavailable. Your answers are saved, so you can retry shortly." }
            }
        }
        if error is URLError {
            return "You appear to be offline. Your answers are saved and generation can resume when you reconnect."
        }
        return "Your week could not be completed. Your answers are saved—please try again."
    }

    private func clearTerminalGenerationJob(for error: Error) {
        guard let apiError = error as? APIError,
              case let .server(status, code, _) = apiError else { return }
        let terminalCodes = ["BUDGET_TOO_LOW", "CONSTRAINT_CONFLICT", "UNPRICED_BASKET", "PROVIDER_UNAVAILABLE", "MODEL_FAILURE", "GENERATION_FAILED"]
        guard status == 404 || terminalCodes.contains(code?.uppercased() ?? "") else { return }
        pendingGenerationJob = nil
        try? persistence.remove(key: PersistenceKey.generationJob)
        try? persistence.remove(key: PersistenceKey.generationUpdate)
        try? persistence.remove(key: PersistenceKey.generationSubmissionKey)
    }
}
