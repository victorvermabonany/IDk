import SwiftUI

struct WeekHomeView: View {
    @Bindable var appModel: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                if let plan = appModel.plan {
                    weekSummary(plan)

                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Meals this week")
                                .font(.coveTitle)
                            Text("\(plan.meals.count) dinners · \(plan.totalMinutes) minutes total")
                                .font(.subheadline)
                                .foregroundStyle(WeektableTheme.secondaryInk)
                        }
                        Spacer()
                    }

                    ForEach(Array(plan.meals.enumerated()), id: \.element.id) { index, meal in
                        MealCard(
                            meal: meal,
                            estimatedCostCents: estimatedCost(for: meal, in: plan),
                            featured: index == 0,
                            accent: WeektableTheme.preferenceAccent(at: index),
                            onSwap: { appModel.openSwap(for: meal) }
                        )
                    }

                    PriceSourceNotice(plan: plan)
                        .padding(.bottom, 20)
                } else {
                    ContentUnavailableView(
                        "No week yet",
                        systemImage: "calendar.badge.plus",
                        description: Text("Create a plan to see your dinners here.")
                    )
                }
            }
            .padding(.horizontal, WeektableTheme.pagePadding)
            .padding(.top, 10)
        }
        .background(WeektableTheme.canvas)
        .navigationTitle("Week")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: String.self) { mealID in
            if let meal = appModel.plan?.meals.first(where: { $0.id == mealID }) {
                RecipeDetailView(appModel: appModel, meal: meal)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                CoveBrandMark(compact: true)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Plan another week", systemImage: "plus") { appModel.planAnotherWeek() }
                    .labelStyle(.iconOnly)
                    .accessibilityHint("Starts a new weekly plan")
                Button("Settings", systemImage: "person.crop.circle") { appModel.presentSettings() }
                    .labelStyle(.iconOnly)
            }
        }
    }

    private func weekSummary(_ plan: MealPlan) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Image("weektable-dinners")
                    .resizable()
                    .scaledToFill()
                    .frame(height: dynamicTypeSize.isAccessibilitySize ? 260 : 215)
                    .clipped()
                    .accessibilityHidden(true)

                LinearGradient(
                    colors: [.clear, WeektableTheme.ink.opacity(0.74)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                HStack {
                    Text("THIS WEEK")
                        .font(.caption2.weight(.black))
                        .tracking(1.1)
                    Spacer()
                    Text("\(plan.meals.count) dinners")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(18)
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Grocery basket")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(WeektableTheme.secondaryInk)
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(plan.estimatedTotalCents.currency)
                                .font(.system(size: 31, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text("of \(plan.budgetCents.currency)")
                                .font(.subheadline)
                                .foregroundStyle(WeektableTheme.secondaryInk)
                        }
                    }
                    Spacer()
                    CoveStatusPill(
                        text: "\(plan.remainingCents.currency) left",
                        symbol: plan.remainingCents >= 0 ? "checkmark" : "exclamationmark",
                        color: plan.remainingCents >= 0 ? WeektableTheme.success : WeektableTheme.error
                    )
                }

                ProgressView(value: Double(plan.estimatedTotalCents), total: Double(max(plan.budgetCents, 1)))
                    .tint(plan.remainingCents >= 0 ? WeektableTheme.brand : WeektableTheme.error)
                    .scaleEffect(x: 1, y: 1.35)
                    .accessibilityLabel("Weekly grocery budget")
                    .accessibilityValue("\(plan.estimatedTotalCents.currency) of \(plan.budgetCents.currency)")

                Button {
                    appModel.selectGroceries()
                } label: {
                    Label("Open grocery list", systemImage: "cart.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .foregroundStyle(WeektableTheme.brandDeep)
                .background(WeektableTheme.selected, in: RoundedRectangle(cornerRadius: 15))
                .accessibilityHint("Opens the grocery list tab")
            }
            .padding(18)
            .background(WeektableTheme.raised)
        }
        .clipShape(RoundedRectangle(cornerRadius: WeektableTheme.heroRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: WeektableTheme.heroRadius, style: .continuous)
                .stroke(WeektableTheme.divider, lineWidth: 0.75)
        }
        .shadow(color: WeektableTheme.ink.opacity(0.09), radius: 18, y: 9)
        .accessibilityElement(children: .contain)
    }

    private func estimatedCost(for meal: Meal, in plan: MealPlan) -> Int {
        plan.basket.reduce(0) { partial, item in
            guard item.mealIDs.contains(meal.id) else { return partial }
            return partial + item.totalPriceCents / max(item.mealIDs.count, 1)
        }
    }
}

private struct MealCard: View {
    let meal: Meal
    let estimatedCostCents: Int
    let featured: Bool
    let accent: Color
    let onSwap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            NavigationLink(value: meal.id) {
                if featured {
                    featuredContent
                } else {
                    compactContent
                }
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, featured ? 16 : 134)

            Button(action: onSwap) {
                HStack {
                    Label("Swap dinner", systemImage: "arrow.triangle.2.circlepath")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(WeektableTheme.secondaryInk)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WeektableTheme.brandDeep)
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
            }
            .accessibilityHint("Shows alternatives and basket price changes")
        }
        .coveCard()
        .accessibilityElement(children: .contain)
    }

    private var featuredContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            MealPhoto(meal: meal)
                .frame(height: 220)
                .clipped()
                .overlay(alignment: .topLeading) { dayPill }

            VStack(alignment: .leading, spacing: 9) {
                Text(meal.title)
                    .font(.coveCardTitle)
                Text(meal.description)
                    .font(.subheadline)
                    .foregroundStyle(WeektableTheme.secondaryInk)
                    .lineLimit(2)
                metadata
            }
            .padding(16)
        }
    }

    private var compactContent: some View {
        HStack(alignment: .top, spacing: 14) {
            MealPhoto(meal: meal)
                .frame(width: 118, height: 132)
                .clipped()
                .overlay(alignment: .topLeading) { dayPill }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 9) {
                Text(meal.title)
                    .font(.headline)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                metadata
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.trailing, 14)
        }
        .padding(10)
    }

    private var dayPill: some View {
        Text(meal.day.uppercased())
            .font(.caption2.weight(.black))
            .tracking(0.7)
            .foregroundStyle(WeektableTheme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(WeektableTheme.raised.opacity(0.94), in: Capsule())
            .padding(11)
    }

    private var metadata: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                CoveStatusPill(text: "\(meal.totalMinutes)m", symbol: "clock", color: accent)
                CoveStatusPill(text: "~\(estimatedCostCents.currency)", symbol: "basket", color: WeektableTheme.brand)
            }
            VStack(alignment: .leading, spacing: 6) {
                CoveStatusPill(text: "\(meal.totalMinutes)m", symbol: "clock", color: accent)
                CoveStatusPill(text: "~\(estimatedCostCents.currency)", symbol: "basket", color: WeektableTheme.brand)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(meal.totalMinutes) minutes. About \(estimatedCostCents.currency) of the shared basket.")
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
