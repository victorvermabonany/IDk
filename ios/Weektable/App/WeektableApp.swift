import SwiftUI
import SwiftData

@main
struct WeektableApp: App {
    @State private var appModel: AppModel

    init() {
        let persistence = PersistenceController()
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
                .preferredColorScheme(nil)
        }
        .modelContainer(appModel.persistence.container)
    }
}

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
