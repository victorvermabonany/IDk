import SwiftUI

struct RecipeDetailView: View {
    @Bindable var appModel: AppModel
    let meal: Meal
    @State private var cookingMode = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                Image(meal.imageAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 270)
                    .clipped()
                    .containerRelativeFrame(.horizontal)
                    .accessibilityLabel("Prepared \(meal.title)")

                VStack(alignment: .leading, spacing: 14) {
                    SectionLabel(text: "\(meal.day) dinner")
                    Text(meal.title)
                        .font(.title.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text(meal.description)
                        .font(.body).foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        RecipeStat(value: "\(meal.prepMinutes)m", label: "Prep")
                        RecipeStat(value: "\(meal.cookMinutes)m", label: "Cook")
                        RecipeStat(value: "\(meal.servings)", label: "Servings")
                        RecipeStat(value: "\(meal.proteinGrams)g", label: "Protein")
                    }

                    if ingredientReuseCount > 0 {
                        Label("\(ingredientReuseCount) ingredients also work in another dinner this week", systemImage: "arrow.triangle.2.circlepath")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, WeektableTheme.pagePadding)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Ingredients").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                    VStack(spacing: 0) {
                        ForEach(meal.ingredients) { ingredient in
                            HStack(alignment: .firstTextBaseline) {
                                Text(ingredient.name)
                                Spacer()
                                Text(ingredient.formattedQuantity)
                                    .fontWeight(.semibold).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 13)
                            if ingredient.id != meal.ingredients.last?.id { Divider() }
                        }
                    }
                    .padding(.horizontal, 16)
                    .background(WeektableTheme.raised, in: RoundedRectangle(cornerRadius: WeektableTheme.cardRadius))
                }
                .padding(.horizontal, WeektableTheme.pagePadding)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Make dinner").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                    ForEach(Array(meal.instructions.enumerated()), id: \.offset) { index, instruction in
                        HStack(alignment: .top, spacing: 14) {
                            Text("\(index + 1)")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(WeektableTheme.brandDeep, in: Circle())
                            Text(instruction)
                                .font(cookingMode ? .title3 : .body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .background(WeektableTheme.raised, in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))
                    }
                }
                .padding(.horizontal, WeektableTheme.pagePadding)

                Label("Approximately \(meal.calories) calories and \(meal.proteinGrams)g protein per serving. Nutrition is a planning estimate, not medical guidance.", systemImage: "heart.text.square")
                    .font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, WeektableTheme.pagePadding)

                Label("Selected allergies are hard recipe constraints. Always verify packaged-food labels and cross-contact warnings.", systemImage: "exclamationmark.shield.fill")
                    .font(.footnote).foregroundStyle(.primary.opacity(0.78))
                    .padding(16)
                    .background(WeektableTheme.warning.opacity(0.18), in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))
                    .padding(.horizontal, WeektableTheme.pagePadding)
                    .padding(.bottom, 24)
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

    private var ingredientReuseCount: Int {
        guard let plan = appModel.plan else { return 0 }
        return plan.basket.filter { item in
            item.mealIDs.contains(meal.id) && item.mealIDs.count > 1
        }.count
    }
}

private struct RecipeStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.headline).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(WeektableTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
