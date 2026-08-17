import SwiftUI

struct WelcomeView: View {
    @Bindable var appModel: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                WeektableFoodImage(alignment: .center)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .ignoresSafeArea()
                    .overlay {
                        LinearGradient(
                            colors: [.black.opacity(0.04), .black.opacity(0.2), .black.opacity(0.94)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()
                    }

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Spacer(minLength: dynamicTypeSize.isAccessibilitySize ? 120 : max(150, proxy.size.height * 0.32))
                        welcomeContent
                    }
                    .frame(minHeight: proxy.size.height, alignment: .bottom)
                    .padding(.horizontal, WeektableTheme.pagePadding)
                    .padding(.bottom, 16)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .scrollBounceBehavior(.basedOnSize)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }

    private var welcomeContent: some View {
        VStack(alignment: .leading, spacing: 16) {
                Label("COVE", systemImage: "fork.knife")
                    .font(.caption.weight(.black))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.9))

                Text("Your week, planned.")
                    .font(dynamicTypeSize.isAccessibilitySize ? .title.bold() : .system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)

                Text("Tell us where you shop, what you want to spend, and how you like to eat. We’ll handle the week.")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 18) {
                    Label("About 3 min", systemImage: "clock")
                    Label("No account", systemImage: "person.crop.circle.badge.checkmark")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.82))

                Button("Plan my first week") { appModel.showPlanner() }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityHint("Starts the four-step dinner planner")
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
