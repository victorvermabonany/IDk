import SwiftUI

struct WeekHomeView: View {
    @Bindable var appModel: AppModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
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
                            isTonight: index == 0,
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
        VStack(spacing: 7) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current grocery spend")
                        .font(.caption2)
                        .foregroundStyle(WeektableTheme.secondaryInk)
                    Text(appModel.groceryTotalCents.currency)
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .monospacedDigit()
                }
                Spacer()
                Text("\(max(plan.budgetCents - appModel.groceryTotalCents, 0).currency) left")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WeektableTheme.brand)
            }
            ProgressView(value: Double(appModel.groceryTotalCents), total: Double(max(plan.budgetCents, 1)))
                .tint(WeektableTheme.brand)
        }
        .padding(10)
        .background(WeektableTheme.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current grocery spend \(appModel.groceryTotalCents.currency) of \(plan.budgetCents.currency)")
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
            ForEach(Array(dates.enumerated()), id: \.offset) { index, date in
                VStack(spacing: 4) {
                    Text(date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption.weight(.semibold))
                    Text(date.formatted(.dateTime.day()))
                        .font(.caption)
                }
                .foregroundStyle(index == 0 ? .white : WeektableTheme.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(index == 0 ? WeektableTheme.terracotta : Color.clear, in: Capsule())
            }
        }
        .padding(6)
        .background(WeektableTheme.raised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: WeektableTheme.ink.opacity(0.045), radius: 12, y: 5)
        .accessibilityElement(children: .contain)
    }
}

private struct WeekMealRow: View {
    let meal: Meal
    let estimatedCostCents: Int
    let isTonight: Bool
    let onSwap: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            NavigationLink(value: meal.id) {
                HStack(spacing: 10) {
                    MealPhoto(meal: meal)
                        .frame(width: 88, height: 86)
                        .clipped()
                        .overlay(alignment: .topLeading) {
                            Text(isTonight ? "TODAY" : shortDay)
                                .font(.caption2.weight(.black))
                                .foregroundStyle(WeektableTheme.ink)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background((isTonight ? WeektableTheme.gold : WeektableTheme.raised).opacity(0.94), in: Capsule())
                                .padding(6)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(meal.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(WeektableTheme.ink)
                            .lineLimit(3)
                        Text("~\(estimatedCostCents.currency)")
                            .font(.caption)
                            .foregroundStyle(WeektableTheme.brand)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .trailing, spacing: 8) {
                Text("\(meal.totalMinutes) min")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(WeektableTheme.terracotta)
                    .monospacedDigit()
                Button(action: onSwap) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WeektableTheme.brand)
                        .frame(width: 38, height: 38)
                        .background(WeektableTheme.selected, in: Circle())
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Swap \(meal.title)")
            }
        }
        .padding(6)
        .coveCard(radius: 20)
        .accessibilityElement(children: .contain)
    }

    private var shortDay: String {
        String(meal.day.prefix(3)).uppercased()
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
        if plan.pricingProvenance?.pricingMode == "live" {
            return "\(plan.pricingProvenance?.providerName ?? "Provider") listed prices for \(plan.pricingProvenance?.storeName ?? plan.store.name). Verify current shelf prices and labels."
        }
        if plan.pricingProvenance?.pricingMode == "fixture" || plan.priceKind == .fixture {
            return "Development fixture prices. Not current store pricing."
        }
        return "Estimated basket · Cove complete-package estimates. Prices may differ at your store."
    }
}
