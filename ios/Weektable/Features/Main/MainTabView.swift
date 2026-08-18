import SwiftUI

struct MainTabView: View {
    @Bindable var appModel: AppModel

    private var tabSelection: Binding<AppTab> {
        Binding {
            appModel.selectedTab
        } set: { next in
            if next == .week, appModel.selectedTab == .week {
                appModel.weekNavigationPath.removeAll()
            }
            appModel.selectedTab = next
        }
    }

    var body: some View {
        TabView(selection: tabSelection) {
            NavigationStack(path: $appModel.weekNavigationPath) {
                WeekHomeView(appModel: appModel)
            }
            .tabItem { Label("Week", systemImage: "calendar") }
            .tag(AppTab.week)

            NavigationStack {
                GroceryListView(appModel: appModel)
            }
            .tabItem { Label("Groceries", systemImage: "cart") }
            .tag(AppTab.groceries)
        }
        .toolbarBackground(WeektableTheme.raised, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .sheet(item: $appModel.swapMeal) { meal in
            MealSwapSheet(appModel: appModel, meal: meal)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sheet(item: $appModel.paywallTrigger) { feature in
            if FeatureFlags.subscriptionsEnabled {
                PaywallView(appModel: appModel, feature: feature)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(30)
            }
        }
        .sheet(isPresented: $appModel.settingsPresented) {
            NavigationStack {
                SettingsView(appModel: appModel)
            }
            .presentationDragIndicator(.visible)
        }
    }
}
