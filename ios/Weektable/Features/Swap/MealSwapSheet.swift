import SwiftUI

struct MealSwapSheet: View {
    @Bindable var appModel: AppModel
    let meal: Meal
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(text: "Keep the basket steady")
                        Text("Swap \(meal.title)")
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                        Text("Every option is rechecked against your full-package total before it appears here.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 4)

                    if appModel.isLoadingSwaps {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Repricing complete packages…")
                        }
                        .frame(maxWidth: .infinity, minHeight: 120)
                    } else if appModel.swapPreviews.isEmpty {
                        ContentUnavailableView("No swaps available", systemImage: "fork.knife", description: Text("Your original meal is unchanged."))
                    } else {
                        ForEach(appModel.swapPreviews) { preview in
                            swapCard(preview)
                        }
                    }
                }
                .padding(WeektableTheme.pagePadding)
            }
            .background(WeektableTheme.canvas)
            .navigationTitle("Meal swap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        appModel.dismissSwap()
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled(appModel.isApplyingSwap)
    }

    private func swapCard(_ preview: SwapPreview) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image("weektable-dinners")
                    .resizable().scaledToFill()
                    .frame(width: 88, height: 88).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(preview.meal.title).font(.headline)
                    Text("\(preview.meal.totalMinutes) min · reuses \(preview.reusedIngredientCount) basket ingredients")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(preview.deltaCents == 0 ? "No price change" : signedCurrency(preview.deltaCents))
                        .font(.headline).monospacedDigit()
                        .foregroundStyle(preview.deltaCents <= 0 ? WeektableTheme.success : WeektableTheme.brand)
                }
            }

            Button {
                appModel.applySwap(preview)
            } label: {
                HStack {
                    Text("Choose this meal")
                    Spacer()
                    Text(preview.resultingTotalCents.currency).monospacedDigit()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(appModel.isApplyingSwap || preview.resultingTotalCents > (appModel.plan?.budgetCents ?? 0))
        }
        .padding(16)
        .background(WeektableTheme.raised, in: RoundedRectangle(cornerRadius: WeektableTheme.cardRadius))
        .accessibilityElement(children: .contain)
    }

    private func signedCurrency(_ cents: Int) -> String {
        let absolute = abs(cents).currency
        return cents < 0 ? "−\(absolute)" : "+\(absolute)"
    }
}

