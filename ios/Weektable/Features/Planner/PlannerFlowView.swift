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
                ScrollView {
                    currentStep
                        .padding(.horizontal, WeektableTheme.pagePadding)
                        .padding(.top, 22)
                        .padding(.bottom, 120)
                }
                .scrollDismissesKeyboard(.interactively)
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
                Spacer()
                Text(step.title)
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
        case .store: StoreBudgetStep(draft: $draft)
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
                .font(.largeTitle.bold())
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
                TextField("ZIP code", text: $draft.zipCode)
                    .keyboardType(.numberPad)
                    .textContentType(.postalCode)
                    .padding(14)
                    .background(WeektableTheme.raised, in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))
                    .accessibilityHint("Five digits")
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
                Picker("Store", selection: $draft.storeID) {
                    Text("Kroger · Downtown demo").tag("demo-kroger-45202")
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(WeektableTheme.raised, in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))
                Label("Demo catalog prices are clearly labeled and are not current store quotes.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
    private let allergyOptions = ["milk", "eggs", "peanuts", "tree nuts", "soy", "wheat", "fish", "shellfish"]

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

            SectionLabel(text: "Allergies · hard constraints")
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
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Foods to avoid").font(.headline)
                TextField("Mushrooms, seafood", text: $draft.dislikedFoods, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(14)
                    .background(WeektableTheme.raised, in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))
            }
        }
    }
}

private struct PantryStep: View {
    @Binding var draft: PlannerRequest
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
                Text("Anything else?").font(.headline)
                TextField("Pasta, garlic powder, frozen peas", text: $draft.customPantryItems, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(14)
                    .background(WeektableTheme.raised, in: RoundedRectangle(cornerRadius: WeektableTheme.controlRadius))
                Text("Separate ingredients with commas. This step is optional.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
