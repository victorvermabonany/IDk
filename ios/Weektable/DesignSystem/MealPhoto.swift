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
                        colors: fallbackColors,
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

    private var fallbackColors: [Color] {
        let palettes: [[Color]] = [
            [WeektableTheme.brand.opacity(0.22), .orange.opacity(0.28)],
            [.green.opacity(0.2), .mint.opacity(0.3)],
            [.yellow.opacity(0.22), WeektableTheme.warning.opacity(0.32)],
            [.brown.opacity(0.2), .orange.opacity(0.24)],
        ]
        let index = meal.title.unicodeScalars.reduce(0) { $0 + Int($1.value) } % palettes.count
        return palettes[index]
    }
}
