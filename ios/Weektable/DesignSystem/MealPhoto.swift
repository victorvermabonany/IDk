import SwiftUI
import UIKit

struct MealPhoto: View {
    let meal: Meal

    var body: some View {
        FocalImage(
            assetName: meal.specificImageAssetName ?? "weektable-dinners",
            focalX: meal.specificImageAssetName == nil ? 0.5 : meal.imageAlignment
        )
        .accessibilityHidden(true)
    }
}

/// Keeps the meal's authored focal point visible at every card and device aspect ratio.
struct FocalImage: View {
    let assetName: String
    var focalX: Double = 0.5

    var body: some View {
        GeometryReader { proxy in
            if let uiImage = UIImage(named: assetName), uiImage.size.width > 0, uiImage.size.height > 0 {
                let scale = max(proxy.size.width / uiImage.size.width, proxy.size.height / uiImage.size.height)
                let renderedWidth = uiImage.size.width * scale
                let overflow = max(0, renderedWidth - proxy.size.width)
                let clampedFocalX = CGFloat(min(1, max(0, focalX)))
                let desiredOffset = (0.5 - clampedFocalX) * renderedWidth
                let horizontalOffset = min(overflow / 2, max(-overflow / 2, desiredOffset))

                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .offset(x: horizontalOffset)
                    .clipped()
            } else {
                Image("weektable-dinners")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
        }
    }
}
