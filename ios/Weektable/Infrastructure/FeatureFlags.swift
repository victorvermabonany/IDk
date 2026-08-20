import Foundation

enum FeatureFlags {
    /// Pro access and its gates are live. App Store purchasing remains intentionally disabled
    /// until the products and server-side transaction verification are activated.
    static let storeKitPurchasesEnabled = false
}
