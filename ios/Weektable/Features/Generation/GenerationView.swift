import SwiftUI

struct GenerationView: View {
    @Bindable var appModel: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 28) {
                Spacer(minLength: 30)

                ZStack {
                    Circle().fill(WeektableTheme.brand.opacity(0.13)).frame(width: 104, height: 104)
                    Image(systemName: "wand.and.stars.inverse")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(WeektableTheme.brand)
                        .symbolEffect(.pulse, value: reduceMotion ? GenerationStage.planning : appModel.generationStage)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Building your week")
                    Text(appModel.generationError == nil ? appModel.generationStage.rawValue : "Your answers are safe")
                        .font(.largeTitle.bold())
                        .contentTransition(.numericText())
                        .accessibilityAddTraits(.isHeader)
                    Text(appModel.generationError ?? "We are matching meals, complete packages, and your budget.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if appModel.generationError == nil {
                    ProgressView(value: appModel.generationProgress)
                        .tint(WeektableTheme.brand)
                        .scaleEffect(x: 1, y: 1.5)
                        .accessibilityLabel("Plan generation progress")
                        .accessibilityValue(appModel.generationProgress.formatted(.percent))

                    VStack(spacing: 0) {
                        ForEach(Array(GenerationStage.allCases.enumerated()), id: \.element) { index, stage in
                            HStack(spacing: 14) {
                                Image(systemName: statusSymbol(for: index))
                                    .foregroundStyle(statusColor(for: index))
                                    .frame(width: 24)
                                Text(stage.rawValue)
                                    .font(.subheadline.weight(index == activeIndex ? .semibold : .regular))
                                    .foregroundStyle(index <= activeIndex ? .primary : .secondary)
                                Spacer()
                            }
                            .frame(minHeight: 48)
                            if index != GenerationStage.allCases.count - 1 { Divider() }
                        }
                    }
                    .padding(.horizontal, 16)
                    .background(WeektableTheme.raised, in: RoundedRectangle(cornerRadius: WeektableTheme.cardRadius))
                } else {
                    Button("Try again") { appModel.retryGeneration() }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Review my answers") { appModel.cancelGeneration() }
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }

                Label("Estimated complete-package prices come from the grocery catalog, never from the model. Check current shelf prices and labels.", systemImage: "checkmark.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, WeektableTheme.pagePadding)
            .background(WeektableTheme.canvas)
            .navigationBarBackButtonHidden()
            .toolbar {
                if appModel.generationError != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { appModel.cancelGeneration() }
                    }
                }
            }
        }
    }

    private var activeIndex: Int {
        GenerationStage.allCases.firstIndex(of: appModel.generationStage) ?? 0
    }

    private func statusSymbol(for index: Int) -> String {
        if index < activeIndex { "checkmark.circle.fill" }
        else if index == activeIndex { "circle.inset.filled" }
        else { "circle" }
    }

    private func statusColor(for index: Int) -> Color {
        index <= activeIndex ? WeektableTheme.brand : WeektableTheme.secondaryInk
    }
}
