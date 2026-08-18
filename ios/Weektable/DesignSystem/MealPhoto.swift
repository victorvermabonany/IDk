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
                Image("weektable-dinners")
                    .resizable()
                    .scaledToFill()
            }
        }
        .accessibilityHidden(true)
    }
}
