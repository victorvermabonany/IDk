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

                    if let error = appModel.swapErrorMessage {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                            Button("Try again") {
                                appModel.openSwap(for: meal)
                            }
                            .font(.headline)
                        }
                        .padding(16)
                        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))
                        .accessibilityElement(children: .contain)
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
                Image(preview.meal.imageAssetName)
                    .resizable().scaledToFill()
                    .frame(width: 88, height: 88).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(preview.meal.title).font(.headline)
                    Text("\(preview.meal.totalMinutes) min · reuses \(preview.reusedIngredientCount) basket ingredients")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(deltaDescription(preview.deltaCents))
                        .font(.headline).monospacedDigit()
                        .foregroundStyle(preview.deltaCents <= 0 ? WeektableTheme.success : WeektableTheme.brand)
                }
            }

            Button {
                appModel.applySwap(preview)
            } label: {
                HStack {
                    if appModel.applyingSwapPreviewID == preview.id {
                        ProgressView().tint(.white)
                        Text("Updating basket…")
                    } else {
                        Text("Choose meal")
                    }
                    Spacer()
                    Text("New basket \(preview.resultingTotalCents.currency)").monospacedDigit()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(appModel.isApplyingSwap || preview.resultingTotalCents > (appModel.plan?.budgetCents ?? 0))

            if preview.resultingTotalCents > (appModel.plan?.budgetCents ?? 0) {
                Label("Over your weekly budget, so this option cannot be selected.", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(WeektableTheme.error)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("The amount above is the estimated total for your full weekly basket.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(WeektableTheme.raised, in: RoundedRectangle(cornerRadius: WeektableTheme.cardRadius))
        .accessibilityElement(children: .contain)
    }

    private func deltaDescription(_ cents: Int) -> String {
        let absolute = abs(cents).currency
        if cents < 0 { return "\(absolute) less" }
        if cents > 0 { return "\(absolute) more" }
        return "No price change"
    }
}
