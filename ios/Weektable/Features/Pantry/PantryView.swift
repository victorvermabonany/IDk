import SwiftUI

struct PantryView: View {
    @Bindable var appModel: AppModel

    private var ownedItems: [BasketItem] {
        appModel.plan?.basket.filter { appModel.groceryState.ownedItemIDs.contains($0.id) } ?? []
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                pantryHero

                if ownedItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "cabinet")
                            .font(.system(size: 34, weight: .light))
                            .foregroundStyle(WeektableTheme.brand)
                        Text("Your pantry is ready to fill")
                            .font(.coveCardTitle)
                        Text("Mark grocery items as already on hand and they’ll appear here while Cove recalculates your basket.")
                            .font(.subheadline)
                            .foregroundStyle(WeektableTheme.secondaryInk)
                            .multilineTextAlignment(.center)
                        Button(appModel.plan == nil ? "Plan a new week" : "Open groceries") {
                            if appModel.plan == nil { appModel.showPlanner() }
                            else { appModel.selectGroceries() }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(24)
                    .coveCard()
                } else {
                    SectionLabel(text: "On hand")
                    ForEach(ownedItems) { item in
                        PantryRow(item: item) { appModel.toggleOwned(item.id) }
                    }
                }
            }
            .padding(.horizontal, WeektableTheme.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(WeektableTheme.canvas.ignoresSafeArea())
        .navigationTitle("Pantry")
        .navigationBarTitleDisplayMode(.large)
    }

    private var pantryHero: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 7) {
                Text("PANTRY")
                    .font(.caption2.weight(.black))
                    .tracking(0.8)
                Text("\(ownedItems.count) items on hand")
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                Text("Cove removes these from your grocery total automatically.")
                    .font(.subheadline)
                    .foregroundStyle(WeektableTheme.secondaryInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image("cove-pantry-jars")
                .resizable()
                .scaledToFill()
                .frame(width: 128, height: 128)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityHidden(true)
        }
        .padding(16)
        .coveCard()
    }
}

private struct PantryRow: View {
    let item: BasketItem
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: departmentSymbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(WeektableTheme.brand)
                .frame(width: 42, height: 42)
                .background(WeektableTheme.selected, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayName)
                    .font(.body.weight(.semibold))
                Text(item.packageDisplay)
                    .font(.caption)
                    .foregroundStyle(WeektableTheme.secondaryInk)
            }
            Spacer()
            Button("Need it") { remove() }
                .font(.caption.weight(.semibold))
                .foregroundStyle(WeektableTheme.terracotta)
                .frame(minWidth: 64, minHeight: 44)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .coveCard(radius: WeektableTheme.controlRadius, shadow: false)
    }

    private var departmentSymbol: String {
        switch item.department {
        case .produce: "leaf"
        case .meat: "takeoutbag.and.cup.and.straw"
        case .dairy: "waterbottle"
        case .bakery: "birthday.cake"
        case .pantry, .canned, .seasonings, .other: "cabinet"
        }
    }
}
