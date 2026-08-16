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
            let model = AppModel(persistence: persistence)
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
        XCTAssertEqual(received.last?.completedPlanID, "demo")
        XCTAssertTrue(received.allSatisfy { $0.jobID == job.id })
    }

    func testSwapPreviewKeepsPlanInsideBudget() async throws {
        let repository = DemoPlanRepository()
        _ = try await repository.createPlan(request: PlannerRequest(), idempotencyKey: "swap")
        let previews = try await repository.swapPreviews(planID: "demo", mealID: "pesto-rigatoni")
        let preview = try XCTUnwrap(previews.first)
        XCTAssertLessThanOrEqual(preview.resultingTotalCents, DemoData.plan.budgetCents)
        XCTAssertLessThan(preview.deltaCents, 0)
    }
}
