import SwiftUI

#if DEBUG

@MainActor
enum PreviewFactory {
    static func model(withPlan: Bool = true) -> AppModel {
        let persistence = PersistenceController(inMemory: true)
        let model = AppModel(repository: AppConfiguration.makePreviewRepository(), persistence: persistence, subscriptions: SubscriptionService())
        model.plan = withPlan ? DemoData.plan : nil
        if withPlan {
            model.groceryState.ownedItemIDs = Set(DemoData.plan.basket.filter(\.pantryStatus).map(\.id))
        }
        model.rootFlow = withPlan ? .main : .welcome
        return model
    }
}

#Preview("Welcome · iPhone") {
    WelcomeView(appModel: PreviewFactory.model(withPlan: false))
}

#Preview("Week · light") {
    NavigationStack { WeekHomeView(appModel: PreviewFactory.model()) }
}

#Preview("Week · dark") {
    NavigationStack { WeekHomeView(appModel: PreviewFactory.model()) }
        .preferredColorScheme(.dark)
}

#Preview("Groceries · accessibility type") {
    NavigationStack { GroceryListView(appModel: PreviewFactory.model()) }
        .environment(\.dynamicTypeSize, .accessibility2)
}
#endif
