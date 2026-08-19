import SwiftUI

struct HomeView: View {
    @Bindable var appModel: AppModel

    private var plan: MealPlan? { appModel.plan }
    private var tonight: Meal? { plan?.meals.first }
    private var itemsLeft: Int {
        plan?.basket.filter {
            !appModel.groceryState.ownedItemIDs.contains($0.id) &&
            !appModel.groceryState.checkedItemIDs.contains($0.id)
        }.count ?? 0
    }
    private var pantryCount: Int { appModel.groceryState.ownedItemIDs.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                VStack(alignment: .leading, spacing: 3) {
                    Text(greeting)
                        .font(.subheadline)
                        .foregroundStyle(WeektableTheme.secondaryInk)
                    Text(plan == nil ? "Let’s plan your week." : "Here’s your week.")
                        .font(.coveTitle)
                        .foregroundStyle(WeektableTheme.ink)
                }

                assistantBar

                if let plan {
                    weekHero(plan)
                } else {
                    emptyWeekHero
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    tonightTile
                    groceriesTile
                    pantryTile
                    newWeekTile
                }
            }
            .padding(.horizontal, WeektableTheme.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(WeektableTheme.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack {
            CoveBrandMark()
                .scaleEffect(0.9, anchor: .leading)
            Spacer()
            Button { } label: {
                Image(systemName: "bell")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(WeektableTheme.ink)
                    .frame(width: 38, height: 38)
            }
            .accessibilityLabel("Notifications")
            Button { appModel.presentSettings() } label: {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(WeektableTheme.brand)
                    .symbolRenderingMode(.hierarchical)
            }
            .accessibilityLabel("Profile and settings")
        }
    }

    private var assistantBar: some View {
        Button { appModel.presentAssistant() } label: {
            HStack(spacing: 10) {
                CoveOtterAvatar(size: 36)
                Text("Ask Cove anything…")
                    .font(.body)
                    .foregroundStyle(WeektableTheme.secondaryInk.opacity(0.68))
                Spacer()
                Image(systemName: "arrow.up")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(WeektableTheme.brand, in: Circle())
            }
            .padding(7)
            .background(WeektableTheme.raised, in: Capsule())
            .overlay { Capsule().stroke(WeektableTheme.divider.opacity(0.55), lineWidth: 0.75) }
            .shadow(color: WeektableTheme.ink.opacity(0.05), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens a conversation with Cove")
    }

    private func weekHero(_ plan: MealPlan) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("THIS WEEK")
                        .font(.caption2.weight(.black))
                        .tracking(0.8)
                    Text("\(plan.meals.count) dinners planned")
                        .font(.system(size: 21, weight: .semibold, design: .serif))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(appModel.groceryTotalCents.currency) of \(plan.budgetCents.currency) budget")
                        .font(.subheadline)
                        .foregroundStyle(WeektableTheme.secondaryInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)

                Image("weektable-dinners")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 142, height: 132)
                    .clipped()
                    .accessibilityHidden(true)
            }

            VStack(spacing: 10) {
                ProgressView(value: Double(appModel.groceryTotalCents), total: Double(max(plan.budgetCents, 1)))
                    .tint(WeektableTheme.brand)
                    .accessibilityLabel("Weekly grocery budget")
                    .accessibilityValue("\(appModel.groceryTotalCents.currency) of \(plan.budgetCents.currency)")

                Button { appModel.selectWeek() } label: {
                    HStack {
                        Spacer()
                        Text("View my week")
                        Image(systemName: "arrow.right")
                        Spacer()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(height: 42)
                    .background(WeektableTheme.brandDeep, in: Capsule())
                }
            }
            .padding(12)
        }
        .background(WeektableTheme.surface.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: WeektableTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: WeektableTheme.cardRadius, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        }
        .shadow(color: WeektableTheme.ink.opacity(0.07), radius: 18, y: 9)
    }

    private var emptyWeekHero: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 11) {
                Text("YOUR NEXT WEEK")
                    .font(.caption2.weight(.black))
                    .tracking(0.8)
                Text("Dinner decisions, handled.")
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                Text("Set your budget and food preferences. Cove will do the rest.")
                    .font(.subheadline)
                    .foregroundStyle(WeektableTheme.secondaryInk)
                Button("Plan a new week") { appModel.showPlanner() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 44)
                    .background(WeektableTheme.brandDeep, in: Capsule())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)

            Image("weektable-dinners")
                .resizable()
                .scaledToFill()
                .frame(width: 132, height: 180)
                .clipped()
                .accessibilityHidden(true)
        }
        .background(WeektableTheme.surface.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: WeektableTheme.cardRadius, style: .continuous))
        .shadow(color: WeektableTheme.ink.opacity(0.07), radius: 18, y: 9)
    }

    private var tonightTile: some View {
        Button {
            if plan == nil { appModel.showPlanner() } else { appModel.selectWeek() }
        } label: {
            DashboardTile(title: "Tonight", subtitle: tonight?.title ?? "No dinner planned", detail: tonight.map { "\($0.totalMinutes) min" }, imageName: tonight?.imageAssetName)
        }
        .buttonStyle(.plain)
    }

    private var groceriesTile: some View {
        Button {
            if plan == nil { appModel.showPlanner() } else { appModel.selectGroceries() }
        } label: {
            DashboardTile(title: "Groceries", subtitle: plan == nil ? "Build a week first" : "\(itemsLeft) items left", detail: plan.map { _ in "\(appModel.groceryTotalCents.currency) est." }, imageName: "cove-grocery-bag")
        }
        .buttonStyle(.plain)
    }

    private var pantryTile: some View {
        Button { appModel.selectPantry() } label: {
            DashboardTile(title: "Pantry", subtitle: "\(pantryCount) items", detail: "On hand", imageName: "cove-pantry-jars")
        }
        .buttonStyle(.plain)
    }

    private var newWeekTile: some View {
        Button { appModel.planAnotherWeek() } label: {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Plan a new week")
                        .font(.headline)
                    Text("Start from scratch")
                        .font(.subheadline)
                        .foregroundStyle(WeektableTheme.secondaryInk)
                    Spacer(minLength: 0)
                }

                Image(systemName: "plus")
                    .font(.body.weight(.medium))
                    .foregroundStyle(WeektableTheme.ink)
                    .frame(width: 38, height: 38)
                    .background(WeektableTheme.gold.opacity(0.24), in: Circle())
            }
            .foregroundStyle(WeektableTheme.ink)
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 128, maxHeight: 128, alignment: .leading)
            .coveCard(radius: 20)
        }
        .buttonStyle(.plain)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 12 { return "Good morning." }
        if hour < 18 { return "Good afternoon." }
        return "Good evening."
    }
}

private struct DashboardTile: View {
    let title: String
    let subtitle: String
    let detail: String?
    let imageName: String?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(WeektableTheme.ink)
                    .lineLimit(2)
                    .frame(maxWidth: imageName == nil ? .infinity : 94, alignment: .leading)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(WeektableTheme.brand)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if let imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 58, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(WeektableTheme.ink)
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 128, maxHeight: 128, alignment: .leading)
        .coveCard(radius: 20)
    }
}
