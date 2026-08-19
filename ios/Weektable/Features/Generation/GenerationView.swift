import SwiftUI

struct GenerationView: View {
    @Bindable var appModel: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    CoveBrandMark()
                        .padding(.top, 8)

                    generationVisual

                    VStack(alignment: .leading, spacing: 9) {
                        SectionLabel(text: "Building your week")
                        Text(appModel.generationFailure?.title ?? appModel.generationStage.rawValue)
                            .font(.coveTitle)
                            .foregroundStyle(WeektableTheme.ink)
                            .contentTransition(.numericText())
                            .accessibilityAddTraits(.isHeader)
                        Text(appModel.generationFailure?.message ?? "Cove is matching meals, package prices, and your budget.")
                            .font(.body)
                            .foregroundStyle(WeektableTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if appModel.generationFailure == nil {
                        ProgressView(value: appModel.generationProgress)
                            .tint(WeektableTheme.brand)
                            .scaleEffect(x: 1, y: 1.5)
                            .accessibilityLabel("Plan generation progress")
                            .accessibilityValue(appModel.generationProgress.formatted(.percent))

                        VStack(spacing: 0) {
                            ForEach(Array(GenerationStage.allCases.enumerated()), id: \.element) { index, stage in
                                HStack(spacing: 14) {
                                    Image(systemName: statusSymbol(for: index))
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(statusColor(for: index))
                                        .frame(width: 30, height: 30)
                                        .background(statusColor(for: index).opacity(0.10), in: Circle())
                                    Text(stage.rawValue)
                                        .font(.subheadline.weight(index == activeIndex ? .bold : .regular))
                                        .foregroundStyle(index <= activeIndex ? WeektableTheme.ink : WeektableTheme.secondaryInk)
                                    Spacer()
                                }
                                .frame(minHeight: 52)
                                if index != GenerationStage.allCases.count - 1 { Divider().padding(.leading, 44) }
                            }
                        }
                        .padding(.horizontal, 16)
                        .coveCard()
                    } else {
                        failureActions
                    }

                    Label("Your completed plan will show whether prices are provider-listed or estimated.", systemImage: "checkmark.shield")
                        .font(.caption)
                        .foregroundStyle(WeektableTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 26)
                }
                .padding(.horizontal, WeektableTheme.pagePadding)
            }
            .background(WeektableTheme.canvas)
            .navigationBarBackButtonHidden()
            .toolbar {
                if appModel.generationFailure != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { appModel.cancelGeneration() }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var failureActions: some View {
        if let failure = appModel.generationFailure {
            switch failure.kind {
            case .budget:
                Button("Adjust budget") { appModel.reviewGenerationBudget() }
                    .buttonStyle(PrimaryButtonStyle())
                secondaryButton("Review preferences") { appModel.reviewGenerationPreferences() }
            case .constraints:
                Button("Review preferences") { appModel.reviewGenerationPreferences() }
                    .buttonStyle(PrimaryButtonStyle())
                secondaryButton("Adjust budget") { appModel.reviewGenerationBudget() }
            case .pricing:
                Button("Review store & budget") { appModel.reviewGenerationBudget() }
                    .buttonStyle(PrimaryButtonStyle())
                secondaryButton("Try again") { appModel.retryGeneration() }
            case .expired:
                Button("Review my answers") { appModel.reviewGenerationBudget() }
                    .buttonStyle(PrimaryButtonStyle())
            case .temporary, .offline:
                Button("Try again") { appModel.retryGeneration() }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 50)
    }

    private var generationVisual: some View {
        ZStack {
            Image("weektable-dinners")
                .resizable()
                .scaledToFill()
                .frame(height: 180)
                .clipped()
            Color.black.opacity(0.16)
            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)
                .symbolEffect(.pulse, value: reduceMotion ? GenerationStage.planning : appModel.generationStage)
                .frame(width: 70, height: 70)
                .background(.ultraThinMaterial, in: Circle())
        }
        .clipShape(RoundedRectangle(cornerRadius: WeektableTheme.heroRadius, style: .continuous))
        .shadow(color: WeektableTheme.ink.opacity(0.10), radius: 16, y: 8)
        .accessibilityHidden(true)
    }

    private var activeIndex: Int {
        GenerationStage.allCases.firstIndex(of: appModel.generationStage) ?? 0
    }

    private func statusSymbol(for index: Int) -> String {
        if index < activeIndex { return "checkmark" }
        if index == activeIndex { return "sparkles" }
        return "circle"
    }

    private func statusColor(for index: Int) -> Color {
        index <= activeIndex ? WeektableTheme.brand : WeektableTheme.secondaryInk
    }
}
