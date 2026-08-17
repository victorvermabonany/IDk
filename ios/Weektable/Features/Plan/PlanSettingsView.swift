import SwiftUI

private enum PlanEditTarget: String, Identifiable {
    case storeBudget, household, food, pantry
    var id: String { rawValue }

    var title: String {
        switch self {
        case .storeBudget: "Store & budget"
        case .household: "Household"
        case .food: "Food preferences"
        case .pantry: "Pantry"
        }
    }
}

struct PlanSettingsView: View {
    @Bindable var appModel: AppModel
    @State private var editing: PlanEditTarget?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Tune next week")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("Change one setting now, or create a completely fresh plan when you are ready.")
                    .foregroundStyle(.secondary)

                VStack(spacing: 0) {
                    editRow(.storeBudget, symbol: "mappin.and.ellipse", title: "Store", value: appModel.plan?.store.name ?? "Not selected")
                    Divider().padding(.leading, 48)
                    editRow(.storeBudget, symbol: "dollarsign.circle", title: "Budget", value: appModel.plannerDraft.budgetDollars.formatted(.currency(code: "USD")))
                    Divider().padding(.leading, 48)
                    editRow(.household, symbol: "person.2", title: "Household", value: "\(appModel.plannerDraft.householdSize) people")
                    Divider().padding(.leading, 48)
                    editRow(.household, symbol: "fork.knife", title: "Dinners", value: "\(appModel.plannerDraft.dinnerCount)")
                    Divider().padding(.leading, 48)
                    editRow(.food, symbol: appModel.plannerDraft.nutritionStyle.symbol, title: "Dinner style", value: appModel.plannerDraft.nutritionStyle.title)
                    Divider().padding(.leading, 48)
                    editRow(.food, symbol: "timer", title: "Cooking time", value: "Up to \(appModel.plannerDraft.maxCookingMinutes) min")
                    Divider().padding(.leading, 48)
                    editRow(.food, symbol: "exclamationmark.shield", title: "Allergies", value: appModel.plannerDraft.allergies.isEmpty ? "None" : "\(appModel.plannerDraft.allergies.count) selected")
                    Divider().padding(.leading, 48)
                    editRow(.pantry, symbol: "cabinet", title: "Pantry", value: "\(appModel.plannerDraft.pantryItems.count) staples")
                }
                .padding(.horizontal, 16)
                .background(WeektableTheme.raised, in: RoundedRectangle(cornerRadius: WeektableTheme.cardRadius))

                Label("These defaults are used the next time you start a week from the Week screen. Your current meals are not changed.", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(WeektableTheme.pagePadding)
        }
        .background(WeektableTheme.canvas)
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { target in
            PlanEditSheet(appModel: appModel, target: target)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func editRow(_ target: PlanEditTarget, symbol: String, title: String, value: String) -> some View {
        Button { editing = target } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol).foregroundStyle(WeektableTheme.brand).frame(width: 28)
                Text(title).foregroundStyle(.primary)
                Spacer()
                Text(value).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
            }
            .font(.body)
            .frame(minHeight: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens \(target.title.lowercased()) settings")
    }
}

private struct PlanEditSheet: View {
    @Bindable var appModel: AppModel
    let target: PlanEditTarget
    @Environment(\.dismiss) private var dismiss
    @State private var draft: PlannerRequest
    @State private var newPantryItem = ""

    init(appModel: AppModel, target: PlanEditTarget) {
        self.appModel = appModel
        self.target = target
        _draft = State(initialValue: appModel.plannerDraft)
    }

    var body: some View {
        NavigationStack {
            Form {
                switch target {
                case .storeBudget:
                    Section("Store") {
                        TextField("ZIP code", text: $draft.zipCode).keyboardType(.numberPad).textContentType(.postalCode)
                        Button("Find stores") { Task { await appModel.findStores(postalCode: draft.zipCode) } }
                            .disabled(draft.zipCode.count != 5)
                        if !storeChoices.isEmpty {
                            Picker("Store", selection: $draft.storeID) {
                                ForEach(storeChoices, id: \.id) { Text($0.name).tag($0.id) }
                            }
                        }
                    }
                    Section("Weekly dinner budget") {
                        TextField("Budget", value: $draft.budgetDollars, format: .number).keyboardType(.numberPad)
                    }
                case .household:
                    Section("People and dinners") {
                        Stepper("\(draft.householdSize) people", value: $draft.householdSize, in: 1...8)
                        Picker("Dinners", selection: $draft.dinnerCount) { ForEach(3...7, id: \.self) { Text("\($0)").tag($0) } }
                        Toggle("Plan for leftovers", isOn: $draft.plannedLeftovers)
                    }
                case .food:
                    Section("Dinner style") {
                        Picker("Direction", selection: $draft.nutritionStyle) { ForEach(NutritionStyle.allCases) { Text($0.title).tag($0) } }
                        Picker("Maximum time", selection: $draft.maxCookingMinutes) { ForEach([20, 30, 40, 60], id: \.self) { Text("\($0) minutes").tag($0) } }
                    }
                    Section("Restrictions") {
                        TextField("Foods to avoid", text: $draft.dislikedFoods, axis: .vertical)
                        ForEach(["milk", "eggs", "peanuts", "tree nuts", "soy", "wheat", "fish", "shellfish"], id: \.self) { allergy in
                            Toggle(allergy.capitalized, isOn: Binding(get: { draft.allergies.contains(allergy) }, set: { selected in
                                if selected { draft.allergies.insert(allergy) } else { draft.allergies.remove(allergy) }
                            }))
                        }
                        Text("Allergies remain hard constraints in every generated plan.").font(.caption).foregroundStyle(.secondary)
                    }
                case .pantry:
                    Section("Pantry staples") {
                        ForEach(["olive oil", "salt", "black pepper", "rice", "eggs", "soy sauce"], id: \.self) { item in
                            Toggle(item.capitalized, isOn: Binding(get: { draft.pantryItems.contains(item) }, set: { selected in
                                if selected { draft.pantryItems.insert(item) } else { draft.pantryItems.remove(item) }
                            }))
                        }
                    }
                    Section("Add another") {
                        TextField("Garlic powder", text: $newPantryItem)
                            .textInputAutocapitalization(.never)
                            .submitLabel(.done)
                            .onSubmit(addPantryItem)
                        Button("Add to pantry", action: addPantryItem)
                            .disabled(newPantryItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .navigationTitle(target.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        appModel.updateDraft(draft)
                        Haptics.success()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .task {
            if target == .storeBudget, draft.zipCode.count == 5 {
                await appModel.findStores(postalCode: draft.zipCode)
            }
        }
    }

    private var storeChoices: [Store] {
        if !appModel.availableStores.isEmpty { return appModel.availableStores }
        return appModel.plan.map { [$0.store] } ?? []
    }

    private func addPantryItem() {
        let item = newPantryItem.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !item.isEmpty else { return }
        draft.pantryItems.insert(item)
        newPantryItem = ""
        Haptics.selection()
    }
}
