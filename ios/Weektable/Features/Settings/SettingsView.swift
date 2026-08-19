import SwiftUI

struct SettingsView: View {
    @Bindable var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    CoveBrandMark()
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Your Cove").font(.headline)
                        Text("Plans and shopping progress are saved on this iPhone")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(WeektableTheme.raised)

            if FeatureFlags.subscriptionsEnabled {
                Section("Cove Pro") {
                    NavigationLink {
                        SubscriptionSettingsView(appModel: appModel)
                    } label: {
                        Label {
                            LabeledContent("Subscription", value: appModel.subscriptions.isPro ? "Pro active" : "Free")
                        } icon: {
                            Image(systemName: "crown.fill").foregroundStyle(WeektableTheme.brand)
                        }
                    }
                }
            }

            Section("Planning defaults") {
                NavigationLink {
                    PlanSettingsView(appModel: appModel)
                } label: {
                    Label("Store, budget and food preferences", systemImage: "slider.horizontal.3")
                }
            }

            Section("About your data") {
                NavigationLink {
                    SettingsTextView(
                        title: "Prices and nutrition",
                        symbol: "info.circle",
                        text: "Cove labels each estimated basket as provider-listed, estimated, or based on development data and records when the prices were observed. Check current shelf prices and package labels. Nutrition values are estimates, not medical advice."
                    )
                } label: {
                    Label("Prices and nutrition", systemImage: "info.circle")
                }

                if let url = AppConfiguration.privacyURL { Link("Privacy", destination: url).accessibilityHint("Opens the Cove privacy page") }
                if let url = AppConfiguration.termsURL { Link("Terms", destination: url).accessibilityHint("Opens the Cove terms page") }
                if let url = AppConfiguration.supportURL { Link("Support", destination: url).accessibilityHint("Opens Cove support") }
            }

            Section {
                LabeledContent("Version", value: appVersion)
            } footer: {
                Text("This internal beta is free. Generated plans use available recipe and catalog metadata; always verify package labels and cross-contact warnings.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(WeektableTheme.canvas)
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }.fontWeight(.semibold)
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}

private struct SubscriptionSettingsView: View {
    @Bindable var appModel: AppModel
    @State private var statusMessage: String?
    @State private var showingPaywall = false

    var body: some View {
        List {
            Section {
                LabeledContent("Current access", value: appModel.subscriptions.isPro ? "Cove Pro" : "Free")
                if !appModel.subscriptions.isPro {
                    Button("View Cove Pro") { showingPaywall = true }
                }
            }
            Section {
                Button(appModel.subscriptions.isRestoring ? "Restoring purchases…" : "Restore purchases") {
                    Task {
                        let result = await appModel.subscriptions.restorePurchases()
                        switch result {
                        case .purchased:
                            statusMessage = "Cove Pro has been restored."
                            Haptics.success()
                        case .failed(let message):
                            statusMessage = message
                            Haptics.warning()
                        case .pending:
                            statusMessage = "The App Store is still processing this purchase."
                        case .cancelled:
                            statusMessage = nil
                        }
                    }
                }
                .disabled(appModel.subscriptions.isRestoring)
            } footer: {
                if let statusMessage { Text(statusMessage) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(WeektableTheme.canvas)
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPaywall) {
            PaywallView(appModel: appModel, feature: .general)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
        }
    }
}

private struct SettingsTextView: View {
    let title: String
    let symbol: String
    let text: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: symbol)
                    .font(.largeTitle)
                    .foregroundStyle(WeektableTheme.brand)
                Text(title).font(.title.bold()).accessibilityAddTraits(.isHeader)
                Text(text)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(WeektableTheme.pagePadding)
        }
        .background(WeektableTheme.canvas)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
