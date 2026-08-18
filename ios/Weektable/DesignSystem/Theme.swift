import SwiftUI
import UIKit

enum WeektableTheme {
    static let brand = adaptive(
        light: UIColor(red: 0.20, green: 0.34, blue: 0.23, alpha: 1),
        dark: UIColor(red: 0.58, green: 0.73, blue: 0.57, alpha: 1)
    )
    static let brandDeep = adaptive(
        light: UIColor(red: 0.10, green: 0.25, blue: 0.16, alpha: 1),
        dark: UIColor(red: 0.32, green: 0.51, blue: 0.35, alpha: 1)
    )
    static let canvas = adaptive(
        light: UIColor(red: 0.975, green: 0.957, blue: 0.925, alpha: 1),
        dark: UIColor(red: 0.075, green: 0.072, blue: 0.065, alpha: 1)
    )
    static let surface = adaptive(
        light: UIColor(red: 0.941, green: 0.908, blue: 0.850, alpha: 1),
        dark: UIColor(red: 0.13, green: 0.125, blue: 0.112, alpha: 1)
    )
    static let raised = adaptive(
        light: UIColor(red: 1.0, green: 0.992, blue: 0.976, alpha: 1),
        dark: UIColor(red: 0.115, green: 0.11, blue: 0.10, alpha: 1)
    )
    static let ink = adaptive(
        light: UIColor(red: 0.17, green: 0.11, blue: 0.085, alpha: 1),
        dark: UIColor(red: 0.96, green: 0.93, blue: 0.88, alpha: 1)
    )
    static let secondaryInk = adaptive(
        light: UIColor(red: 0.43, green: 0.39, blue: 0.35, alpha: 1),
        dark: UIColor(red: 0.70, green: 0.67, blue: 0.62, alpha: 1)
    )
    static let terracotta = adaptive(
        light: UIColor(red: 0.78, green: 0.31, blue: 0.18, alpha: 1),
        dark: UIColor(red: 0.94, green: 0.49, blue: 0.34, alpha: 1)
    )
    static let gold = adaptive(
        light: UIColor(red: 0.77, green: 0.55, blue: 0.14, alpha: 1),
        dark: UIColor(red: 0.92, green: 0.70, blue: 0.29, alpha: 1)
    )
    static let sage = adaptive(
        light: UIColor(red: 0.55, green: 0.67, blue: 0.52, alpha: 1),
        dark: UIColor(red: 0.48, green: 0.62, blue: 0.47, alpha: 1)
    )
    static let sky = adaptive(
        light: UIColor(red: 0.43, green: 0.67, blue: 0.65, alpha: 1),
        dark: UIColor(red: 0.45, green: 0.72, blue: 0.70, alpha: 1)
    )
    static let success = adaptive(
        light: UIColor(red: 0.12, green: 0.43, blue: 0.27, alpha: 1),
        dark: UIColor(red: 0.42, green: 0.78, blue: 0.56, alpha: 1)
    )
    static let warning = adaptive(
        light: UIColor(red: 0.78, green: 0.49, blue: 0.10, alpha: 1),
        dark: UIColor(red: 0.94, green: 0.68, blue: 0.28, alpha: 1)
    )
    static let error = Color(uiColor: .systemRed)
    static let selected = brand.opacity(0.13)
    static let disabled = Color(uiColor: .tertiaryLabel)
    static let divider = adaptive(
        light: UIColor(red: 0.79, green: 0.74, blue: 0.67, alpha: 0.45),
        dark: UIColor(red: 0.42, green: 0.39, blue: 0.35, alpha: 0.55)
    )

    static let heroRadius: CGFloat = 30
    static let cardRadius: CGFloat = 24
    static let controlRadius: CGFloat = 17
    static let compactRadius: CGFloat = 12
    static let pagePadding: CGFloat = 20

    static func preferenceAccent(at index: Int) -> Color {
        [brand, terracotta, sky, gold, sage, brandDeep][index % 6]
    }

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

extension Font {
    static let coveDisplay = Font.system(size: 36, weight: .bold, design: .rounded)
    static let coveTitle = Font.system(size: 29, weight: .bold, design: .rounded)
    static let coveCardTitle = Font.system(size: 20, weight: .bold, design: .rounded)
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .frame(maxWidth: .infinity, minHeight: 58)
            .foregroundStyle(.white)
            .background(isEnabled ? WeektableTheme.brandDeep : WeektableTheme.disabled)
            .clipShape(RoundedRectangle(cornerRadius: WeektableTheme.controlRadius, style: .continuous))
            .shadow(color: isEnabled ? WeektableTheme.brandDeep.opacity(0.18) : .clear, radius: 12, y: 6)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .frame(minWidth: 54, minHeight: 54)
            .padding(.horizontal, 14)
            .foregroundStyle(WeektableTheme.ink)
            .background(WeektableTheme.raised)
            .clipShape(RoundedRectangle(cornerRadius: WeektableTheme.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: WeektableTheme.controlRadius, style: .continuous)
                    .stroke(WeektableTheme.divider, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: configuration.isPressed)
    }
}

struct SelectionCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let isSelected: Bool
    var accent: Color = WeektableTheme.brand
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Image(systemName: symbol)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : accent)
                        .frame(width: 40, height: 40)
                        .background(isSelected ? accent : accent.opacity(0.12), in: Circle())
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? accent : WeektableTheme.secondaryInk.opacity(0.5))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(WeektableTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
            .padding(15)
            .background(isSelected ? accent.opacity(0.12) : WeektableTheme.raised)
            .overlay {
                RoundedRectangle(cornerRadius: WeektableTheme.controlRadius, style: .continuous)
                    .stroke(isSelected ? accent : WeektableTheme.divider, lineWidth: isSelected ? 1.5 : 0.75)
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
            .font(.caption2.weight(.black))
            .tracking(1.1)
            .foregroundStyle(WeektableTheme.secondaryInk)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    func coveCard(
        radius: CGFloat = WeektableTheme.cardRadius,
        fill: Color = WeektableTheme.raised,
        shadow: Bool = true
    ) -> some View {
        self
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(WeektableTheme.divider, lineWidth: 0.75)
            }
            .shadow(color: shadow ? Color.black.opacity(0.055) : .clear, radius: 16, y: 7)
    }
}

enum Haptics {
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func lightImpact() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}
