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
    case savedPreferences
    case planHistory

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "Plan every week with Pro"
        case .anotherWeek: "Plan every week"
        case .additionalSwap: "Keep your week flexible"
        case .savedPreferences: "Keep your preferences ready"
        case .planHistory: "Revisit every week"
        }
    }

    var message: String {
        switch self {
        case .general: "Unlimited weekly planning, meal swaps, saved preferences, and plan history in one native subscription."
        case .anotherWeek: "Your first complete week is yours. Pro unlocks unlimited new weeks."
        case .additionalSwap: "Your first swap is included. Pro unlocks unlimited swaps with automatic estimated-basket updates."
        case .savedPreferences: "Pro saves your planning defaults for every new week without changing plans you already made."
        case .planHistory: "Pro keeps previous week snapshots ready to open without regenerating them."
        }
    }
}

enum PurchaseOutcome: Equatable {
    case purchased
    case pending
    case cancelled
    case failed(String)
}

enum ProEntitlementStatus: String, Codable, Equatable {
    case free
    case pro
    case expired
    case revoked
}

struct EntitlementCache: Codable, Equatable {
    var status: ProEntitlementStatus = .free
    var productIDs: Set<String> = []
    var verifiedAt: Date?
    var expirationDate: Date?

    var isPro: Bool {
        guard status == .pro else { return false }
        return expirationDate.map { $0 > .now } ?? true
    }

    private enum CodingKeys: String, CodingKey {
        case status, productIDs, verifiedAt, expirationDate
    }

    init(
        status: ProEntitlementStatus = .free,
        productIDs: Set<String> = [],
        verifiedAt: Date? = nil,
        expirationDate: Date? = nil
    ) {
        self.status = status
        self.productIDs = productIDs
        self.verifiedAt = verifiedAt
        self.expirationDate = expirationDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        productIDs = try container.decodeIfPresent(Set<String>.self, forKey: .productIDs) ?? []
        verifiedAt = try container.decodeIfPresent(Date.self, forKey: .verifiedAt)
        expirationDate = try container.decodeIfPresent(Date.self, forKey: .expirationDate)
        status = try container.decodeIfPresent(ProEntitlementStatus.self, forKey: .status)
            ?? (productIDs.isDisjoint(with: SubscriptionProductID.all) ? .free : .pro)
    }
}

enum ProCapability {
    case generateWeek
    case swapMeal
    case savedPreferences
    case planHistory
    case nutritionSummary
}

struct ProAccessPolicy {
    private(set) var entitlement: EntitlementCache

    init(entitlement: EntitlementCache = EntitlementCache()) {
        self.entitlement = entitlement
    }

    var isPro: Bool { entitlement.isPro }

    mutating func update(_ entitlement: EntitlementCache) {
        self.entitlement = entitlement
    }

    func allows(_ capability: ProCapability, completedPlans: Int, completedSwaps: Int) -> Bool {
        if isPro { return true }
        switch capability {
        case .generateWeek: completedPlans == 0
        case .swapMeal: completedSwaps == 0
        case .savedPreferences, .planHistory, .nutritionSummary: false
        }
    }
}

@MainActor
@Observable
final class SubscriptionService {
    private(set) var products: [Product] = []
    private(set) var verifiedProductIDs: Set<String> = []
    private(set) var isLoadingProducts = false
    private(set) var isRestoring = false
    private(set) var entitlement = EntitlementCache()
    var message: String?

    private var transactionUpdatesTask: Task<Void, Never>?

    var isPro: Bool { entitlement.isPro }

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
        guard FeatureFlags.storeKitPurchasesEnabled else { return }
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        guard FeatureFlags.storeKitPurchasesEnabled else { return }
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
        guard FeatureFlags.storeKitPurchasesEnabled else {
            return .failed("Cove Pro purchases are not enabled in this build yet.")
        }
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
        guard FeatureFlags.storeKitPurchasesEnabled else {
            return .failed("Cove Pro purchases are not enabled in this build yet.")
        }
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
        var latestExpiration: Date?
        var revoked = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  SubscriptionProductID.all.contains(transaction.productID) else { continue }
            if transaction.revocationDate != nil { revoked = true; continue }
            guard !transaction.isUpgraded else { continue }
            if let expiration = transaction.expirationDate, expiration <= .now { continue }
            activeIDs.insert(transaction.productID)
            if let expiration = transaction.expirationDate {
                latestExpiration = max(latestExpiration ?? expiration, expiration)
            }
        }
        verifiedProductIDs = activeIDs
        let status: ProEntitlementStatus = !activeIDs.isEmpty ? .pro : revoked ? .revoked : entitlement.status == .pro ? .expired : .free
        entitlement = EntitlementCache(status: status, productIDs: activeIDs, verifiedAt: .now, expirationDate: latestExpiration)
    }

    private func productRank(_ productID: String) -> Int {
        productID == SubscriptionProductID.annual ? 0 : 1
    }
}
