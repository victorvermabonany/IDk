import SwiftUI

struct WelcomeView: View {
    @Bindable var appModel: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack(alignment: .bottom) {
            WeektableFoodImage(alignment: .center)
                .ignoresSafeArea()
                .overlay {
                    LinearGradient(
                        colors: [.black.opacity(0.08), .black.opacity(0.24), .black.opacity(0.88)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }

            VStack(alignment: .leading, spacing: 18) {
                Label("WEEKTABLE", systemImage: "fork.knife")
                    .font(.caption.weight(.black))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.9))

                Text("Dinner, handled.")
                    .font(dynamicTypeSize.isAccessibilitySize ? .largeTitle.bold() : .system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)

                Text("A full week of meals and one grocery list, built around your budget and the way you eat.")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 18) {
                    Label("About 3 min", systemImage: "clock")
                    Label("No account", systemImage: "person.crop.circle.badge.checkmark")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.82))

                Button("Plan my week") { appModel.showPlanner() }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityHint("Starts the four-step dinner planner")
            }
            .padding(.horizontal, WeektableTheme.pagePadding)
            .padding(.bottom, 18)
        }
    }
}

struct WeektableFoodImage: View {
    let alignment: Alignment

    var body: some View {
        Image("weektable-dinners")
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .clipped()
            .accessibilityHidden(true)
    }
}

