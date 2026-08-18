import SwiftUI

struct WelcomeView: View {
    @Bindable var appModel: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    CoveBrandMark()
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your week, planned.")
                            .font(dynamicTypeSize.isAccessibilitySize ? .largeTitle.bold() : .coveDisplay)
                            .foregroundStyle(WeektableTheme.ink)
                            .accessibilityAddTraits(.isHeader)

                        Text("Tell Cove where you shop, what you want to spend, and how you like to eat. Cove plans the week around it.")
                            .font(.body)
                            .foregroundStyle(WeektableTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    CoveFoodMosaic(height: mosaicHeight(for: proxy.size.height))

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 16) {
                            welcomeFact("About 3 minutes", symbol: "clock")
                            welcomeFact("No account needed", symbol: "person.crop.circle.badge.checkmark")
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            welcomeFact("About 3 minutes", symbol: "clock")
                            welcomeFact("No account needed", symbol: "person.crop.circle.badge.checkmark")
                        }
                    }
                }
                .padding(.horizontal, WeektableTheme.pagePadding)
                .padding(.bottom, 112)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(WeektableTheme.canvas.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            Button("Plan my first week") { appModel.showPlanner() }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityHint("Starts the four-step dinner planner")
                .padding(.horizontal, WeektableTheme.pagePadding)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
        }
    }

    private func mosaicHeight(for availableHeight: CGFloat) -> CGFloat {
        if dynamicTypeSize.isAccessibilitySize { return 250 }
        return min(340, max(260, availableHeight * 0.39))
    }

    private func welcomeFact(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(WeektableTheme.secondaryInk)
    }
}
