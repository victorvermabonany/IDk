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
            NavigationStack {
                HomeView(appModel: appModel)
            }
            .tabItem { Label("Home", systemImage: appModel.selectedTab == .home ? "house.fill" : "house") }
            .tag(AppTab.home)

            NavigationStack(path: $appModel.weekNavigationPath) {
                WeekHomeView(appModel: appModel)
            }
            .tabItem { Label("Week", systemImage: appModel.selectedTab == .week ? "calendar.circle.fill" : "calendar") }
            .tag(AppTab.week)

            NavigationStack {
                GroceryListView(appModel: appModel)
            }
            .tabItem { Label("Groceries", systemImage: appModel.selectedTab == .groceries ? "cart.fill" : "cart") }
            .tag(AppTab.groceries)

            NavigationStack {
                PantryView(appModel: appModel)
            }
            .tabItem { Label("Pantry", systemImage: appModel.selectedTab == .pantry ? "cabinet.fill" : "cabinet") }
            .tag(AppTab.pantry)
        }
        .tint(WeektableTheme.terracotta)
        .toolbarBackground(WeektableTheme.raised, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .fullScreenCover(isPresented: $appModel.assistantPresented) {
            CoveAssistantView(appModel: appModel)
        }
        .sheet(item: $appModel.swapMeal) { meal in
            MealSwapSheet(appModel: appModel, meal: meal)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(WeektableTheme.canvas)
                .presentationContentInteraction(.scrolls)
        }
        .sheet(item: $appModel.paywallTrigger) { feature in
            PaywallView(appModel: appModel, feature: feature)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
                .presentationBackground(WeektableTheme.canvas)
        }
        .sheet(isPresented: $appModel.settingsPresented) {
            NavigationStack {
                SettingsView(appModel: appModel)
            }
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(WeektableTheme.canvas)
        }
    }
}
