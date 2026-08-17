import SwiftUI

struct MealPhoto: View {
    let meal: Meal

    var body: some View {
        Group {
            if let asset = meal.specificImageAssetName {
                Image(asset)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [WeektableTheme.brand.opacity(0.2), WeektableTheme.warning.opacity(0.28)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: fallbackSymbol)
                        .font(.system(size: 38, weight: .medium))
                        .foregroundStyle(WeektableTheme.brandDeep)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var fallbackSymbol: String {
        let title = meal.title.lowercased()
        if title.contains("pasta") || title.contains("rigatoni") { return "fork.knife" }
        if title.contains("bowl") || title.contains("rice") { return "takeoutbag.and.cup.and.straw.fill" }
        if title.contains("soup") || title.contains("chili") || title.contains("curry") { return "cup.and.saucer.fill" }
        return "leaf.fill"
    }
}
