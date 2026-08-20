import XCTest
@testable import Weektable

final class WeektableDomainTests: XCTestCase {
    func testFirstRunRoutingStates() {
        XCTAssertEqual(
            RootFlow.restored(hasCompletedWelcome: false, hasCachedPlan: false, hasPendingGeneration: false),
            .welcome
        )
        XCTAssertEqual(
            RootFlow.restored(hasCompletedWelcome: true, hasCachedPlan: false, hasPendingGeneration: false),
            .main
        )
        XCTAssertEqual(
            RootFlow.restored(hasCompletedWelcome: false, hasCachedPlan: true, hasPendingGeneration: false),
            .main
        )
        XCTAssertEqual(
            RootFlow.restored(hasCompletedWelcome: true, hasCachedPlan: true, hasPendingGeneration: true),
            .generation
        )
    }

    func testWelcomeCompletionPersistsAcrossAppModelInstances() async {
        await MainActor.run {
            let persistence = PersistenceController(inMemory: true)
            let firstLaunch = AppModel(repository: DemoPlanRepository(), persistence: persistence, subscriptions: SubscriptionService())
            XCTAssertEqual(firstLaunch.rootFlow, .welcome)

            firstLaunch.completeWelcome()
            XCTAssertEqual(firstLaunch.rootFlow, .main)

            let relaunch = AppModel(repository: DemoPlanRepository(), persistence: persistence, subscriptions: SubscriptionService())
            XCTAssertEqual(relaunch.rootFlow, .main)
        }
    }

    func testCachedPlanSkipsWelcome() async throws {
        try await MainActor.run {
            let persistence = PersistenceController(inMemory: true)
            try persistence.save(DemoData.plan, key: PersistenceKey.cachedPlan)

            let relaunch = AppModel(repository: DemoPlanRepository(), persistence: persistence, subscriptions: SubscriptionService())
            XCTAssertEqual(relaunch.rootFlow, .main)
            XCTAssertEqual(relaunch.plan?.id, DemoData.plan.id)
        }
    }

    func testDemoBasketMatchesReferenceTotal() {
        XCTAssertEqual(DemoData.plan.estimatedTotalCents, 8_537)
        XCTAssertEqual(DemoData.plan.remainingCents, 1_463)
        XCTAssertEqual(DemoData.plan.priceCoverage, 1)
    }

    func testPantryItemsAreExcludedFromNativeGroceryTotal() async {
        await MainActor.run {
            let persistence = PersistenceController(inMemory: true)
            let model = AppModel(repository: DemoPlanRepository(), persistence: persistence, subscriptions: SubscriptionService())
            model.plan = DemoData.plan
            model.groceryState.ownedItemIDs = Set(DemoData.plan.basket.filter(\.pantryStatus).map(\.id))
            XCTAssertEqual(model.groceryTotalCents, 8_537)

            model.toggleOwned("basket-rigatoni")
            XCTAssertEqual(model.groceryTotalCents, 8_358)
        }
    }

    func testBudgetFailureUsesPlannerContextWithoutExposingServerMessage() {
        var request = PlannerRequest()
        request.budgetCents = 2_500
        request.householdSize = 4
        request.dinnerCount = 5

        let failure = GenerationFailure.userFacing(
            for: APIError.server(status: 422, code: "BUDGET_TOO_LOW", message: "internal optimizer detail"),
            request: request
        )

        XCTAssertEqual(failure.kind, .budget)
        XCTAssertEqual(failure.title, "We couldn’t make this week fit your current budget.")
        XCTAssertTrue(failure.message.contains("5 dinners for 4 people"))
        XCTAssertTrue(failure.message.contains(request.budgetCents.currency))
        XCTAssertFalse(failure.message.contains("internal optimizer detail"))
    }

    func testConstraintAndTemporaryFailuresUseSafeSpecificCopy() {
        var request = PlannerRequest()
        request.dinnerCount = 6
        request.maxCookingMinutes = 20
        request.allergies = ["milk"]

        let conflict = GenerationFailure.userFacing(
            for: APIError.server(status: 422, code: "CONSTRAINT_CONFLICT", message: "raw conflict"),
            request: request
        )
        XCTAssertEqual(conflict.kind, .constraints)
        XCTAssertTrue(conflict.message.contains("20-minute cooking limit"))
        XCTAssertFalse(conflict.message.contains("raw conflict"))

        let temporary = GenerationFailure.userFacing(
            for: APIError.server(status: 502, code: "MODEL_FAILURE", message: "provider stack trace"),
            request: request
        )
        XCTAssertEqual(temporary.kind, .temporary)
        XCTAssertEqual(temporary.message, "Your answers are still saved. Please try again in a moment.")
        XCTAssertFalse(temporary.message.contains("provider stack trace"))

        let backend = GenerationFailure.userFacing(
            for: APIError.server(status: 502, code: "GENERATION_FAILED", message: "database detail"),
            request: request
        )
        XCTAssertEqual(backend.kind, .temporary)
        XCTAssertFalse(backend.message.contains("database detail"))
    }

    func testWeekdayLabelsReplaceGenericDayValuesWithoutReorderingMeals() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let wednesday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 19)))

        XCTAssertEqual(WeekdayLabel.label(for: "Monday", index: 0, now: wednesday, calendar: calendar), "TODAY")
        XCTAssertEqual(WeekdayLabel.label(for: "Tuesday", index: 1, now: wednesday, calendar: calendar), "TUE")
        XCTAssertEqual(WeekdayLabel.label(for: "Day 2", index: 1, now: wednesday, calendar: calendar), "THU")
    }

    func testReviewingGenerationFailurePreservesPlannerAnswersAndOpensRequestedStep() async {
        await MainActor.run {
            let persistence = PersistenceController(inMemory: true)
            let model = AppModel(repository: DemoPlanRepository(), persistence: persistence, subscriptions: SubscriptionService())
            var request = PlannerRequest()
            request.budgetCents = 4_500
            request.allergies = ["milk"]
            model.updateDraft(request)

            model.reviewGenerationPreferences()

            XCTAssertEqual(model.rootFlow, .planner)
            XCTAssertEqual(model.plannerEntryPoint, .food)
            XCTAssertEqual(model.plannerDraft, request)
        }
    }

    func testGenerationStagesAreOrderedAndResumableByJobID() async throws {
        let repository = DemoPlanRepository()
        let job = try await repository.createPlan(request: PlannerRequest(), idempotencyKey: "test")
        let updates = await repository.generationUpdates(jobID: job.id)
        var received: [GenerationUpdate] = []
        for try await update in updates { received.append(update) }

        XCTAssertEqual(received.map(\.stage), GenerationStage.allCases)
        XCTAssertEqual(received.last?.completedPlanID, job.planID)
        XCTAssertTrue(received.allSatisfy { $0.jobID == job.id })
        let generatedPlan = try await repository.plan(id: job.planID)
        XCTAssertEqual(received.last?.metadata?.ingredientCount, generatedPlan.basket.count)
    }

    func testLegacyGenerationStageNamesRemainDecodableDuringDeployment() throws {
        let payload = Data(#"{"jobId":"legacy-job","stage":"Checking complete packages","progress":0.6,"completedPlanId":null}"#.utf8)
        let update = try JSONDecoder().decode(GenerationUpdate.self, from: payload)

        XCTAssertEqual(update.stage, .packages)
        XCTAssertNil(update.metadata)
    }

    @MainActor
    func testGenerationRelaunchRestoresLatestActualStageAndMetadata() throws {
        let persistence = PersistenceController(inMemory: true)
        let job = GenerationJob(id: "restored-job", planID: DemoData.plan.id)
        let metadata = GenerationMetadata(ingredientCount: 19, productsMatched: 17, reusedIngredientCount: 5, underBudgetCents: 1_200)
        try persistence.save(true, key: PersistenceKey.hasCompletedWelcome)
        try persistence.save(job, key: PersistenceKey.generationJob)
        try persistence.save(
            GenerationUpdate(jobID: job.id, stage: .budget, completedPlanID: nil, metadata: metadata),
            key: PersistenceKey.generationUpdate
        )

        let relaunched = AppModel(repository: DemoPlanRepository(), persistence: persistence, subscriptions: SubscriptionService())

        XCTAssertEqual(relaunched.rootFlow, .generation)
        XCTAssertEqual(relaunched.pendingGenerationJob?.id, job.id)
        XCTAssertEqual(relaunched.generationStage, .budget)
        XCTAssertEqual(relaunched.generationMetadata, metadata)
    }

    @MainActor
    func testBackgroundResumeReconnectsWithoutReplayingEarlierStagesAndOpensWeek() async throws {
        let persistence = PersistenceController(inMemory: true)
        let job = GenerationJob(id: "resume-job", planID: DemoData.plan.id)
        try persistence.save(true, key: PersistenceKey.hasCompletedWelcome)
        try persistence.save(job, key: PersistenceKey.generationJob)
        try persistence.save(
            GenerationUpdate(jobID: job.id, stage: .packages, completedPlanID: nil),
            key: PersistenceKey.generationUpdate
        )
        let model = AppModel(repository: DemoPlanRepository(), persistence: persistence, subscriptions: SubscriptionService())

        model.resumeGenerationIfNeeded()
        for _ in 0..<40 where model.rootFlow != .main {
            try await Task.sleep(for: .milliseconds(100))
            XCTAssertNotEqual(model.generationStage, .planning)
            XCTAssertNotEqual(model.generationStage, .combining)
        }

        XCTAssertEqual(model.rootFlow, .main)
        XCTAssertEqual(model.selectedTab, .week)
        XCTAssertEqual(model.plan?.id, DemoData.plan.id)
        XCTAssertNil(try persistence.load(GenerationJob.self, key: PersistenceKey.generationJob))
        XCTAssertNil(try persistence.load(GenerationUpdate.self, key: PersistenceKey.generationUpdate))
    }

    func testSwapPreviewKeepsPlanInsideBudget() async throws {
        let repository = DemoPlanRepository()
        _ = try await repository.createPlan(request: PlannerRequest(), idempotencyKey: "swap")
        let previews = try await repository.swapPreviews(planID: "demo", mealID: "pesto-rigatoni")
        let preview = try XCTUnwrap(previews.first)
        XCTAssertLessThanOrEqual(preview.resultingTotalCents, DemoData.plan.budgetCents)
        XCTAssertNotEqual(preview.meal.title, DemoData.meals[0].title)
    }

    func testFreeBetaAllowsAnotherWeekWithoutRemovingCurrentPlan() async {
        await MainActor.run {
            let persistence = PersistenceController(inMemory: true)
            let model = AppModel(repository: DemoPlanRepository(), persistence: persistence, subscriptions: SubscriptionService())
            model.plan = DemoData.plan
            model.rootFlow = .main
            model.completedPlanCount = 1

            model.planAnotherWeek()

            XCTAssertNil(model.paywallTrigger)
            XCTAssertEqual(model.rootFlow, .planner)
            XCTAssertNotNil(model.plan)
        }
    }

    func testDinnerCountAndHouseholdScaleActualIngredients() async throws {
        let repository = DemoPlanRepository()
        var small = PlannerRequest()
        small.budgetCents = 30_000
        small.householdSize = 2
        small.dinnerCount = 3
        let smallJob = try await repository.createPlan(request: small, idempotencyKey: "small")
        let smallPlan = try await repository.plan(id: smallJob.planID)

        var large = small
        large.householdSize = 5
        large.dinnerCount = 7
        let largeJob = try await repository.createPlan(request: large, idempotencyKey: "large")
        let largePlan = try await repository.plan(id: largeJob.planID)

        XCTAssertEqual(smallPlan.meals.count, 3)
        XCTAssertEqual(largePlan.meals.count, 7)
        XCTAssertTrue(largePlan.meals.allSatisfy { $0.servings == 5 })
        let smallQuantity = smallPlan.meals[0].ingredients[0].quantity
        let matching = largePlan.meals.first(where: { $0.title == smallPlan.meals[0].title })
        if let matching {
            XCTAssertGreaterThan(matching.ingredients[0].quantity, smallQuantity)
        }
    }

    func testVegetarianVeganAllergyAndTimeAreHardConstraints() async throws {
        let repository = DemoPlanRepository()
        var request = PlannerRequest()
        request.budgetCents = 20_000
        request.dinnerCount = 5
        request.nutritionStyle = .highProtein
        request.dietaryRestrictions = ["vegan"]
        request.allergies = ["wheat", "peanuts"]
        request.dislikedFoodItems = ["mushrooms"]
        request.maxCookingMinutes = 30
        let job = try await repository.createPlan(request: request, idempotencyKey: "vegan")
        let plan = try await repository.plan(id: job.planID)
        let forbidden = ["chicken", "turkey", "sausage", "yogurt", "parmesan", "cheddar", "egg", "rigatoni", "flour tortilla"]
        let ingredientText = plan.meals.flatMap(\.ingredients).map { $0.name.lowercased() }.joined(separator: " ")
        XCTAssertTrue(forbidden.allSatisfy { !ingredientText.contains($0) })
        XCTAssertTrue(plan.meals.allSatisfy { $0.totalMinutes <= 30 })
        XCTAssertEqual(plan.constraintsUsed, request)
    }

    func testVegetarianHighProteinFixtureWeekLimitsCenterpieceRepetition() async throws {
        let repository = DemoPlanRepository()
        var request = PlannerRequest()
        request.nutritionStyle = .highProtein
        request.dietaryRestrictions = ["vegetarian"]
        request.dinnerCount = 5
        request.budgetCents = 10_000
        let job = try await repository.createPlan(request: request, idempotencyKey: "meal-quality")
        let plan = try await repository.plan(id: job.planID)

        let proteinGroups = [
            "tofu": "tofu", "eggs": "eggs", "lentils": "lentils",
            "black_beans": "black beans", "chickpeas": "chickpeas"
        ]
        let proteins = plan.meals.compactMap { meal in
            meal.ingredients.compactMap { proteinGroups[$0.ingredientID] }.first
        }
        let maximumProteinUse = Dictionary(grouping: proteins, by: { $0 }).values.map(\.count).max() ?? 0
        let quinoaMeals = plan.meals.filter { $0.ingredients.contains(where: { $0.ingredientID == "quinoa" }) }.count
        let formats = plan.meals.map { meal -> String in
            let title = meal.title.lowercased()
            if title.contains("taco") { return "tacos" }
            if title.contains("quesadilla") { return "quesadillas" }
            if title.contains("curry") { return "curry" }
            if title.contains("skillet") { return "skillet" }
            if title.contains("bowl") { return "bowls" }
            return "other"
        }

        XCTAssertLessThanOrEqual(maximumProteinUse, 2)
        XCTAssertLessThanOrEqual(quinoaMeals, 2)
        XCTAssertGreaterThanOrEqual(Set(formats).count, 4)
        XCTAssertLessThanOrEqual(plan.estimatedTotalCents, request.budgetCents)
    }

    func testMealImageMetadataPreventsKnownIDFromForcingWrongPhoto() {
        var fallback = DemoData.meals[0]
        fallback.imageKey = nil
        fallback.imageMatch = "fallback"
        XCTAssertNil(fallback.specificImageAssetName)

        var category = DemoData.meals[0]
        category.imageKey = "meal-chickpea-coconut-curry"
        category.imageMatch = "category"
        XCTAssertEqual(category.specificImageAssetName, "meal-chickpea-coconut-curry")

        var unsupported = DemoData.meals[0]
        unsupported.imageKey = "meal-not-in-cove"
        unsupported.imageMatch = "category"
        XCTAssertNil(unsupported.specificImageAssetName)
    }

    func testLeftoversPantryAndStoreRepriceAuthoritatively() async throws {
        let repository = DemoPlanRepository()
        var request = PlannerRequest()
        request.budgetCents = 30_000
        request.householdSize = 2
        request.dinnerCount = 3
        request.leftovers = LeftoverConstraint(enabled: true, extraServings: 1)
        request.pantryItems.insert("olive oil")
        let firstJob = try await repository.createPlan(request: request, idempotencyKey: "primary-store")
        let first = try await repository.plan(id: firstJob.planID)
        XCTAssertTrue(first.meals.allSatisfy { $0.servings == 3 })
        XCTAssertEqual(first.basket.first(where: { $0.ingredientID == "olive_oil" })?.pantryStatus, true)

        request.store = PlannerStoreConstraint(id: DemoData.valueStore.id, locationID: DemoData.valueStore.providerStoreID, postalCode: "45202")
        let secondJob = try await repository.createPlan(request: request, idempotencyKey: "value-store")
        let second = try await repository.plan(id: secondJob.planID)
        XCTAssertEqual(second.store.id, DemoData.valueStore.id)
        XCTAssertNotEqual(second.estimatedTotalCents, first.estimatedTotalCents)
    }

    func testPantryMutationReturnsRepricedPlan() async throws {
        let repository = DemoPlanRepository()
        var request = PlannerRequest()
        request.budgetCents = 30_000
        request.dinnerCount = 3
        let job = try await repository.createPlan(request: request, idempotencyKey: "pantry")
        let before = try await repository.plan(id: job.planID)
        let item = try XCTUnwrap(before.basket.first(where: { !$0.pantryStatus }))
        let existingOwned = Set(before.basket.filter(\.pantryStatus).map(\.id))
        let after = try await repository.updateGroceryState(
            planID: before.id,
            state: GroceryState(checkedItemIDs: [], ownedItemIDs: existingOwned.union([item.id]))
        )
        XCTAssertEqual(after.estimatedTotalCents, before.estimatedTotalCents - item.totalPriceCents)
        XCTAssertEqual(after.basket.first(where: { $0.id == item.id })?.pantryStatus, true)
    }
}
