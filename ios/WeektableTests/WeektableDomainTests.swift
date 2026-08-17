import XCTest
@testable import Weektable

final class WeektableDomainTests: XCTestCase {
    func testDemoBasketMatchesReferenceTotal() {
        XCTAssertEqual(DemoData.plan.estimatedTotalCents, 8_537)
        XCTAssertEqual(DemoData.plan.remainingCents, 1_463)
        XCTAssertEqual(DemoData.plan.priceCoverage, 1)
    }

    func testPantryItemsAreExcludedFromNativeGroceryTotal() async {
        await MainActor.run {
            let persistence = PersistenceController(inMemory: true)
            let model = AppModel(persistence: persistence, subscriptions: SubscriptionService())
            model.plan = DemoData.plan
            model.groceryState.ownedItemIDs = Set(DemoData.plan.basket.filter(\.pantryStatus).map(\.id))
            XCTAssertEqual(model.groceryTotalCents, 8_537)

            model.toggleOwned("basket-rigatoni")
            XCTAssertEqual(model.groceryTotalCents, 8_358)
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
    }

    func testSwapPreviewKeepsPlanInsideBudget() async throws {
        let repository = DemoPlanRepository()
        _ = try await repository.createPlan(request: PlannerRequest(), idempotencyKey: "swap")
        let previews = try await repository.swapPreviews(planID: "demo", mealID: "pesto-rigatoni")
        let preview = try XCTUnwrap(previews.first)
        XCTAssertLessThanOrEqual(preview.resultingTotalCents, DemoData.plan.budgetCents)
        XCTAssertNotEqual(preview.meal.title, DemoData.meals[0].title)
    }

    func testSecondWeekIsGatedForFreeUserWithoutRemovingCurrentPlan() async {
        await MainActor.run {
            let persistence = PersistenceController(inMemory: true)
            let model = AppModel(persistence: persistence, subscriptions: SubscriptionService())
            model.plan = DemoData.plan
            model.rootFlow = .main
            model.completedPlanCount = 1

            model.planAnotherWeek()

            XCTAssertEqual(model.paywallTrigger, .anotherWeek)
            XCTAssertEqual(model.rootFlow, .main)
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

    func testLeftoversPantryAndStoreRepriceAuthoritatively() async throws {
        let repository = DemoPlanRepository()
        var request = PlannerRequest()
        request.budgetCents = 30_000
        request.householdSize = 2
        request.dinnerCount = 3
        request.leftovers = LeftoverConstraint(enabled: true, extraServings: 1)
        request.pantryItems.insert("brown rice")
        let firstJob = try await repository.createPlan(request: request, idempotencyKey: "primary-store")
        let first = try await repository.plan(id: firstJob.planID)
        XCTAssertTrue(first.meals.allSatisfy { $0.servings == 3 })
        XCTAssertEqual(first.basket.first(where: { $0.ingredientID == "brown_rice" })?.pantryStatus, true)

        request.store = PlannerStoreConstraint(id: DemoData.valueStore.id, locationID: DemoData.valueStore.providerStoreID, postalCode: "45202")
        let secondJob = try await repository.createPlan(request: request, idempotencyKey: "value-store")
        let second = try await repository.plan(id: secondJob.planID)
        XCTAssertEqual(second.store.id, DemoData.valueStore.id)
        XCTAssertLessThanOrEqual(second.estimatedTotalCents, first.estimatedTotalCents)
    }

    func testPantryMutationReturnsRepricedPlan() async throws {
        let repository = DemoPlanRepository()
        var request = PlannerRequest()
        request.budgetCents = 30_000
        request.dinnerCount = 3
        let job = try await repository.createPlan(request: request, idempotencyKey: "pantry")
        let before = try await repository.plan(id: job.planID)
        let item = try XCTUnwrap(before.basket.first(where: { !$0.pantryStatus }))
        let after = try await repository.updateGroceryState(
            planID: before.id,
            state: GroceryState(checkedItemIDs: [], ownedItemIDs: [item.id])
        )
        XCTAssertEqual(after.estimatedTotalCents, before.estimatedTotalCents - item.totalPriceCents)
        XCTAssertEqual(after.basket.first(where: { $0.id == item.id })?.pantryStatus, true)
    }
}
