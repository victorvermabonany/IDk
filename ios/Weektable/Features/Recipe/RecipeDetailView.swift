import SwiftUI

struct RecipeDetailView: View {
    @Bindable var appModel: AppModel
    let meal: Meal
    @State private var cookingMode = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                hero

                VStack(alignment: .leading, spacing: 14) {
                    Text(meal.title)
                        .font(.coveTitle)
                        .foregroundStyle(WeektableTheme.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(meal.description)
                        .font(.body)
                        .foregroundStyle(WeektableTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        RecipeStat(value: "\(meal.totalMinutes)m", label: "Total time", symbol: "clock")
                        RecipeStat(value: "\(meal.servings)", label: "Servings", symbol: "person.2")
                        RecipeStat(value: "~\(estimatedMealCost.currency)", label: "Basket share", symbol: "basket")
                        RecipeStat(value: "\(meal.proteinGrams)g", label: "Protein", symbol: "bolt")
                    }

                    if ingredientReuseCount > 0 {
                        Label("\(ingredientReuseCount) ingredients also work in another dinner this week", systemImage: "arrow.triangle.2.circlepath")
                            .font(.subheadline)
                            .foregroundStyle(WeektableTheme.brand)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, WeektableTheme.pagePadding)

                CoveNutritionPanel(calories: meal.calories, proteinGrams: meal.proteinGrams)
                    .padding(.horizontal, WeektableTheme.pagePadding)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Ingredients")
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    VStack(spacing: 0) {
                        ForEach(meal.ingredients) { ingredient in
                            HStack(alignment: .firstTextBaseline, spacing: 14) {
                                Circle()
                                    .fill(WeektableTheme.sage)
                                    .frame(width: 7, height: 7)
                                Text(ingredient.name)
                                    .foregroundStyle(WeektableTheme.ink)
                                Spacer()
                                Text(ingredient.formattedQuantity)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(WeektableTheme.secondaryInk)
                                    .multilineTextAlignment(.trailing)
                            }
                            .padding(.vertical, 14)
                            if ingredient.id != meal.ingredients.last?.id { Divider() }
                        }
                    }
                    .padding(.horizontal, 16)
                    .coveCard(shadow: false)
                }
                .padding(.horizontal, WeektableTheme.pagePadding)

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Make dinner")
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        CoveStatusPill(text: "\(meal.instructions.count) steps", symbol: "list.number")
                    }

                    ForEach(Array(meal.instructions.enumerated()), id: \.offset) { index, instruction in
                        HStack(alignment: .top, spacing: 14) {
                            Text("\(index + 1)")
                                .font(.headline.bold())
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(WeektableTheme.brandDeep, in: Circle())
                            Text(instruction)
                                .font(cookingMode ? .title3 : .body)
                                .foregroundStyle(WeektableTheme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(17)
                        .coveCard(radius: WeektableTheme.controlRadius, shadow: false)
                    }
                }
                .padding(.horizontal, WeektableTheme.pagePadding)

                Label("Nutrition is an approachable planning estimate, not medical guidance.", systemImage: "heart.text.square")
                    .font(.footnote)
                    .foregroundStyle(WeektableTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, WeektableTheme.pagePadding)

                Label("Selected allergies are hard recipe constraints. Always verify packaged-food labels and cross-contact warnings.", systemImage: "exclamationmark.shield.fill")
                    .font(.footnote)
                    .foregroundStyle(WeektableTheme.ink)
                    .padding(16)
                    .background(WeektableTheme.warning.opacity(0.15), in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))
                    .padding(.horizontal, WeektableTheme.pagePadding)
                    .padding(.bottom, 26)
            }
        }
        .background(WeektableTheme.canvas)
        .navigationTitle(meal.day)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(cookingMode ? "Standard text" : "Cooking text", systemImage: cookingMode ? "textformat.size.smaller" : "textformat.size.larger") {
                    cookingMode.toggle()
                    Haptics.selection()
                }
                .accessibilityLabel(cookingMode ? "Use standard text size" : "Use larger cooking text")

                Menu {
                    Button("Swap this dinner", systemImage: "arrow.triangle.2.circlepath") { appModel.openSwap(for: meal) }
                    Button("Open groceries", systemImage: "cart") { appModel.selectGroceries() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Recipe actions")
            }
        }
    }

    private var hero: some View {
        MealPhoto(meal: meal)
            .frame(height: 300)
            .clipped()
            .containerRelativeFrame(.horizontal)
            .overlay(alignment: .bottomLeading) {
                Text("\(meal.day.uppercased()) DINNER")
                    .font(.caption2.weight(.black))
                    .tracking(1)
                    .foregroundStyle(WeektableTheme.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(WeektableTheme.raised.opacity(0.94), in: Capsule())
                    .padding(WeektableTheme.pagePadding)
            }
    }

    private var ingredientReuseCount: Int {
        guard let plan = appModel.plan else { return 0 }
        return plan.basket.filter { item in
            item.mealIDs.contains(meal.id) && item.mealIDs.count > 1
        }.count
    }

    private var estimatedMealCost: Int {
        guard let plan = appModel.plan else { return 0 }
        return plan.basket.reduce(0) { partial, item in
            guard item.mealIDs.contains(meal.id) else { return partial }
            return partial + item.totalPriceCents / max(item.mealIDs.count, 1)
        }
    }
}

private struct RecipeStat: View {
    let value: String
    let label: String
    let symbol: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WeektableTheme.brand)
                .frame(width: 32, height: 32)
                .background(WeektableTheme.selected, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .monospacedDigit()
                Text(label)
                    .font(.caption)
                    .foregroundStyle(WeektableTheme.secondaryInk)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .padding(.horizontal, 12)
        .background(WeektableTheme.surface.opacity(0.76), in: RoundedRectangle(cornerRadius: 15))
        .accessibilityElement(children: .combine)
    }
}

private struct CoveNutritionPanel: View {
    let calories: Int
    let proteinGrams: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    SectionLabel(text: "Nutrition")
                    Text("A useful snapshot")
                        .font(.coveCardTitle)
                }
                Spacer()
                Image(systemName: "chart.dots.scatter")
                    .font(.title3)
                    .foregroundStyle(WeektableTheme.terracotta)
            }

            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(WeektableTheme.surface, lineWidth: 11)
                    Circle()
                        .trim(from: 0, to: min(Double(calories) / 900, 1))
                        .stroke(WeektableTheme.gold, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(calories)")
                            .font(.title2.bold())
                            .monospacedDigit()
                        Text("cal")
                            .font(.caption)
                            .foregroundStyle(WeektableTheme.secondaryInk)
                    }
                }
                .frame(width: 106, height: 106)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Circle().fill(WeektableTheme.terracotta).frame(width: 10, height: 10)
                        Text("Protein")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(proteinGrams)g")
                            .font(.headline)
                            .monospacedDigit()
                    }
                    ProgressView(value: Double(proteinGrams), total: 70)
                        .tint(WeektableTheme.terracotta)
                    Text("A simple per-serving view, kept intentionally easy to read.")
                        .font(.caption)
                        .foregroundStyle(WeektableTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .coveCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(calories) calories and \(proteinGrams) grams of protein per serving")
    }
}
