import SwiftUI

struct PlanSettingsView: View {
    @Bindable var appModel: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Tune next week")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("Your latest answers are saved on this device. Review them before creating another plan.")
                    .foregroundStyle(.secondary)

                VStack(spacing: 0) {
                    SummaryRow(symbol: "mappin.and.ellipse", title: "Store", value: appModel.plan?.store.name ?? "Not selected")
                    Divider().padding(.leading, 48)
                    SummaryRow(symbol: "dollarsign.circle", title: "Budget", value: "\(appModel.plannerDraft.budgetDollars.formatted(.currency(code: "USD")))")
                    Divider().padding(.leading, 48)
                    SummaryRow(symbol: "person.2", title: "Household", value: "\(appModel.plannerDraft.householdSize) people")
                    Divider().padding(.leading, 48)
                    SummaryRow(symbol: "fork.knife", title: "Dinners", value: "\(appModel.plannerDraft.dinnerCount)")
                    Divider().padding(.leading, 48)
                    SummaryRow(symbol: appModel.plannerDraft.nutritionStyle.symbol, title: "Direction", value: appModel.plannerDraft.nutritionStyle.title)
                }
                .padding(.horizontal, 16)
                .background(WeektableTheme.raised, in: RoundedRectangle(cornerRadius: WeektableTheme.cardRadius))

                Button("Plan another week") { appModel.planAnotherWeek() }
                    .buttonStyle(PrimaryButtonStyle())

                Text("A new plan keeps your saved preferences but creates a fresh generation job and grocery state.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(WeektableTheme.pagePadding)
        }
        .background(WeektableTheme.canvas)
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SummaryRow: View {
    let symbol: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).foregroundStyle(WeektableTheme.brand).frame(width: 28)
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }
        .font(.body)
        .frame(minHeight: 54)
        .accessibilityElement(children: .combine)
    }
}

