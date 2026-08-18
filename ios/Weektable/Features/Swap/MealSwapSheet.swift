import SwiftUI

struct MealSwapSheet: View {
    @Bindable var appModel: AppModel
    let meal: Meal
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "Cove recalculates the full basket")
                        Text("Find another dinner")
                            .font(.coveTitle)
                            .accessibilityAddTraits(.isHeader)
                        Text("Replacing \(meal.title). Each option keeps your constraints and shows the new weekly total.")
                            .font(.subheadline)
                            .foregroundStyle(WeektableTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if appModel.isLoadingSwaps {
                        VStack(spacing: 14) {
                            ProgressView()
                                .controlSize(.large)
                                .tint(WeektableTheme.brand)
                            Text("Repricing complete packages…")
                                .font(.headline)
                            Text("Cove is checking ingredient reuse and your full weekly basket.")
                                .font(.subheadline)
                                .foregroundStyle(WeektableTheme.secondaryInk)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 220)
                        .padding(20)
                        .coveCard()
                    } else if appModel.swapPreviews.isEmpty {
                        ContentUnavailableView("No swaps available", systemImage: "fork.knife", description: Text("Your original meal is unchanged."))
                    } else {
                        ForEach(Array(appModel.swapPreviews.enumerated()), id: \.element.id) { index, preview in
                            swapCard(preview, accent: WeektableTheme.preferenceAccent(at: index))
                        }
                    }

                    if let error = appModel.swapErrorMessage {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline)
                                .foregroundStyle(WeektableTheme.error)
                            Button("Try again") { appModel.openSwap(for: meal) }
                                .font(.headline)
                        }
                        .padding(16)
                        .background(WeektableTheme.error.opacity(0.09), in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))
                        .accessibilityElement(children: .contain)
                    }
                }
                .padding(WeektableTheme.pagePadding)
            }
            .background(WeektableTheme.canvas)
            .navigationTitle("Swap dinner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        appModel.dismissSwap()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .interactiveDismissDisabled(appModel.isApplyingSwap)
    }

    private func swapCard(_ preview: SwapPreview, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MealPhoto(meal: preview.meal)
                .frame(height: 170)
                .clipped()
                .overlay(alignment: .topTrailing) {
                    Text(deltaDescription(preview.deltaCents))
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(preview.deltaCents <= 0 ? WeektableTheme.success : WeektableTheme.terracotta, in: Capsule())
                        .padding(12)
                }

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(preview.meal.title)
                        .font(.coveCardTitle)
                    HStack(spacing: 8) {
                        CoveStatusPill(text: "\(preview.meal.totalMinutes)m", symbol: "clock", color: accent)
                        CoveStatusPill(text: "\(preview.reusedIngredientCount) reused", symbol: "arrow.triangle.2.circlepath", color: WeektableTheme.brand)
                    }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("New weekly basket")
                            .font(.caption)
                            .foregroundStyle(WeektableTheme.secondaryInk)
                        Text(preview.resultingTotalCents.currency)
                            .font(.title3.bold())
                            .monospacedDigit()
                    }
                    Spacer()
                    if preview.resultingTotalCents <= (appModel.plan?.budgetCents ?? 0) {
                        CoveStatusPill(text: "In budget", symbol: "checkmark", color: WeektableTheme.success)
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
                            Text("Choose this dinner")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(appModel.isApplyingSwap || preview.resultingTotalCents > (appModel.plan?.budgetCents ?? 0))

                if preview.resultingTotalCents > (appModel.plan?.budgetCents ?? 0) {
                    Label("This option is over your weekly budget.", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(WeektableTheme.error)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Uses \(preview.reusedIngredientCount) ingredients already represented in your basket.")
                        .font(.footnote)
                        .foregroundStyle(WeektableTheme.secondaryInk)
                }
            }
            .padding(17)
            .background(WeektableTheme.raised)
        }
        .clipShape(RoundedRectangle(cornerRadius: WeektableTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: WeektableTheme.cardRadius, style: .continuous)
                .stroke(WeektableTheme.divider, lineWidth: 0.75)
        }
        .shadow(color: WeektableTheme.ink.opacity(0.07), radius: 15, y: 7)
        .accessibilityElement(children: .contain)
    }

    private func deltaDescription(_ cents: Int) -> String {
        let absolute = abs(cents).currency
        if cents < 0 { return "\(absolute) less" }
        if cents > 0 { return "\(absolute) more" }
        return "Same price"
    }
}
