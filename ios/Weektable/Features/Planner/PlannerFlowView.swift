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
                            .padding(.top, 22)
                            .padding(.bottom, 132)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: step) { _, _ in
                        proxy.scrollTo("planner-top", anchor: .top)
                    }
                }
            }
            .background(WeektableTheme.canvas)
            .navigationTitle("Plan your week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if appModel.plan != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark") { appModel.rootFlow = .main }
                            .labelStyle(.iconOnly)
                            .accessibilityHint("Returns to your current week")
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { bottomActions }
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(step.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WeektableTheme.ink)
                Spacer()
                Text("\(step.rawValue + 1) of \(PlannerStep.allCases.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WeektableTheme.secondaryInk)
                    .monospacedDigit()
            }
            CovePlannerProgress(current: step.rawValue, total: PlannerStep.allCases.count)
        }
        .padding(.horizontal, WeektableTheme.pagePadding)
        .padding(.top, 8)
        .padding(.bottom, 13)
        .background(WeektableTheme.canvas)
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
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WeektableTheme.error)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(WeektableTheme.error.opacity(0.09), in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))
                .padding(.top, 16)
                .accessibilityLabel("Error: \(validationMessage)")
        }
    }

    private var bottomActions: some View {
        HStack(spacing: 12) {
            if step != .store {
                Button { moveBack() } label: {
                    Label("Back", systemImage: "chevron.left")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityLabel("Back")
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
        appModel.updateDraft(draft)
        if step == .pantry {
            appModel.beginGeneration()
        } else if let next = PlannerStep(rawValue: step.rawValue + 1) {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.26)) { step = next }
            Haptics.selection()
        }
    }

    private func moveBack() {
        guard let previous = PlannerStep(rawValue: step.rawValue - 1) else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.26)) { step = previous }
        Haptics.selection()
    }
}

private struct PlannerStepHeader: View {
    let eyebrow: String
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionLabel(text: eyebrow)
            Text(title)
                .font(.coveTitle)
                .foregroundStyle(WeektableTheme.ink)
                .accessibilityAddTraits(.isHeader)
            Text(description)
                .font(.body)
                .foregroundStyle(WeektableTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 16)
    }
}

private struct StoreBudgetStep: View {
    @Bindable var appModel: AppModel
    @Binding var draft: PlannerRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PlannerStepHeader(
                eyebrow: "First, the practical part",
                title: "Where do you shop?",
                description: "Cove uses your store and budget to plan complete packages—not imaginary ingredient prices."
            )

            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "Your store")
                HStack(spacing: 10) {
                    Label {
                        TextField("ZIP code", text: $draft.zipCode)
                            .keyboardType(.numberPad)
                            .textContentType(.postalCode)
                            .accessibilityHint("Five digits")
                    } icon: {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(WeektableTheme.brand)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 54)
                    .background(WeektableTheme.surface, in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))

                    Button {
                        Task {
                            await appModel.findStores(postalCode: draft.zipCode)
                            if let first = appModel.availableStores.first { draft.storeID = first.id }
                        }
                    } label: {
                        Image(systemName: "arrow.right")
                            .font(.headline.bold())
                            .frame(width: 54, height: 54)
                    }
                    .foregroundStyle(.white)
                    .background(WeektableTheme.brandDeep, in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))
                    .disabled(draft.zipCode.count != 5 || appModel.storeSearchState == .loading)
                    .accessibilityLabel("Find stores")
                }

                storeResult
            }
            .padding(17)
            .coveCard()

            VStack(alignment: .leading, spacing: 13) {
                SectionLabel(text: "Dinner budget")
                Text("What do you want to spend?")
                    .font(.coveCardTitle)
                CurrencyBudgetField(budgetCents: $draft.budgetCents)
            }
            .padding(17)
            .coveCard()

            Label("Cove plans with estimated complete-package prices. Check current shelf prices and labels.", systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(WeektableTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .task {
            if appModel.availableStores.isEmpty {
                await appModel.findStores(postalCode: draft.zipCode)
                if let first = appModel.availableStores.first { draft.storeID = first.id }
            }
        }
    }

    @ViewBuilder
    private var storeResult: some View {
        if appModel.storeSearchState == .loading {
            HStack(spacing: 12) {
                ProgressView()
                Text("Finding supported stores…")
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        } else if appModel.storeSearchState == .unsupported {
            Label("No supported stores were found for this ZIP code.", systemImage: "mappin.slash")
                .foregroundStyle(WeektableTheme.secondaryInk)
                .frame(minHeight: 56)
        } else if appModel.storeSearchState == .failed {
            VStack(alignment: .leading, spacing: 8) {
                Label(appModel.storeErrorMessage ?? "Stores could not be loaded. Your ZIP code is still saved.", systemImage: "wifi.exclamationmark")
                    .fixedSize(horizontal: false, vertical: true)
                Button("Try again") {
                    Task {
                        await appModel.findStores(postalCode: draft.zipCode)
                        if let first = appModel.availableStores.first { draft.storeID = first.id }
                    }
                }
                .fontWeight(.semibold)
            }
        } else if !appModel.availableStores.isEmpty {
            Picker("Store", selection: $draft.storeID) {
                ForEach(appModel.availableStores, id: \.id) { store in
                    Text("\(store.name) · \(store.address)").tag(store.id)
                }
            }
            .pickerStyle(.menu)
            .tint(WeektableTheme.brandDeep)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .padding(.horizontal, 12)
            .background(WeektableTheme.surface, in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))
        }
    }
}

private struct CurrencyBudgetField: View {
    @Binding var budgetCents: Int
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 4) {
                Text("$")
                    .foregroundStyle(WeektableTheme.secondaryInk)
                TextField("100.00", text: $text)
                    .keyboardType(.decimalPad)
                    .accessibilityLabel("Weekly dinner budget")
                    .onChange(of: text) { _, value in updateBudget(from: value) }
            }
            .font(.system(size: 30, weight: .bold, design: .rounded))
            .padding(.horizontal, 15)
            .frame(minHeight: 64)
            .background(WeektableTheme.surface, in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))

            if !text.isEmpty, parsedCents(text) == nil {
                Text("Enter $20–$500 with up to two decimal places.")
                    .font(.footnote)
                    .foregroundStyle(WeektableTheme.error)
            } else {
                Text("This is your budget for all dinners, not your entire grocery trip.")
                    .font(.footnote)
                    .foregroundStyle(WeektableTheme.secondaryInk)
            }
        }
        .task {
            if text.isEmpty { text = String(format: "%.2f", Double(budgetCents) / 100) }
        }
    }

    private func updateBudget(from value: String) {
        guard let cents = parsedCents(value) else { return }
        budgetCents = cents
    }

    private func parsedCents(_ value: String) -> Int? {
        let cleaned = value.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.range(of: #"^\d{1,3}(?:\.\d{0,2})?$"#, options: .regularExpression) != nil,
              let amount = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        let cents = NSDecimalNumber(decimal: amount * 100).intValue
        return (2_000...50_000).contains(cents) ? cents : nil
    }
}

private struct HouseholdStep: View {
    @Binding var draft: PlannerRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PlannerStepHeader(
                eyebrow: "Set the table",
                title: "Who are we cooking for?",
                description: "Cove scales every recipe and package calculation for the people eating."
            )

            CoveCounter(
                title: "Household",
                symbol: "person.2.fill",
                value: $draft.householdSize,
                range: 1...8,
                suffix: draft.householdSize == 1 ? "person" : "people"
            )

            VStack(alignment: .leading, spacing: 13) {
                SectionLabel(text: "Dinners this week")
                Text("How many nights should Cove cover?")
                    .font(.coveCardTitle)
                HStack(spacing: 8) {
                    ForEach(3...7, id: \.self) { count in
                        Button {
                            draft.dinnerCount = count
                            Haptics.selection()
                        } label: {
                            Text("\(count)")
                                .font(.headline.bold())
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .foregroundStyle(draft.dinnerCount == count ? .white : WeektableTheme.ink)
                                .background(draft.dinnerCount == count ? WeektableTheme.brandDeep : WeektableTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(count) dinners")
                        .accessibilityAddTraits(draft.dinnerCount == count ? .isSelected : [])
                    }
                }
            }
            .padding(17)
            .coveCard()

            Toggle(isOn: $draft.plannedLeftovers) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Plan for leftovers").font(.headline)
                    Text("Add extra servings for easy lunches.")
                        .font(.subheadline)
                        .foregroundStyle(WeektableTheme.secondaryInk)
                }
            }
            .tint(WeektableTheme.brandDeep)
            .padding(17)
            .coveCard(radius: WeektableTheme.controlRadius, shadow: false)
            .onChange(of: draft.plannedLeftovers) { _, _ in Haptics.selection() }
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
                title: "How do you want to eat?",
                description: "Pick a general direction. Cove still balances the whole basket around your budget."
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 11) {
                ForEach(Array(NutritionStyle.allCases.enumerated()), id: \.element) { index, option in
                    SelectionCard(
                        title: option.title,
                        subtitle: option.subtitle,
                        symbol: option.symbol,
                        isSelected: draft.nutritionStyle == option,
                        accent: WeektableTheme.preferenceAccent(at: index)
                    ) {
                        draft.nutritionStyle = option
                        Haptics.selection()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "Time in the kitchen")
                HStack(spacing: 8) {
                    ForEach([20, 30, 40, 60], id: \.self) { minutes in
                        Button {
                            draft.maxCookingMinutes = minutes
                            Haptics.selection()
                        } label: {
                            Text("\(minutes)m")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity, minHeight: 46)
                                .foregroundStyle(draft.maxCookingMinutes == minutes ? .white : WeektableTheme.ink)
                                .background(draft.maxCookingMinutes == minutes ? WeektableTheme.brandDeep : WeektableTheme.surface, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(draft.maxCookingMinutes == minutes ? .isSelected : [])
                    }
                }
            }
            .padding(17)
            .coveCard(shadow: false)

            DisclosureGroup(isExpanded: $restrictionsExpanded) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Allergies")
                        .font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 9)], spacing: 9) {
                        ForEach(allergyOptions, id: \.self) { allergy in
                            CoveChoiceChip(
                                title: allergy.capitalized,
                                symbol: "exclamationmark.shield",
                                isSelected: draft.allergies.contains(allergy),
                                accent: WeektableTheme.warning,
                                isConstraint: true
                            ) {
                                toggle(allergy, in: &draft.allergies)
                            }
                        }
                    }

                    Label("Allergies are hard constraints. Always verify package labels and cross-contact warnings.", systemImage: "checkmark.shield")
                        .font(.footnote)
                        .foregroundStyle(WeektableTheme.secondaryInk)

                    Text("Dietary restrictions")
                        .font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 9)], spacing: 9) {
                        ForEach(dietaryOptions, id: \.self) { restriction in
                            CoveChoiceChip(
                                title: restriction.capitalized,
                                isSelected: draft.dietaryRestrictions.contains(restriction)
                            ) {
                                toggle(restriction, in: &draft.dietaryRestrictions)
                            }
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
                .padding(.top, 18)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.title3)
                        .foregroundStyle(WeektableTheme.warning)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Anything we should avoid?").font(.headline)
                        Text(draft.allergies.isEmpty ? "Allergies, restrictions and dislikes" : "\(draft.allergies.count) allergies selected")
                            .font(.subheadline)
                            .foregroundStyle(WeektableTheme.secondaryInk)
                    }
                }
            }
            .tint(WeektableTheme.brand)
            .padding(17)
            .coveCard()

            DisclosureGroup {
                VStack(alignment: .leading, spacing: 16) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 9)], spacing: 9) {
                        ForEach(Array(cuisineOptions.enumerated()), id: \.element) { index, cuisine in
                            CoveChoiceChip(
                                title: cuisine,
                                isSelected: draft.preferredCuisines.contains(cuisine),
                                accent: WeektableTheme.preferenceAccent(at: index + 2)
                            ) {
                                toggle(cuisine, in: &draft.preferredCuisines)
                            }
                        }
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
                .padding(.top, 16)
            } label: {
                Label("Cuisines and notes", systemImage: "sparkles")
                    .font(.headline)
            }
            .tint(WeektableTheme.brand)
            .padding(17)
            .coveCard(shadow: false)
        }
    }

    private func toggle(_ value: String, in set: inout Set<String>) {
        if set.contains(value) { set.remove(value) }
        else { set.insert(value) }
        Haptics.selection()
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
                description: "Cove keeps these ingredients in recipes and removes them from your grocery subtotal."
            )

            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "Common staples")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 9)], spacing: 9) {
                    ForEach(Array(suggestions.enumerated()), id: \.element) { index, item in
                        CoveChoiceChip(
                            title: item.capitalized,
                            isSelected: draft.pantryItems.contains(item),
                            accent: WeektableTheme.preferenceAccent(at: index)
                        ) {
                            togglePantryItem(item)
                        }
                    }
                }
            }
            .padding(17)
            .coveCard()

            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Add something else")
                HStack(spacing: 10) {
                    TextField("Garlic powder", text: $newItem)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                        .onSubmit(addPantryItem)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 52)
                        .background(WeektableTheme.surface, in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))
                    Button("Add", action: addPantryItem)
                        .fontWeight(.bold)
                        .frame(minWidth: 58, minHeight: 52)
                        .foregroundStyle(.white)
                        .background(WeektableTheme.brandDeep, in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))
                        .disabled(newItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Text("Optional. Cove excludes recognized pantry items from the grocery subtotal.")
                    .font(.footnote)
                    .foregroundStyle(WeektableTheme.secondaryInk)
            }

            if !draft.pantryItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Already have")
                    ForEach(draft.pantryItems.sorted(), id: \.self) { item in
                        HStack {
                            Label(item.capitalized, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(WeektableTheme.success)
                            Spacer()
                            Button("Remove \(item)", systemImage: "xmark") {
                                draft.pantryItems.remove(item)
                                Haptics.selection()
                            }
                            .labelStyle(.iconOnly)
                            .frame(width: 44, height: 44)
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(17)
                .coveCard(fill: WeektableTheme.sage.opacity(0.10), shadow: false)
            }
        }
    }

    private func togglePantryItem(_ item: String) {
        if draft.pantryItems.contains(item) { draft.pantryItems.remove(item) }
        else { draft.pantryItems.insert(item) }
        Haptics.selection()
    }

    private func addPantryItem() {
        let cleaned = newItem.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty else { return }
        draft.pantryItems.insert(cleaned)
        newItem = ""
        Haptics.selection()
    }
}
