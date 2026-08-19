import Foundation
import SwiftUI

struct CoveAssistantView: View {
    @Bindable var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var messages: [CoveMessage]

    init(appModel: AppModel) {
        self.appModel = appModel
        let isScreenshotState = ProcessInfo.processInfo.arguments.contains("-cove-ui-test-assistant")
        _messages = State(initialValue: isScreenshotState ? CoveMessage.screenshotConversation : [
            CoveMessage(role: .cove, text: "Hey! I’m Cove. How can I help with your week?")
        ])
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 13) {
                        ForEach(messages) { message in
                            messageRow(message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, WeektableTheme.pagePadding)
                    .padding(.vertical, 14)
                }
                .background(WeektableTheme.canvas)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) { _, _ in
                    guard let last = messages.last else { return }
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .navigationTitle("Ask Cove")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "chevron.left") { dismiss() }
                        .labelStyle(.iconOnly)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Clear conversation", systemImage: "trash") {
                            messages = [CoveMessage(role: .cove, text: "Fresh start. What can I help with?")]
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { composer }
        }
        .background(WeektableTheme.canvas.ignoresSafeArea())
    }

    private func messageRow(_ message: CoveMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .cove { CoveOtterAvatar(size: 38) }
            if message.role == .user { Spacer(minLength: 50) }

            VStack(alignment: .leading, spacing: 10) {
                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(WeektableTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if let action = message.action {
                    Button(action.title) { perform(action) }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(action.isPrimary ? .white : WeektableTheme.ink)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 42)
                        .background(action.isPrimary ? WeektableTheme.terracotta : WeektableTheme.surface, in: Capsule())
                }
            }
            .padding(13)
            .background(message.role == .cove ? WeektableTheme.raised : WeektableTheme.sage.opacity(0.30))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: message.role == .cove ? WeektableTheme.ink.opacity(0.045) : .clear, radius: 10, y: 5)

            if message.role == .cove { Spacer(minLength: 34) }
        }
        .frame(maxWidth: .infinity)
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Ask Cove anything…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.leading, 16)
                .onSubmit { submit() }

            Button(action: submit) {
                Image(systemName: "arrow.up")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? WeektableTheme.disabled : WeektableTheme.brand, in: Circle())
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Send")
        }
        .padding(8)
        .background(WeektableTheme.raised, in: Capsule())
        .overlay { Capsule().stroke(WeektableTheme.divider.opacity(0.6), lineWidth: 0.75) }
        .shadow(color: WeektableTheme.ink.opacity(0.06), radius: 12, y: 5)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(WeektableTheme.canvas.opacity(0.96))
    }

    private func submit() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        messages.append(CoveMessage(role: .user, text: text))
        messages.append(response(to: text))
        Haptics.lightImpact()
    }

    private func response(to text: String) -> CoveMessage {
        let query = text.lowercased()

        if query.contains("egg") {
            if let item = appModel.plan?.basket.first(where: {
                $0.displayName.lowercased().contains("egg") || $0.productName.lowercased().contains("egg")
            }) {
                if appModel.groceryState.ownedItemIDs.contains(item.id) {
                    appModel.toggleOwned(item.id)
                    return CoveMessage(role: .cove, text: "Got it — I removed eggs from your pantry and added them back to this week’s grocery total.", action: .groceries)
                }
                return CoveMessage(role: .cove, text: "Eggs are already on your grocery list, so your basket is up to date.", action: .groceries)
            }
            return CoveMessage(role: .cove, text: "I don’t see eggs in this week’s plan yet. Add them during your next weekly plan and I’ll track them for you.", action: .planner)
        }

        if query.contains("swap") || query.contains("quicker") || query.contains("wednesday") {
            let meal = query.contains("wednesday")
                ? appModel.plan?.meals.first(where: { $0.day.lowercased().contains("wednesday") })
                : appModel.plan?.meals.first
            if let meal {
                return CoveMessage(role: .cove, text: "Absolutely. I can look for a quicker swap for \(meal.title) and keep the basket recalculation intact.", action: .swap(meal.id))
            }
            return CoveMessage(role: .cove, text: "Let’s build your first week, then I can swap any dinner without losing your budget or grocery calculations.", action: .planner)
        }

        if query.contains("spend less") || query.contains("cheaper") || query.contains("budget") {
            if let plan = appModel.plan {
                return CoveMessage(role: .cove, text: "This week is currently \(appModel.groceryTotalCents.currency) against your \(plan.budgetCents.currency) budget. We can rebuild with a lower target while keeping your preferences.", action: .planner)
            }
            return CoveMessage(role: .cove, text: "Tell me your weekly budget in the planner and I’ll build around it.", action: .planner)
        }

        if query.contains("20 minute") || query.contains("20-minute") || query.contains("quick") {
            if let meal = appModel.plan?.meals.first(where: { $0.totalMinutes <= 20 }) {
                return CoveMessage(role: .cove, text: "\(meal.title) is your quickest option at \(meal.totalMinutes) minutes. I can take you straight to the week.", action: .week)
            }
            return CoveMessage(role: .cove, text: "None of this week’s dinners are under 20 minutes. I can help you swap one for a quicker option.", action: appModel.plan?.meals.first.map { .swap($0.id) })
        }

        return CoveMessage(role: .cove, text: "I can help swap a dinner, update pantry items, find quick meals, or reshape the week around a tighter budget. Try asking about tonight’s meal.")
    }

    private func perform(_ action: CoveAssistantAction) {
        switch action {
        case .swap(let mealID):
            guard let meal = appModel.plan?.meals.first(where: { $0.id == mealID }) else { return }
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { appModel.openSwap(for: meal) }
        case .planner:
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { appModel.planAnotherWeek() }
        case .week:
            dismiss()
            appModel.selectWeek()
        case .groceries:
            dismiss()
            appModel.selectGroceries()
        }
    }
}

private struct CoveMessage: Identifiable {
    enum Role { case cove, user }
    let id = UUID()
    let role: Role
    let text: String
    var action: CoveAssistantAction? = nil

    static let screenshotConversation: [CoveMessage] = [
        CoveMessage(role: .cove, text: "Hey! I’m Cove. How can I help with your week?"),
        CoveMessage(role: .user, text: "Can you make Wednesday dinner quicker?"),
        CoveMessage(
            role: .cove,
            text: "Absolutely — I found a quicker swap that keeps the week on budget.",
            action: .week
        ),
        CoveMessage(role: .user, text: "Yes please!"),
        CoveMessage(role: .cove, text: "Done! I updated your week. Anything else I can help with?")
    ]
}

private enum CoveAssistantAction {
    case swap(String)
    case planner
    case week
    case groceries

    var title: String {
        switch self {
        case .swap: "See swap options"
        case .planner: "Plan a new week"
        case .week: "Open my week"
        case .groceries: "Open groceries"
        }
    }

    var isPrimary: Bool {
        if case .swap = self { return true }
        return false
    }
}
