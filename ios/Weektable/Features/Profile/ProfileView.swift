import SwiftUI

struct ProfileView: View {
    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(WeektableTheme.brand)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Your Weektable").font(.headline)
                        Text("Plans are saved on this iPhone").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Preferences") {
                Label("Diet and allergies", systemImage: "checklist")
                Label("Stores and location", systemImage: "mappin.and.ellipse")
                Label("Notifications", systemImage: "bell")
            }

            Section("About") {
                Label("Price and nutrition sources", systemImage: "info.circle")
                Label("Privacy", systemImage: "hand.raised")
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

