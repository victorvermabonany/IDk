import SwiftUI
import UIKit

private enum PlannerStep: Int, CaseIterable {
    case store
    case household
    case food
    case pantry

    var title: String {
        switch self {
        case .store: "Store & budget"
        case .household: "Household"
        case .food: "Food"
        case .pantry: "Pantry"
        }
    }
}

struct PlannerFlowView: View {
    @Bindable var appModel: AppModel
    @State private var step: PlannerStep = .store
    @State private var draft: PlannerRequest
    @State private var validationMessage: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(appModel: AppModel) {
        self.appModel = appModel
        _draft = State(initialValue: appModel.plannerDraft)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressHeader
                ScrollViewReader { proxy in
                    ScrollView {
                        Color.clear.frame(height: 1).id("planner-top")
                        currentStep
                            .id(step)
                            .padding(.horizontal, WeektableTheme.pagePadding)
                            .padding(.top, 21)
                            .padding(.bottom, 140)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: step) { _, _ in
                        proxy.scrollTo("planner-top", anchor: .top)
                    }
                }
            }
            .background(WeektableTheme.canvas)
            .navigationTitle(step.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { appModel.rootFlow = appModel.plan == nil ? .welcome : .main }
                        .labelStyle(.iconOnly)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                }
            }
            .safeAreaInset(edge: .bottom) { bottomActions }
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Step \(step.rawValue + 1) of \(PlannerStep.allCases.count)")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            ProgressView(value: Double(step.rawValue + 1), total: Double(PlannerStep.allCases.count))
                .tint(WeektableTheme.brand)
                .accessibilityLabel("Planner progress")
                .accessibilityValue("Step \(step.rawValue + 1) of \(PlannerStep.allCases.count)")
        }
        .padding(.horizontal, WeektableTheme.pagePadding)
        .padding(.vertical, 12)
        .background(.bar)
    }

    @ViewBuilder
    private var currentStep: some View {
        switch step {
        case .store: StoreBudgetStep(appModel: appModel, draft: $draft)
        case .household: HouseholdStep(draft: $draft)
        case .food: FoodPreferencesStep(draft: $draft)
        case .pantry: PantryStep(draft: $draft)
        }

        if let validationMessage {
            Label(validationMessage, systemImage: "exclamationmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.red)
                .padding(.top, 16)
                .accessibilityLabel("Error: \(validationMessage)")
        }
    }

    private var bottomActions: some View {
        HStack(spacing: 12) {
            if step != .store {
                Button("Back") { moveBack() }
                    .font(.headline)
                    .frame(minWidth: 82, minHeight: 54)
            }
            Button(step == .pantry ? "Build my week" : "Continue") { advance() }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, WeektableTheme.pagePadding)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private func advance() {
        if step == .store {
            guard draft.zipCode.count == 5, draft.zipCode.allSatisfy(\.isNumber) else {
                validationMessage = "Enter a five-digit ZIP code."
                Haptics.warning()
                return
            }
            guard draft.budgetDollars >= 20 else {
                validationMessage = "The minimum dinner budget is $20."
                Haptics.warning()
                return
            }
            guard appModel.storeSearchState == .loaded,
                  appModel.availableStores.contains(where: { $0.id == draft.storeID }) else {
                validationMessage = "Choose a supported store before continuing."
                Haptics.warning()
                return
            }
        }
        validationMessage = nil
        if step == .pantry {
            let customItems = draft.customPantryItems
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
            draft.pantryItems.formUnion(customItems)
        }
        appModel.updateDraft(draft)
        if step == .pantry {
            appModel.beginGeneration()
        } else if let next = PlannerStep(rawValue: step.rawValue + 1) {
            withAnimation(reduceMotion ? nil : .snappy) { step = next }
            Haptics.selection()
        }
    }

    private func moveBack() {
        guard let previous = PlannerStep(rawValue: step.rawValue - 1) else { return }
        withAnimation(reduceMotion ? nil : .snappy) { step = previous }
        Haptics.selection()
    }
}

private struct PlannerStepHeader: View {
    let eyebrow: String
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: eyebrow)
            Text(title)
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 22)
    }
}

private struct StoreBudgetStep: View {
    @Bindable var appModel: AppModel
    @Binding var draft: PlannerRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PlannerStepHeader(
                eyebrow: "Start with the practical part",
                title: "Where are you shopping?",
                description: "We match complete packages at your selected store and keep the basket inside your dinner budget."
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("ZIP code").font(.headline)
                HStack(spacing: 10) {
                    TextField("ZIP code", text: $draft.zipCode)
                        .keyboardType(.numberPad)
                        .textContentType(.postalCode)
                        .accessibilityHint("Five digits")
                    Button("Find stores") {
                        Task {
                            await appModel.findStores(postalCode: draft.zipCode)
                            if let first = appModel.availableStores.first { draft.storeID = first.id }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(draft.zipCode.count != 5 || appModel.storeSearchState == .loading)
                }
                .padding(14)
                .background(WeektableTheme.raised, in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Weekly dinner budget").font(.headline)
                HStack {
                    Text("$").foregroundStyle(.secondary)
                    TextField("Budget", value: $draft.budgetDollars, format: .number)
                        .keyboardType(.numberPad)
                }
                .font(.title3.weight(.semibold))
                .padding(14)
                .background(WeektableTheme.raised, in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Store").font(.headline)
                if appModel.storeSearchState == .loading {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Finding supported stores…")
                    }
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                } else if appModel.storeSearchState == .unsupported {
                    Label("No supported stores were found for this ZIP code.", systemImage: "mappin.slash")
                        .foregroundStyle(.secondary)
                        .frame(minHeight: 56)
                } else if appModel.storeSearchState == .failed {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Stores could not be loaded. Your ZIP code is still saved.", systemImage: "wifi.exclamationmark")
                        Button("Try again") {
                            Task {
                                await appModel.findStores(postalCode: draft.zipCode)
                                if let first = appModel.availableStores.first { draft.storeID = first.id }
                            }
                        }
                            .fontWeight(.semibold)
                    }
                } else {
                    Picker("Store", selection: $draft.storeID) {
                        ForEach(appModel.availableStores, id: \.id) { store in
                            Text("\(store.name) · \(store.address)").tag(store.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(WeektableTheme.raised, in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))
                }
                Label("Demo catalog prices are clearly labeled and are not current store quotes.", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            if appModel.availableStores.isEmpty {
                await appModel.findStores(postalCode: draft.zipCode)
                if let first = appModel.availableStores.first { draft.storeID = first.id }
            }
        }
    }
}

private struct HouseholdStep: View {
    @Binding var draft: PlannerRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PlannerStepHeader(
                eyebrow: "Set the table",
                title: "How much dinner do you need?",
                description: "We scale every recipe and package calculation for your household."
            )

            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "People eating")
                Stepper(value: $draft.householdSize, in: 1...8) {
                    HStack {
                        Label("Household", systemImage: "person.2.fill")
                        Spacer()
                        Text("\(draft.householdSize)").font(.title2.bold()).monospacedDigit()
                    }
                }
                .padding(16)
                .background(WeektableTheme.raised, in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))
                .onChange(of: draft.householdSize) { _, _ in Haptics.selection() }
            }

            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Dinners this week")
                Picker("Dinners this week", selection: $draft.dinnerCount) {
                    ForEach(3...7, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: draft.dinnerCount) { _, _ in Haptics.selection() }
            }

            Toggle(isOn: $draft.plannedLeftovers) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Plan for leftovers").font(.headline)
                    Text("Useful for lunches; dinner servings never shrink.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .tint(WeektableTheme.brand)
            .padding(16)
            .background(WeektableTheme.raised, in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))
        }
    }
}

private struct FoodPreferencesStep: View {
    @Binding var draft: PlannerRequest
    @State private var restrictionsExpanded = false
    private let allergyOptions = ["milk", "eggs", "peanuts", "tree nuts", "soy", "wheat", "fish", "shellfish"]
    private let dietaryOptions = ["gluten-free", "dairy-free", "vegan"]
    private let cuisineOptions = ["Mexican", "Italian", "Mediterranean", "Asian-inspired"]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PlannerStepHeader(
                eyebrow: "Make it yours",
                title: "How should dinner feel?",
                description: "Choose one direction. Allergies remain hard constraints no matter what you select."
            )

            SectionLabel(text: "General direction")
            ForEach(NutritionStyle.allCases) { option in
                SelectionCard(
                    title: option.title,
                    subtitle: option.subtitle,
                    symbol: option.symbol,
                    isSelected: draft.nutritionStyle == option
                ) {
                    draft.nutritionStyle = option
                    Haptics.selection()
                }
            }

            SectionLabel(text: "Maximum cooking time")
            Picker("Maximum cooking time", selection: $draft.maxCookingMinutes) {
                ForEach([20, 30, 40, 60], id: \.self) { Text("\($0)m").tag($0) }
            }
            .pickerStyle(.segmented)

            DisclosureGroup(isExpanded: $restrictionsExpanded) {
                VStack(alignment: .leading, spacing: 16) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                        ForEach(allergyOptions, id: \.self) { allergy in
                            Button {
                                if draft.allergies.contains(allergy) { draft.allergies.remove(allergy) }
                                else { draft.allergies.insert(allergy) }
                                Haptics.selection()
                            } label: {
                                Label(allergy.capitalized, systemImage: draft.allergies.contains(allergy) ? "checkmark" : "plus")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.bordered)
                            .tint(draft.allergies.contains(allergy) ? WeektableTheme.brand : .secondary)
                            .accessibilityAddTraits(draft.allergies.contains(allergy) ? .isSelected : [])
                        }
                    }

                    Label("Always verify packaged-food labels and cross-contact warnings.", systemImage: "exclamationmark.shield")
                        .font(.footnote)
                        .foregroundStyle(.primary.opacity(0.78))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dietary restrictions").font(.headline)
                        ForEach(dietaryOptions, id: \.self) { restriction in
                            Toggle(restriction.capitalized, isOn: setBinding(restriction, in: $draft.dietaryRestrictions))
                                .frame(minHeight: 44)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Foods to avoid").font(.headline)
                        TextField("Mushrooms, seafood", text: $draft.dislikedFoods, axis: .vertical)
                            .lineLimit(2...4)
                            .padding(14)
                            .background(WeektableTheme.surface, in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))
                    }
                }
                .padding(.top, 16)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Restrictions").font(.headline)
                        Text(draft.allergies.isEmpty ? "Allergies and foods to avoid" : "\(draft.allergies.count) allergies selected")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "exclamationmark.shield")
                        .foregroundStyle(WeektableTheme.brand)
                }
            }
            .tint(WeektableTheme.brand)
            .padding(16)
            .background(WeektableTheme.raised, in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))

            DisclosureGroup {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Cuisines you enjoy").font(.headline)
                    ForEach(cuisineOptions, id: \.self) { cuisine in
                        Toggle(cuisine, isOn: setBinding(cuisine, in: $draft.preferredCuisines))
                            .frame(minHeight: 44)
                    }
                    TextField(
                        "Optional notes for this week",
                        text: Binding(
                            get: { draft.customInstruction ?? "" },
                            set: { draft.customInstruction = $0.isEmpty ? nil : $0 }
                        ),
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                    .padding(14)
                    .background(WeektableTheme.surface, in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))
                }
                .padding(.top, 14)
            } label: {
                Label("More preferences", systemImage: "slider.horizontal.3")
                    .font(.headline)
            }
            .tint(WeektableTheme.brand)
            .padding(16)
            .background(WeektableTheme.raised, in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))
        }
    }

    private func setBinding(_ value: String, in set: Binding<Set<String>>) -> Binding<Bool> {
        Binding(
            get: { set.wrappedValue.contains(value) },
            set: { selected in
                if selected { set.wrappedValue.insert(value) }
                else { set.wrappedValue.remove(value) }
                Haptics.selection()
            }
        )
    }
}

private struct PantryStep: View {
    @Binding var draft: PlannerRequest
    @State private var newItem = ""
    private let suggestions = ["olive oil", "salt", "black pepper", "rice", "eggs", "soy sauce"]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PlannerStepHeader(
                eyebrow: "Use what you have",
                title: "What is already in your kitchen?",
                description: "These ingredients stay in recipes but come out of your grocery subtotal."
            )

            SectionLabel(text: "Common staples")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 10)], spacing: 10) {
                ForEach(suggestions, id: \.self) { item in
                    Button {
                        if draft.pantryItems.contains(item) { draft.pantryItems.remove(item) }
                        else { draft.pantryItems.insert(item) }
                        Haptics.selection()
                    } label: {
                        Label(item.capitalized, systemImage: draft.pantryItems.contains(item) ? "checkmark" : "plus")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 46)
                    }
                    .buttonStyle(.bordered)
                    .tint(draft.pantryItems.contains(item) ? WeektableTheme.brand : .secondary)
                    .accessibilityAddTraits(draft.pantryItems.contains(item) ? .isSelected : [])
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Add another ingredient").font(.headline)
                HStack(spacing: 10) {
                    TextField("Garlic powder", text: $newItem)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                        .onSubmit(addPantryItem)
                    Button("Add", action: addPantryItem)
                        .fontWeight(.semibold)
                        .disabled(newItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(14)
                .background(WeektableTheme.raised, in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))
                Text("Optional. Added items are excluded from the grocery subtotal when the server recognizes them.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if !draft.pantryItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Selected pantry items")
                    ForEach(draft.pantryItems.sorted(), id: \.self) { item in
                        HStack {
                            Text(item.capitalized)
                            Spacer()
                            Button("Remove \(item)", systemImage: "xmark.circle.fill") {
                                draft.pantryItems.remove(item)
                                Haptics.selection()
                            }
                            .labelStyle(.iconOnly)
                            .frame(width: 44, height: 44)
                        }
                    }
                }
                .padding(16)
                .background(WeektableTheme.raised, in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))
            }
        }
    }

    private func addPantryItem() {
        let cleaned = newItem.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty else { return }
        draft.pantryItems.insert(cleaned)
        newItem = ""
        Haptics.selection()
    }
}
