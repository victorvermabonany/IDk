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
                            .contentTransition(.opacity)
                            .accessibilityAddTraits(.isHeader)
                        Text(appModel.generationFailure?.message ?? appModel.generationStage.supportingCopy)
                            .font(.body)
                            .foregroundStyle(WeektableTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: appModel.generationStage)

                    if appModel.generationFailure == nil {
                        VStack(spacing: 0) {
                            ForEach(Array(GenerationStage.allCases.enumerated()), id: \.element) { index, stage in
                                HStack(spacing: 14) {
                                    Image(systemName: statusSymbol(for: index))
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(statusColor(for: index))
                                        .frame(width: 30, height: 30)
                                        .background(statusColor(for: index).opacity(0.10), in: Circle())
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(stage.rawValue)
                                            .font(.subheadline.weight(index == activeIndex ? .bold : .semibold))
                                            .foregroundStyle(stageTitleColor(for: index))
                                        Text(stage.supportingCopy)
                                            .font(.caption)
                                            .foregroundStyle(WeektableTheme.secondaryInk.opacity(index > activeIndex ? 0.72 : 1))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    index == activeIndex ? WeektableTheme.brand.opacity(0.08) : .clear,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                )
                                .accessibilityElement(children: .combine)
                            }
                        }
                        .padding(8)
                        .coveCard()
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: appModel.generationStage)

                        if let metadata = appModel.generationMetadata, !metadata.isEmpty {
                            generationFacts(metadata)
                                .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .bottom)))
                        }
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
        if index < activeIndex { return WeektableTheme.brand }
        if index == activeIndex { return WeektableTheme.terracotta }
        return WeektableTheme.secondaryInk.opacity(0.55)
    }

    private func stageTitleColor(for index: Int) -> Color {
        index <= activeIndex ? WeektableTheme.ink : WeektableTheme.secondaryInk.opacity(0.72)
    }

    @ViewBuilder
    private func generationFacts(_ metadata: GenerationMetadata) -> some View {
        let facts = generationFactValues(metadata)
        if !facts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Week details")
                ForEach(facts, id: \.self) { fact in
                    Label(fact, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(WeektableTheme.brand)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .coveCard()
            .accessibilityElement(children: .combine)
        }
    }

    private func generationFactValues(_ metadata: GenerationMetadata) -> [String] {
        var facts: [String] = []
        if let count = metadata.ingredientCount {
            facts.append("\(count) ingredients combined")
        }
        if let count = metadata.productsMatched {
            facts.append("\(count) products matched")
        }
        if let count = metadata.reusedIngredientCount, count > 0 {
            facts.append("\(count) ingredients reused across dinners")
        }
        if let cents = metadata.underBudgetCents, cents > 0 {
            facts.append("\(cents.currency) under budget")
        }
        return facts
    }
}
