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
                        Text("Your meals").font(.title2.bold())
                        Spacer()
                        Text("\(plan.meals.count) dinners · \(plan.totalMinutes) min")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    ForEach(plan.meals) { meal in
                        MealCard(
                            meal: meal,
                            onSwap: { appModel.openSwap(for: meal) }
                        )
                    }

                    PriceSourceNotice(priceKind: plan.priceKind)
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
            .padding(.top, 12)
        }
        .background(WeektableTheme.canvas)
        .navigationTitle("This week")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: String.self) { mealID in
            if let meal = appModel.plan?.meals.first(where: { $0.id == mealID }) {
                RecipeDetailView(appModel: appModel, meal: meal)
            }
        }
        .toolbar {
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
        ZStack(alignment: .bottomLeading) {
            Color.black
                .overlay {
                    Image("weektable-dinners")
                        .resizable()
                        .scaledToFill()
                        .accessibilityHidden(true)
                }
                .clipped()

            LinearGradient(
                colors: [.black.opacity(0.05), .black.opacity(0.86)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Text("THIS WEEK")
                        .font(.caption.weight(.black)).tracking(1)
                    Spacer(minLength: 8)
                    Text("\(plan.meals.count) dinners")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }

                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    Text(plan.estimatedTotalCents.currency)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .monospacedDigit()
                    Text("/ \(plan.budgetCents.currency)")
                        .font(.headline).foregroundStyle(.white.opacity(0.72))
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        remainingLabel(plan)
                        Spacer(minLength: 4)
                        groceryButton
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        remainingLabel(plan)
                        groceryButton
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(20)
        }
        .frame(height: dynamicTypeSize.isAccessibilitySize ? 410 : 300)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("This week. \(plan.meals.count) dinners. Basket \(plan.estimatedTotalCents.currency) of \(plan.budgetCents.currency). \(plan.remainingCents.currency) left.")
    }

    private func remainingLabel(_ plan: MealPlan) -> some View {
        Label("\(plan.remainingCents.currency) left", systemImage: "checkmark.circle.fill")
            .font(.headline)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var groceryButton: some View {
        Button {
            appModel.selectGroceries()
        } label: {
            Label("Groceries", systemImage: "cart.fill")
                .font(.subheadline.bold())
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(.white)
                .foregroundStyle(.black)
                .clipShape(Capsule())
        }
        .accessibilityHint("Opens the grocery list tab")
        .frame(minWidth: 44, minHeight: 44)
    }
}

private struct MealCard: View {
    let meal: Meal
    let onSwap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink(value: meal.id) {
                VStack(alignment: .leading, spacing: 0) {
                    MealPhoto(meal: meal)
                        .frame(height: 178)
                        .clipped()
                        .overlay(alignment: .topLeading) {
                            Text(meal.day.uppercased())
                                .font(.caption2.weight(.black)).tracking(0.8)
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(.ultraThickMaterial, in: Capsule())
                                .padding(12)
                        }
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(meal.title).font(.title3.bold())
                        Text(meal.description)
                            .font(.subheadline).foregroundStyle(.secondary)
                            .lineLimit(2)
                        HStack(spacing: 16) {
                            Label("\(meal.totalMinutes) min", systemImage: "clock")
                            Label("\(meal.servings)", systemImage: "person.2")
                            Label("\(meal.proteinGrams)g", systemImage: "bolt")
                        }
                        .font(.caption)
                    }
                    .padding(16)
                }
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 16)
            Button("Swap this dinner", systemImage: "arrow.triangle.2.circlepath", action: onSwap)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
                .accessibilityHint("Shows alternatives and basket price changes")
        }
        .background(WeektableTheme.raised)
        .clipShape(RoundedRectangle(cornerRadius: WeektableTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: WeektableTheme.cardRadius, style: .continuous)
                .stroke(WeektableTheme.divider.opacity(0.65), lineWidth: 0.5)
        }
        .accessibilityElement(children: .contain)
    }
}

struct PriceSourceNotice: View {
    let priceKind: PriceKind

    var body: some View {
        Label {
            Text(priceKind == .fixture
                 ? "Estimated complete-package prices for planning. Verify current shelf prices and labels."
                 : "Estimated complete-package prices · \(priceKind.rawValue.capitalized) source. Verify shelf prices and labels.")
        } icon: {
            Image(systemName: "info.circle.fill")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WeektableTheme.surface, in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))
    }
}
