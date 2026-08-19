import SwiftUI

struct WeekHomeView: View {
    @Bindable var appModel: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                WeekDateStrip()

                if let plan = appModel.plan {
                    HStack {
                        Text("\(plan.meals.count) dinners · \(plan.totalMinutes) minutes total")
                            .font(.subheadline)
                            .foregroundStyle(WeektableTheme.secondaryInk)
                        Spacer()
                    }

                    budgetSummary(plan)

                    ForEach(Array(plan.meals.enumerated()), id: \.element.id) { index, meal in
                        WeekMealRow(
                            meal: meal,
                            estimatedCostCents: estimatedCost(for: meal, in: plan),
                            dayLabel: WeekdayLabel.label(for: meal.day, index: index),
                            onSwap: { appModel.openSwap(for: meal) }
                        )
                    }

                    PriceSourceNotice(plan: plan)
                        .padding(.top, 4)
                        .padding(.bottom, 18)
                } else {
                    VStack(spacing: 14) {
                        Image("weektable-dinners")
                            .resizable()
                            .scaledToFill()
                            .frame(height: 210)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: WeektableTheme.cardRadius, style: .continuous))
                            .accessibilityHidden(true)
                        Text("No week planned yet")
                            .font(.coveCardTitle)
                        Text("Start with your budget, household, and food preferences. Cove will build the rest.")
                            .font(.subheadline)
                            .foregroundStyle(WeektableTheme.secondaryInk)
                            .multilineTextAlignment(.center)
                        Button("Plan a new week") { appModel.showPlanner() }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(18)
                    .coveCard()
                }
            }
            .padding(.horizontal, WeektableTheme.pagePadding)
            .padding(.top, 6)
        }
        .background(WeektableTheme.canvas.ignoresSafeArea())
        .navigationTitle("My Week")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: String.self) { mealID in
            if let meal = appModel.plan?.meals.first(where: { $0.id == mealID }) {
                RecipeDetailView(appModel: appModel, meal: meal)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Plan another week", systemImage: "calendar.badge.plus") { appModel.planAnotherWeek() }
                    .labelStyle(.iconOnly)
                    .accessibilityHint("Starts a new weekly plan")
            }
        }
    }

    private func budgetSummary(_ plan: MealPlan) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Estimated basket")
                        .font(.caption2)
                        .foregroundStyle(WeektableTheme.secondaryInk)
                    Text("\(appModel.groceryTotalCents.currency) of \(plan.budgetCents.currency)")
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                Spacer()
                Text(budgetBalance(for: plan))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(appModel.groceryTotalCents <= plan.budgetCents ? WeektableTheme.brand : WeektableTheme.error)
            }
            ProgressView(value: Double(appModel.groceryTotalCents), total: Double(max(plan.budgetCents, 1)))
                .tint(WeektableTheme.brand)
        }
        .padding(9)
        .background(WeektableTheme.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: appModel.groceryTotalCents)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Estimated basket \(appModel.groceryTotalCents.currency) of \(plan.budgetCents.currency), \(budgetBalance(for: plan))")
    }

    private func budgetBalance(for plan: MealPlan) -> String {
        if appModel.groceryTotalCents <= plan.budgetCents {
            return "\((plan.budgetCents - appModel.groceryTotalCents).currency) remaining"
        }
        return "\((appModel.groceryTotalCents - plan.budgetCents).currency) over budget"
    }

    private func estimatedCost(for meal: Meal, in plan: MealPlan) -> Int {
        plan.basket.reduce(0) { partial, item in
            guard item.mealIDs.contains(meal.id) else { return partial }
            return partial + item.totalPriceCents / max(item.mealIDs.count, 1)
        }
    }
}

private struct WeekDateStrip: View {
    private let dates: [Date] = {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }()

    var body: some View {
        HStack(spacing: 0) {
            ForEach(dates, id: \.self) { date in
                VStack(spacing: 4) {
                    Text(date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption.weight(.semibold))
                    Text(date.formatted(.dateTime.day()))
                        .font(.caption)
                }
                .foregroundStyle(Calendar.current.isDateInToday(date) ? .white : WeektableTheme.ink)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(Calendar.current.isDateInToday(date) ? WeektableTheme.terracotta : Color.clear, in: Capsule())
            }
        }
        .padding(5)
        .background(WeektableTheme.raised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: WeektableTheme.ink.opacity(0.045), radius: 12, y: 5)
        .accessibilityElement(children: .contain)
    }
}

private struct WeekMealRow: View {
    let meal: Meal
    let estimatedCostCents: Int
    let dayLabel: String
    let onSwap: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            NavigationLink(value: meal.id) {
                HStack(spacing: 9) {
                    MealPhoto(meal: meal)
                        .frame(width: 82, height: 80)
                        .clipped()
                        .overlay(alignment: .topLeading) {
                            Text(dayLabel)
                                .font(.caption2.weight(.black))
                                .foregroundStyle(WeektableTheme.ink)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background((dayLabel == "TODAY" ? WeektableTheme.gold : WeektableTheme.raised).opacity(0.94), in: Capsule())
                                .padding(6)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(meal.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(WeektableTheme.ink)
                            .lineLimit(2, reservesSpace: true)
                        Text("~\(estimatedCostCents.currency)")
                            .font(.caption)
                            .foregroundStyle(WeektableTheme.brand)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .trailing, spacing: 6) {
                Text("\(meal.totalMinutes) min")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(WeektableTheme.terracotta)
                    .monospacedDigit()
                Button(action: onSwap) {
                    Label("Swap", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WeektableTheme.brand)
                        .padding(.horizontal, 8)
                        .frame(minHeight: 36)
                        .background(WeektableTheme.selected, in: Capsule())
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Swap \(meal.title)")
                .accessibilityHint("Shows alternative dinners")
            }
        }
        .padding(5)
        .coveCard(radius: 18, shadow: false)
        .accessibilityElement(children: .contain)
    }
}

enum WeekdayLabel {
    private static let knownDays: [String: String] = [
        "sun": "SUN", "mon": "MON", "tue": "TUE", "wed": "WED",
        "thu": "THU", "fri": "FRI", "sat": "SAT"
    ]
    private static let fallbackDays = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

    static func label(for mealDay: String, index: Int, now: Date = .now, calendar: Calendar = .current) -> String {
        if index == 0 { return "TODAY" }

        let normalized = mealDay.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.count >= 3 {
            let prefix = String(normalized.prefix(3))
            if let known = knownDays[prefix] { return known }
        }

        let date = calendar.date(byAdding: .day, value: index, to: now) ?? now
        let weekday = calendar.component(.weekday, from: date)
        return fallbackDays[max(0, min(weekday - 1, fallbackDays.count - 1))]
    }
}

struct PriceSourceNotice: View {
    let plan: MealPlan

    var body: some View {
        Label(message, systemImage: "info.circle")
            .font(.caption)
            .foregroundStyle(WeektableTheme.secondaryInk)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WeektableTheme.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))
    }

    private var message: String {
        if plan.pricingProvenance?.pricingMode == "live" || plan.priceKind == .live || plan.priceKind == .feed {
            return "\(plan.pricingProvenance?.providerName ?? "Provider") listed prices for \(plan.pricingProvenance?.storeName ?? plan.store.name). Verify current shelf prices and labels."
        }
        if plan.pricingProvenance?.pricingMode == "fixture" || plan.priceKind == .fixture {
            return "Estimated basket · Development prices, not current retailer prices."
        }
        return "Estimated basket · Package-price estimates, not current retailer prices."
    }
}
