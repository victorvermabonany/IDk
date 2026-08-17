import StoreKit
import SwiftUI
import UIKit

struct PaywallView: View {
    @Bindable var appModel: AppModel
    let feature: PremiumFeature
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProductID: String?
    @State private var isPurchasing = false
    @State private var statusMessage: String?

    private var subscriptions: SubscriptionService { appModel.subscriptions }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hero
                    benefits
                    products

                    if let statusMessage {
                        Label(statusMessage, systemImage: "info.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityElement(children: .combine)
                    }

                    Button(isPurchasing ? "Contacting the App Store…" : "Continue") {
                        Task { await purchaseSelectedProduct() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isPurchasing || selectedProduct == nil)

                    Button(subscriptions.isRestoring ? "Restoring…" : "Restore purchases") {
                        Task { await restore() }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .disabled(isPurchasing || subscriptions.isRestoring)

                    Text("Payment is charged to your Apple ID. Subscriptions renew automatically unless cancelled in App Store settings before the current period ends.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(WeektableTheme.pagePadding)
            }
            .background(WeektableTheme.canvas)
            .navigationTitle("Cove Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .accessibilityHint("Closes Cove Pro")
                }
            }
            .task {
                if subscriptions.products.isEmpty { await subscriptions.loadProducts() }
                selectedProductID = subscriptions.products.first?.id
            }
        }
        .interactiveDismissDisabled(isPurchasing)
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Image("weektable-dinners")
                .resizable()
                .scaledToFill()
                .frame(height: 210)
                .clipped()
                .accessibilityHidden(true)
            LinearGradient(colors: [.clear, .black.opacity(0.88)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 7) {
                Text(feature.title).font(.title.bold())
                Text(feature.message).font(.subheadline).foregroundStyle(.white.opacity(0.88))
            }
            .foregroundStyle(.white)
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: WeektableTheme.cardRadius, style: .continuous))
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            BenefitRow(symbol: "calendar.badge.plus", text: "Unlimited weekly plans")
            BenefitRow(symbol: "arrow.triangle.2.circlepath", text: "Unlimited swaps with basket repricing")
            BenefitRow(symbol: "slider.horizontal.3", text: "Saved preferences and advanced replanning")
        }
        .padding(18)
        .background(WeektableTheme.raised, in: RoundedRectangle(cornerRadius: WeektableTheme.cardRadius))
    }

    @ViewBuilder
    private var products: some View {
        if subscriptions.isLoadingProducts {
            HStack(spacing: 12) {
                ProgressView()
                Text("Loading App Store options…")
            }
            .frame(maxWidth: .infinity, minHeight: 88)
        } else if subscriptions.products.isEmpty {
            ContentUnavailableView(
                "Subscriptions unavailable",
                systemImage: "wifi.exclamationmark",
                description: Text("Your current week remains available. Try again when you are connected to the App Store.")
            )
        } else {
            VStack(spacing: 10) {
                ForEach(subscriptions.products) { product in
                    ProductChoiceRow(
                        product: product,
                        isSelected: selectedProductID == product.id,
                        action: {
                            selectedProductID = product.id
                            Haptics.selection()
                        }
                    )
                }
            }
        }
    }

    private var selectedProduct: Product? {
        subscriptions.products.first(where: { $0.id == selectedProductID })
    }

    private func purchaseSelectedProduct() async {
        guard let selectedProduct else { return }
        isPurchasing = true
        statusMessage = nil
        let outcome = await subscriptions.purchase(selectedProduct)
        isPurchasing = false
        handle(outcome)
    }

    private func restore() async {
        statusMessage = nil
        handle(await subscriptions.restorePurchases())
    }

    private func handle(_ outcome: PurchaseOutcome) {
        switch outcome {
        case .purchased:
            Haptics.success()
            UIAccessibility.post(notification: .announcement, argument: "Cove Pro is active")
            if feature == .anotherWeek { appModel.startPlannerForAnotherWeek() }
            dismiss()
        case .pending:
            statusMessage = "The purchase is waiting for approval. Pro will unlock automatically when the App Store completes it."
        case .cancelled:
            statusMessage = nil
        case .failed(let message):
            statusMessage = message
            Haptics.warning()
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}

private struct BenefitRow: View {
    let symbol: String
    let text: String
    var body: some View {
        Label(text, systemImage: symbol)
            .font(.body.weight(.medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.primary)
    }
}

private struct ProductChoiceRow: View {
    let product: Product
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? WeektableTheme.brand : .secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.id == SubscriptionProductID.annual ? "Annual" : "Monthly")
                        .font(.headline)
                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.headline)
                    .monospacedDigit()
            }
            .padding(16)
            .background(WeektableTheme.raised)
            .overlay {
                RoundedRectangle(cornerRadius: WeektableTheme.controlRadius)
                    .stroke(isSelected ? WeektableTheme.brand : WeektableTheme.divider, lineWidth: isSelected ? 2 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(product.displayPrice)
    }
}
