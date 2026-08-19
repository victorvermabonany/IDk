import Foundation
import Observation
import StoreKit
import UIKit

enum SubscriptionProductID {
    static let monthly = "com.weektable.pro.monthly"
    static let annual = "com.weektable.pro.annual"
    static let all = [monthly, annual]
}

enum PremiumFeature: String, Identifiable, Codable {
    case general
    case anotherWeek
    case additionalSwap

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "Plan every week with Pro"
        case .anotherWeek: "Plan every week"
        case .additionalSwap: "Keep your week flexible"
        }
    }

    var message: String {
        switch self {
        case .general: "Unlimited weekly planning, meal swaps, and saved preferences in one native subscription."
        case .anotherWeek: "Your first complete week is yours. Pro unlocks unlimited new weeks."
        case .additionalSwap: "Your first swap is included. Pro unlocks unlimited swaps with automatic estimated-basket updates."
        }
    }
}

enum PurchaseOutcome: Equatable {
    case purchased
    case pending
    case cancelled
    case failed(String)
}

struct EntitlementCache: Codable, Equatable {
    var productIDs: Set<String> = []
    var verifiedAt: Date?
}

@MainActor
@Observable
final class SubscriptionService {
    private(set) var products: [Product] = []
    private(set) var verifiedProductIDs: Set<String> = []
    private(set) var isLoadingProducts = false
    private(set) var isRestoring = false
    var message: String?

    private var transactionUpdatesTask: Task<Void, Never>?

    var isPro: Bool { !verifiedProductIDs.isDisjoint(with: SubscriptionProductID.all) }

    init() {
        transactionUpdatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    await refreshEntitlements()
                }
            }
        }
    }

    func prepare() async {
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        guard products.isEmpty, !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            products = try await Product.products(for: SubscriptionProductID.all)
                .sorted { productRank($0.id) < productRank($1.id) }
            if products.isEmpty {
                message = "Subscriptions are temporarily unavailable. You can keep using your current week."
            }
        } catch {
            message = "Subscriptions could not be loaded. Check your connection and try again."
        }
    }

    func purchase(_ product: Product) async -> PurchaseOutcome {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    return .failed("The App Store could not verify this purchase.")
                }
                await transaction.finish()
                await refreshEntitlements()
                guard isPro else { return .failed("The purchase completed, but access is still being verified.") }
                return .purchased
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .failed("The App Store returned an unfamiliar purchase state.")
            }
        } catch {
            return .failed("The purchase could not be completed. Please try again.")
        }
    }

    func restorePurchases() async -> PurchaseOutcome {
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            return isPro ? .purchased : .failed("No active Cove Pro purchase was found for this Apple ID.")
        } catch {
            return .failed("Purchases could not be restored. Check your connection and try again.")
        }
    }

    func refreshEntitlements() async {
        var activeIDs: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil,
                  !transaction.isUpgraded,
                  SubscriptionProductID.all.contains(transaction.productID)
            else { continue }
            activeIDs.insert(transaction.productID)
        }
        verifiedProductIDs = activeIDs
    }

    private func productRank(_ productID: String) -> Int {
        productID == SubscriptionProductID.annual ? 0 : 1
    }
}
