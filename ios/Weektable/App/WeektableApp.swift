import Foundation
import SwiftUI
import SwiftData

@main
struct WeektableApp: App {
    @State private var appModel: AppModel

    init() {
        let persistence = PersistenceController()
#if DEBUG
        UITestLaunchState.prepare(persistence: persistence)
#endif
        _appModel = State(initialValue: AppModel(
            repository: AppConfiguration.makePlanRepository(),
            persistence: persistence,
            subscriptions: SubscriptionService()
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootView(appModel: appModel)
                .tint(WeektableTheme.brand)
                .preferredColorScheme(.light)
        }
        .modelContainer(appModel.persistence.container)
    }
}

#if DEBUG
private enum UITestLaunchState {
    private static let resetArgument = "-cove-ui-test-reset"
    private static let activePlanArgument = "-cove-ui-test-active-plan"
    private static let generationArgument = "-cove-ui-test-generation"

    @MainActor
    static func prepare(persistence: PersistenceController) {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains(resetArgument) else { return }

        try? persistence.removeAll()
        if arguments.contains(generationArgument) {
            let job = GenerationJob(id: "ui-generation-job", planID: DemoData.plan.id)
            let update = GenerationUpdate(
                jobID: job.id,
                stage: .packages,
                completedPlanID: nil,
                metadata: GenerationMetadata(ingredientCount: 18, productsMatched: 16, reusedIngredientCount: 4)
            )
            try? persistence.save(true, key: PersistenceKey.hasCompletedWelcome)
            try? persistence.save(job, key: PersistenceKey.generationJob)
            try? persistence.save(update, key: PersistenceKey.generationUpdate)
            return
        }
        guard arguments.contains(activePlanArgument) else { return }

        try? persistence.save(true, key: PersistenceKey.hasCompletedWelcome)
        try? persistence.save(DemoData.plan, key: PersistenceKey.cachedPlan)
        try? persistence.save(1, key: PersistenceKey.completedPlanCount)
    }
}
#endif

struct RootView: View {
    @Bindable var appModel: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch appModel.rootFlow {
            case .welcome:
                WelcomeView(appModel: appModel)
            case .planner:
                PlannerFlowView(appModel: appModel)
            case .generation:
                GenerationView(appModel: appModel)
            case .main:
                MainTabView(appModel: appModel)
            }
        }
        .background(WeektableTheme.canvas.ignoresSafeArea())
        .task {
            await appModel.prepareForUse()
            appModel.resumeGenerationIfNeeded()
        }
        .onChange(of: scenePhase) { _, nextPhase in
            if nextPhase == .active { appModel.resumeGenerationIfNeeded() }
        }
    }
}
