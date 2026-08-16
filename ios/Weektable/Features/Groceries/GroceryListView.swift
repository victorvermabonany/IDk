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

                        PriceSourceNotice(priceKind: plan.priceKind)
                            .listRowInsets(EdgeInsets(top: 0, leading: WeektableTheme.pagePadding, bottom: 8, trailing: WeektableTheme.pagePadding))
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
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(isOwned(item) ? "Add to basket" : "I have this") {
                                            appModel.toggleOwned(item.id)
                                        }
                                        .tint(WeektableTheme.success)
                                    }
                                }
                            } header: {
                                HStack {
                                    Text(department.rawValue)
                                    Spacer()
                                    Text("\(items.count)").monospacedDigit()
                                }
                            }
                        }
                    }

                    Section {
                        Label(
                            itemsLeft == 0 ? "List complete" : "\(itemsLeft) items to go",
                            systemImage: itemsLeft == 0 ? "checkmark.circle.fill" : "cart"
                        )
                        .font(.headline)
                        .foregroundStyle(itemsLeft == 0 ? WeektableTheme.success : .primary)
                        .padding(.vertical, 8)
                        .accessibilityElement(children: .combine)
                    } footer: {
                        Text("Checked items stay in place so the list never jumps while you shop.")
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
        return (["Weektable grocery list"] + lines + ["Estimated total: \(appModel.groceryTotalCents.currency)", "Verify current prices and allergen labels."]).joined(separator: "\n")
    }
}

private struct GrocerySummaryCard: View {
    let totalCents: Int
    let budgetCents: Int
    let itemsLeft: Int
    let dinnerCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("At the store", systemImage: "location.fill")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                Spacer()
                Text("\(itemsLeft) left").font(.subheadline.weight(.semibold))
            }

            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text(totalCents.currency)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()
                Text("/ \(budgetCents.currency)")
                    .font(.headline).foregroundStyle(.white.opacity(0.7))
            }

            ProgressView(value: Double(totalCents), total: Double(max(budgetCents, 1)))
                .tint(.white)
                .accessibilityLabel("Grocery budget used")
                .accessibilityValue("\(totalCents.currency) of \(budgetCents.currency)")

            HStack {
                Label("\((budgetCents - totalCents).currency) left", systemImage: "checkmark.circle.fill")
                Spacer()
                Text("\(dinnerCount) dinners")
            }
            .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(WeektableTheme.brandDeep, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
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
        HStack(alignment: .center, spacing: 12) {
            Button(action: onCheck) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isChecked ? WeektableTheme.success : WeektableTheme.secondaryInk)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(isChecked ? "Uncheck" : "Check") \(item.productName)")

            Button {
                withAnimation(reduceMotion ? nil : .snappy) { expanded.toggle() }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.productName)
                        .font(.body.weight(.semibold))
                        .strikethrough(isChecked)
                        .foregroundStyle(isChecked ? .secondary : .primary)
                    Text("\(item.packageCount) × \(item.packageDisplay) · need \(item.requiredDisplay)")
                        .font(.caption).foregroundStyle(.secondary)
                    if expanded, !mealTitles.isEmpty {
                        Text("Used in \(mealTitles.joined(separator: ", "))")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows the dinners that use this item")

            Menu {
                Button(isOwned ? "Add to basket" : "I have this", action: onOwned)
            } label: {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(isOwned ? "Have it" : item.totalPriceCents.currency)
                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                    Image(systemName: "ellipsis")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(minWidth: 62, minHeight: 44, alignment: .trailing)
            }
            .accessibilityLabel("\(isOwned ? "Already have" : item.totalPriceCents.currency), options for \(item.productName)")
        }
        .padding(.vertical, 4)
        .opacity(isChecked ? 0.62 : 1)
    }
}
