import SwiftUI

struct CoveBrandMark: View {
    var compact = false
    var light = false

    var body: some View {
        HStack(alignment: .top, spacing: 2) {
            Text("Cove")
                .font(.system(size: compact ? 24 : 34, weight: .medium, design: .serif))
                .foregroundStyle(light ? .white : WeektableTheme.ink)
            Image(systemName: "sparkle")
                .font(.system(size: compact ? 7 : 9, weight: .bold))
                .foregroundStyle(WeektableTheme.terracotta)
                .padding(.top, compact ? 2 : 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Cove")
    }
}

struct CoveOtterAvatar: View {
    var size: CGFloat = 42

    var body: some View {
        Image("cove-otter-avatar")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay { Circle().stroke(Color.white.opacity(0.9), lineWidth: 2) }
            .shadow(color: WeektableTheme.ink.opacity(0.10), radius: 6, y: 3)
            .accessibilityLabel("Cove assistant")
    }
}

struct CoveFoodMosaic: View {
    var height: CGFloat = 300

    var body: some View {
        GeometryReader { proxy in
            let gap: CGFloat = 9
            let columnWidth = (proxy.size.width - gap) / 2
            HStack(spacing: gap) {
                VStack(spacing: gap) {
                    tile("meal-pesto-rigatoni")
                        .frame(width: columnWidth, height: (height - gap) * 0.58)
                    tile("meal-smoky-turkey-chili")
                        .frame(width: columnWidth, height: (height - gap) * 0.42)
                }
                VStack(spacing: gap) {
                    tile("meal-crispy-chicken-tacos")
                        .frame(width: columnWidth, height: (height - gap) * 0.42)
                    tile("meal-sausage-peppers")
                        .frame(width: columnWidth, height: (height - gap) * 0.58)
                }
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: WeektableTheme.heroRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: WeektableTheme.heroRadius, style: .continuous)
                .stroke(Color.white.opacity(0.7), lineWidth: 2)
        }
        .shadow(color: WeektableTheme.ink.opacity(0.13), radius: 20, y: 12)
        .accessibilityHidden(true)
    }

    private func tile(_ asset: String) -> some View {
        Image(asset)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
    }
}

struct CoveChoiceChip: View {
    let title: String
    var symbol: String? = nil
    let isSelected: Bool
    var accent: Color = WeektableTheme.brand
    var isConstraint = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.caption.weight(.bold))
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: isSelected ? "checkmark" : "plus")
                    .font(.caption2.weight(.black))
            }
            .foregroundStyle(isSelected ? (isConstraint ? WeektableTheme.ink : Color.white) : WeektableTheme.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(
                isSelected ? (isConstraint ? WeektableTheme.warning.opacity(0.20) : accent) : WeektableTheme.raised,
                in: Capsule()
            )
            .overlay {
                Capsule().stroke(isSelected ? accent.opacity(0.75) : WeektableTheme.divider, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct CoveCounter: View {
    let title: String
    let symbol: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var suffix: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(WeektableTheme.brand)
                .frame(width: 42, height: 42)
                .background(WeektableTheme.selected, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text("\(value) \(suffix)")
                    .font(.title3.bold())
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Spacer()
            HStack(spacing: 8) {
                counterButton("minus", enabled: value > range.lowerBound) { value -= 1 }
                counterButton("plus", enabled: value < range.upperBound) { value += 1 }
            }
        }
        .padding(16)
        .coveCard(radius: WeektableTheme.controlRadius, shadow: false)
        .onChange(of: value) { _, _ in Haptics.selection() }
    }

    private func counterButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.bold))
                .frame(width: 44, height: 44)
                .background(enabled ? WeektableTheme.surface : WeektableTheme.surface.opacity(0.45), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(symbol == "plus" ? "Increase \(title)" : "Decrease \(title)")
    }
}

struct CoveStatusPill: View {
    let text: String
    let symbol: String
    var color: Color = WeektableTheme.brand

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .frame(minHeight: 30)
            .background(color.opacity(0.12), in: Capsule())
    }
}

struct CovePlannerProgress: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? WeektableTheme.brand : WeektableTheme.divider)
                    .frame(maxWidth: .infinity)
                    .frame(height: 5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Planner progress")
        .accessibilityValue("Step \(current + 1) of \(total)")
    }
}
