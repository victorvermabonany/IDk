import SwiftUI

struct ProfileView: View {
    @Bindable var appModel: AppModel

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(WeektableTheme.brand)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Your Cove").font(.headline)
                        Text("Plans are saved on this iPhone").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Preferences") {
                NavigationLink {
                    ProfileInfoView(title: "Diet and allergies", symbol: "checklist", rows: [
                        ("Dinner style", appModel.plannerDraft.nutritionStyle.title),
                        ("Allergies", appModel.plannerDraft.allergies.isEmpty ? "None selected" : appModel.plannerDraft.allergies.sorted().joined(separator: ", ")),
                        ("Foods to avoid", appModel.plannerDraft.dislikedFoods.isEmpty ? "None" : appModel.plannerDraft.dislikedFoods)
                    ])
                } label: { Label("Diet and allergies", systemImage: "checklist") }

                NavigationLink {
                    ProfileInfoView(title: "Stores and location", symbol: "mappin.and.ellipse", rows: [
                        ("Store", appModel.plan?.store.name ?? "Not selected"),
                        ("ZIP code", appModel.plannerDraft.zipCode),
                        ("Price source", appModel.plan?.priceKind.rawValue.capitalized ?? "Not available")
                    ])
                } label: { Label("Stores and location", systemImage: "mappin.and.ellipse") }

                HStack {
                    Label("Notifications", systemImage: "bell")
                    Spacer()
                    Text("Coming soon").font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("About") {
                NavigationLink {
                    ProfileTextView(title: "Price and nutrition sources", symbol: "info.circle", text: "Cove labels each estimated basket as provider-listed, estimated, or based on development data. Always check current shelf prices and labels. Nutrition values are estimates, not medical advice.")
                } label: { Label("Price and nutrition sources", systemImage: "info.circle") }
                NavigationLink {
                    ProfileTextView(title: "Privacy", symbol: "hand.raised", text: "Your latest planner answers, cached plan, and grocery progress are stored on this iPhone. Cove does not require an account for the core planning flow.")
                } label: { Label("Privacy", systemImage: "hand.raised") }
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0").foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Profile")
    }
}

private struct ProfileInfoView: View {
    let title: String
    let symbol: String
    let rows: [(String, String)]

    var body: some View {
        List {
            Section {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    LabeledContent(row.0, value: row.1)
                }
            } footer: {
                Text("Edit these preferences from the Plan tab before creating your next week.")
            }
        }
        .navigationTitle(title)
        .toolbar(.hidden, for: .tabBar)
    }
}

private struct ProfileTextView: View {
    let title: String
    let symbol: String
    let text: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: symbol).font(.largeTitle).foregroundStyle(WeektableTheme.brand)
                Text(title).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                Text(text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(WeektableTheme.pagePadding)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
