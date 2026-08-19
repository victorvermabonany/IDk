import SwiftUI
import UIKit

struct GroceryListView: View {
    @Bindable var appModel: AppModel

    private var plan: MealPlan? { appModel.plan }
    private var neededItems: [BasketItem] {
        plan?.basket.filter { !isOwned($0) } ?? []
    }
    private var itemsLeft: Int {
        neededItems.filter { !appModel.groceryState.checkedItemIDs.contains($0.id) }.count
    }

    var body: some View {
        Group {
            if let plan {
                List {
                    Section {
                        GrocerySummaryCard(
                            totalCents: appModel.groceryTotalCents,
                            budgetCents: plan.budgetCents,
                            itemsLeft: itemsLeft,
                            dinnerCount: plan.meals.count
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: WeektableTheme.pagePadding, bottom: 14, trailing: WeektableTheme.pagePadding))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                        PriceSourceNotice(plan: plan)
                            .listRowInsets(EdgeInsets(top: 0, leading: WeektableTheme.pagePadding, bottom: 10, trailing: WeektableTheme.pagePadding))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }

                    ForEach(Department.allCases) { department in
                        let items = plan.basket.filter { $0.department == department }
                        if !items.isEmpty {
                            Section {
                                ForEach(items) { item in
                                    GroceryRow(
                                        item: item,
                                        isChecked: appModel.groceryState.checkedItemIDs.contains(item.id),
                                        isOwned: isOwned(item),
                                        mealTitles: mealTitles(for: item),
                                        onCheck: { appModel.toggleChecked(item.id) },
                                        onOwned: { appModel.toggleOwned(item.id) }
                                    )
                                    .listRowInsets(EdgeInsets(top: 0, leading: WeektableTheme.pagePadding, bottom: 0, trailing: WeektableTheme.pagePadding))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(isOwned(item) ? "Add to groceries" : "Mark as on hand") {
                                            appModel.toggleOwned(item.id)
                                        }
                                        .tint(WeektableTheme.success)
                                    }
                                }
                            } header: {
                                HStack {
                                    Text(department.rawValue)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(WeektableTheme.ink)
                                    Spacer()
                                    Text("\(items.count)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(WeektableTheme.secondaryInk)
                                        .monospacedDigit()
                                }
                                .textCase(nil)
                                .padding(.horizontal, 4)
                            }
                        }
                    }

                    Section {
                        Label(
                            itemsLeft == 0 ? "List complete" : "\(itemsLeft) items to go",
                            systemImage: itemsLeft == 0 ? "checkmark.circle.fill" : "cart"
                        )
                        .font(.headline)
                        .foregroundStyle(itemsLeft == 0 ? WeektableTheme.success : WeektableTheme.ink)
                        .padding(.vertical, 12)
                        .accessibilityElement(children: .combine)
                    } footer: {
                        Text("Checked items stay in place, so nothing jumps while you shop.")
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(WeektableTheme.canvas)
            } else {
                ContentUnavailableView("No grocery list", systemImage: "cart", description: Text("Build a weekly plan first."))
            }
        }
        .navigationTitle("Groceries")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if let plan {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: shareText(plan)) {
                        Label("Share grocery list", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .onChange(of: itemsLeft) { oldValue, newValue in
            if oldValue > 0, newValue == 0 {
                Haptics.success()
                UIAccessibility.post(notification: .announcement, argument: "Grocery list complete")
            }
        }
    }

    private func isOwned(_ item: BasketItem) -> Bool {
        appModel.groceryState.ownedItemIDs.contains(item.id)
    }

    private func mealTitles(for item: BasketItem) -> [String] {
        guard let plan else { return [] }
        return item.mealIDs.compactMap { id in plan.meals.first(where: { $0.id == id })?.title }
    }

    private func shareText(_ plan: MealPlan) -> String {
        let lines = Department.allCases.flatMap { department -> [String] in
            let items = plan.basket.filter { $0.department == department && !isOwned($0) }
            guard !items.isEmpty else { return [] }
            return [department.rawValue.uppercased()] + items.map { "• \($0.productName) · \($0.packageCount) × \($0.packageDisplay)" }
        }
        return (["Cove grocery list"] + lines + ["Estimated basket: \(appModel.groceryTotalCents.currency) of \(plan.budgetCents.currency)", "Verify current prices and allergen labels."]).joined(separator: "\n")
    }
}

private struct GrocerySummaryCard: View {
    let totalCents: Int
    let budgetCents: Int
    let itemsLeft: Int
    let dinnerCount: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Estimated basket", systemImage: "basket.fill")
                    .font(.caption.weight(.black))
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                Text("\(itemsLeft) left")
                    .font(.subheadline.weight(.bold))
            }

            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text(totalCents.currency)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("of \(budgetCents.currency)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
            }

            ProgressView(value: Double(totalCents), total: Double(max(budgetCents, 1)))
                .tint(.white)
                .scaleEffect(x: 1, y: 1.3)
                .accessibilityLabel("Estimated basket budget")
                .accessibilityValue("\(totalCents.currency) of \(budgetCents.currency)")

            HStack {
                Label(balanceText, systemImage: totalCents <= budgetCents ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                Spacer()
                Text("\(dinnerCount) dinners")
            }
            .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(18)
        .background(WeektableTheme.brandDeep, in: RoundedRectangle(cornerRadius: WeektableTheme.heroRadius, style: .continuous))
        .shadow(color: WeektableTheme.brandDeep.opacity(0.14), radius: 14, y: 7)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: totalCents)
        .accessibilityElement(children: .combine)
    }

    private var balanceText: String {
        if totalCents <= budgetCents { return "\((budgetCents - totalCents).currency) remaining" }
        return "\((totalCents - budgetCents).currency) over budget"
    }
}

private struct GroceryRow: View {
    let item: BasketItem
    let isChecked: Bool
    let isOwned: Bool
    let mealTitles: [String]
    let onCheck: () -> Void
    let onOwned: () -> Void
    @State private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .center, spacing: 11) {
            Button(action: isOwned ? onOwned : onCheck) {
                Image(systemName: statusSymbol)
                    .font(.title2)
                    .foregroundStyle(statusColor)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(statusActionLabel)

            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.productName)
                        .font(.body.weight(.semibold))
                        .strikethrough(isChecked)
                        .foregroundStyle(isChecked ? WeektableTheme.secondaryInk : WeektableTheme.ink)
                        .lineLimit(2)
                    Text("\(item.packageCount) × \(item.packageDisplay) · need \(item.requiredDisplay)")
                        .font(.caption)
                        .foregroundStyle(WeektableTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                    if expanded, !mealTitles.isEmpty {
                        Text("Used in \(mealTitles.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(WeektableTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows the dinners that use this item")

            Menu {
                Button(isOwned ? "Add to groceries" : "Mark as on hand", action: onOwned)
            } label: {
                VStack(alignment: .trailing, spacing: 5) {
                    if isOwned {
                        Text("On hand")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(WeektableTheme.success)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(WeektableTheme.success.opacity(0.12), in: Capsule())
                    } else {
                        Text(item.totalPriceCents.currency)
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(WeektableTheme.ink)
                    }
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .foregroundStyle(WeektableTheme.secondaryInk)
                }
                .frame(width: 76, minHeight: 44, alignment: .trailing)
            }
            .accessibilityLabel("\(isOwned ? "On hand" : item.totalPriceCents.currency), options for \(item.productName)")
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 4)
        .background(rowFill)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(rowStroke)
                .frame(height: 0.75)
        }
        .opacity(isChecked ? 0.64 : 1)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isChecked)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isOwned)
    }

    private var statusSymbol: String {
        if isOwned { return "checkmark.seal.fill" }
        return isChecked ? "checkmark.circle.fill" : "circle"
    }

    private var statusColor: Color {
        if isOwned { return WeektableTheme.success }
        return isChecked ? WeektableTheme.brand : WeektableTheme.secondaryInk
    }

    private var statusActionLabel: String {
        if isOwned { return "Add \(item.productName) to groceries" }
        return "\(isChecked ? "Uncheck" : "Check") \(item.productName)"
    }

    private var rowFill: Color {
        if isOwned { return WeektableTheme.sage.opacity(0.09) }
        if isChecked { return WeektableTheme.surface.opacity(0.44) }
        return .clear
    }

    private var rowStroke: Color {
        isOwned ? WeektableTheme.success.opacity(0.25) : WeektableTheme.divider
    }
}
