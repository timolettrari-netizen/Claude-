import SwiftUI

enum Theme {
    static let accent = Color(red: 1.0, green: 0.42, blue: 0.16)
    static let accent2 = Color(red: 1.0, green: 0.24, blue: 0.42)
}

/// Farbiger, weicher Hintergrund – darauf kommt das Liquid Glass erst richtig zur Geltung.
struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.6, 0.4], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1]
            ],
            colors: scheme == .dark ? Self.dark : Self.light
        )
        .ignoresSafeArea()
    }

    private static let dark: [Color] = [
        Color(red: 0.10, green: 0.05, blue: 0.18), Color(red: 0.24, green: 0.07, blue: 0.24), Color(red: 0.05, green: 0.07, blue: 0.20),
        Color(red: 0.38, green: 0.11, blue: 0.10), Color(red: 0.13, green: 0.07, blue: 0.22), Color(red: 0.05, green: 0.16, blue: 0.28),
        Color(red: 0.55, green: 0.20, blue: 0.07), Color(red: 0.22, green: 0.06, blue: 0.20), Color(red: 0.04, green: 0.05, blue: 0.13)
    ]

    private static let light: [Color] = [
        Color(red: 1.00, green: 0.87, blue: 0.78), Color(red: 0.97, green: 0.85, blue: 0.95), Color(red: 0.80, green: 0.89, blue: 1.00),
        Color(red: 1.00, green: 0.76, blue: 0.66), Color(red: 0.98, green: 0.94, blue: 0.97), Color(red: 0.78, green: 0.92, blue: 0.98),
        Color(red: 1.00, green: 0.68, blue: 0.52), Color(red: 0.93, green: 0.81, blue: 0.95), Color(red: 0.84, green: 0.87, blue: 1.00)
    ]
}

extension Glass {
    static func make(tint: Color? = nil, interactive: Bool = false) -> Glass {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return glass
    }
}

extension View {
    /// Karte aus Liquid Glass.
    func glassCard(padding: CGFloat = 16, radius: CGFloat = 26, tint: Color? = nil, interactive: Bool = false) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(Glass.make(tint: tint, interactive: interactive), in: .rect(cornerRadius: radius))
    }

    /// Einheitlicher Hintergrund für alle Bildschirme.
    func appBackground() -> some View {
        self.background { AppBackground() }
    }
}

// MARK: - Bausteine

struct SectionTitle: View {
    let text: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text).font(.title3.bold())
            Spacer()
            if let trailing {
                Text(trailing).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 6)
    }
}

struct StatTile: View {
    let value: String
    let label: String
    let icon: String
    var tint: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .glassCard(padding: 14, radius: 22)
    }
}

struct Chip: View {
    let title: String
    var icon: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .foregroundStyle(selected ? Color.white : Color.primary)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(Glass.make(tint: selected ? Theme.accent : nil, interactive: true), in: .capsule)
    }
}

struct MuscleDot: View {
    let muscle: Muscle
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(muscle.color.gradient)
            .frame(width: size, height: size)
    }
}

struct Badge: View {
    let text: String
    var icon: String? = nil
    var tint: Color = Theme.accent

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon) }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundStyle(tint)
        .background(tint.opacity(0.15), in: Capsule())
    }
}
