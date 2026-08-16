import SwiftUI

struct MainTabView: View {
    @Bindable var appModel: AppModel

    var body: some View {
        TabView(selection: $appModel.selectedTab) {
            NavigationStack {
                WeekHomeView(appModel: appModel)
            }
            .tabItem { Label("Week", systemImage: "calendar") }
            .tag(AppTab.week)

            NavigationStack {
                GroceryListView(appModel: appModel)
            }
            .tabItem { Label("Groceries", systemImage: "cart") }
            .tag(AppTab.groceries)

            NavigationStack {
                PlanSettingsView(appModel: appModel)
            }
            .tabItem { Label("Plan", systemImage: "slider.horizontal.3") }
            .tag(AppTab.plan)

            NavigationStack {
                ProfileView()
            }
            .tabItem { Label("Profile", systemImage: "person.crop.circle") }
            .tag(AppTab.profile)
        }
        .sheet(item: $appModel.swapMeal) { meal in
            MealSwapSheet(appModel: appModel, meal: meal)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
    }
}

