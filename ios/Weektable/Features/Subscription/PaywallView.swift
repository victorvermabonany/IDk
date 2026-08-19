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
                VStack(alignment: .leading, spacing: 22) {
                    hero

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your week, every week.")
                            .font(.coveTitle)
                            .accessibilityAddTraits(.isHeader)
                        Text(feature.message)
                            .font(.body)
                            .foregroundStyle(WeektableTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    benefits
                    products

                    if let statusMessage {
                        Label(statusMessage, systemImage: "info.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(WeektableTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityElement(children: .combine)
                    }

                    Button(isPurchasing ? "Contacting the App Store…" : "Continue with Cove Pro") {
                        Task { await purchaseSelectedProduct() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isPurchasing || selectedProduct == nil)

                    Button(subscriptions.isRestoring ? "Restoring…" : "Restore purchases") {
                        Task { await restore() }
                    }
                    .font(.headline)
                    .foregroundStyle(WeektableTheme.brandDeep)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .disabled(isPurchasing || subscriptions.isRestoring)

                    Text("Payment is charged to your Apple ID. Subscriptions renew automatically unless cancelled in App Store settings before the current period ends.")
                        .font(.footnote)
                        .foregroundStyle(WeektableTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 22)
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
                .frame(height: 230)
                .clipped()
                .accessibilityHidden(true)
            LinearGradient(colors: [.clear, WeektableTheme.ink.opacity(0.78)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 8) {
                CoveStatusPill(text: "COVE PRO", symbol: "sparkles", color: .white)
                Text(feature.title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: WeektableTheme.heroRadius, style: .continuous))
        .shadow(color: WeektableTheme.ink.opacity(0.12), radius: 18, y: 9)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 0) {
            BenefitRow(symbol: "calendar.badge.plus", text: "Unlimited weekly plans", color: WeektableTheme.terracotta)
            Divider().padding(.leading, 48)
            BenefitRow(symbol: "arrow.triangle.2.circlepath", text: "Unlimited swaps with estimated-basket updates", color: WeektableTheme.sky)
            Divider().padding(.leading, 48)
            BenefitRow(symbol: "slider.horizontal.3", text: "Saved preferences and advanced replanning", color: WeektableTheme.sage)
        }
        .padding(.horizontal, 16)
        .coveCard()
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
    let color: Color

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.12), in: Circle())
            Text(text)
                .font(.body.weight(.semibold))
                .foregroundStyle(WeektableTheme.ink)
        }
        .frame(minHeight: 58)
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
                    .foregroundStyle(isSelected ? WeektableTheme.brand : WeektableTheme.secondaryInk)
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.id == SubscriptionProductID.annual ? "Annual" : "Monthly")
                        .font(.headline)
                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(WeektableTheme.secondaryInk)
                        .lineLimit(2)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.headline)
                    .monospacedDigit()
            }
            .padding(16)
            .background(isSelected ? WeektableTheme.selected : WeektableTheme.raised)
            .overlay {
                RoundedRectangle(cornerRadius: WeektableTheme.controlRadius)
                    .stroke(isSelected ? WeektableTheme.brand : WeektableTheme.divider, lineWidth: isSelected ? 1.5 : 0.75)
            }
            .clipShape(RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(product.displayPrice)
    }
}
