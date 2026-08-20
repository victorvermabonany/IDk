import SwiftUI

struct PlanHistoryView: View {
    @Bindable var appModel: AppModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if appModel.planHistory.isEmpty {
                    ContentUnavailableView(
                        "No previous weeks yet",
                        systemImage: "calendar.badge.clock",
                        description: Text("Completed plans will appear here as saved snapshots.")
                    )
                    .padding(.top, 48)
                } else {
                    ForEach(appModel.planHistory) { plan in
                        historyCard(plan)
                    }
                }
            }
            .padding(WeektableTheme.pagePadding)
        }
        .background(WeektableTheme.canvas)
        .navigationTitle("Plan history")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func historyCard(_ plan: MealPlan) -> some View {
        Button { appModel.openHistoricalPlan(plan) } label: {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(weekLabel(plan))
                            .font(.headline)
                            .foregroundStyle(WeektableTheme.ink)
                        Text(plan.store.name)
                            .font(.subheadline)
                            .foregroundStyle(WeektableTheme.secondaryInk)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(WeektableTheme.secondaryInk)
                }

                HStack(spacing: 8) {
                    ForEach(Array(plan.meals.prefix(3))) { meal in
                        MealPhoto(meal: meal)
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .accessibilityHidden(true)

                HStack {
                    Label("\(plan.meals.count) dinners", systemImage: "fork.knife")
                    Spacer()
                    Text("\(plan.estimatedTotalCents.currency) of \(plan.budgetCents.currency)")
                        .monospacedDigit()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(WeektableTheme.brand)
            }
            .padding(15)
            .coveCard(radius: 20, shadow: false)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Loads this saved week without regenerating it")
    }

    private func weekLabel(_ plan: MealPlan) -> String {
        guard plan.createdDate != .distantPast else { return "Saved week" }
        return "Week of \(plan.createdDate.formatted(.dateTime.month(.abbreviated).day().year()))"
    }
}
