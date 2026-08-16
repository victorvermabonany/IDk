import SwiftUI
import UIKit

enum WeektableTheme {
    static let brand = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.46, blue: 0.31, alpha: 1)
            : UIColor(red: 0.93, green: 0.25, blue: 0.12, alpha: 1)
    })

    static let brandDeep = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.95, green: 0.36, blue: 0.21, alpha: 1)
            : UIColor(red: 0.69, green: 0.16, blue: 0.07, alpha: 1)
    })

    static let canvas = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.055, green: 0.06, blue: 0.06, alpha: 1)
            : UIColor(red: 0.975, green: 0.972, blue: 0.96, alpha: 1)
    })

    static let surface = Color(uiColor: .secondarySystemBackground)
    static let raised = Color(uiColor: .systemBackground)
    static let ink = Color(uiColor: .label)
    static let secondaryInk = Color(uiColor: .secondaryLabel)
    static let success = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.40, green: 0.82, blue: 0.63, alpha: 1)
            : UIColor(red: 0.08, green: 0.42, blue: 0.29, alpha: 1)
    })
    static let warning = Color(uiColor: .systemYellow)
    static let divider = Color(uiColor: .separator)
    static let cardRadius: CGFloat = 22
    static let controlRadius: CGFloat = 14
    static let pagePadding: CGFloat = 20
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(.white)
            .background(isEnabled ? WeektableTheme.brandDeep : Color(uiColor: .tertiaryLabel))
            .clipShape(RoundedRectangle(cornerRadius: WeektableTheme.controlRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

struct SelectionCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? WeektableTheme.brand : WeektableTheme.secondaryInk)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? WeektableTheme.brand : WeektableTheme.secondaryInk)
            }
            .padding(16)
            .background(WeektableTheme.raised)
            .overlay {
                RoundedRectangle(cornerRadius: WeektableTheme.controlRadius, style: .continuous)
                    .stroke(isSelected ? WeektableTheme.brand : WeektableTheme.divider, lineWidth: isSelected ? 2 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: WeektableTheme.controlRadius, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.bold))
            .tracking(0.8)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum Haptics {
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func lightImpact() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}

