import SwiftUI

extension Color {
    static let lime = Color(red: 0.776, green: 0.957, blue: 0.196)
    static let bg = Color(red: 0.039, green: 0.039, blue: 0.043)
    static let card = Color(red: 0.086, green: 0.086, blue: 0.094)
    static let card2 = Color.white.opacity(0.08)
    static let mut = Color.white.opacity(0.55)
    static let line = Color.white.opacity(0.08)

    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}

extension Font {
    /// Sportliche, kursive Schmalschrift (wie die Web-App)
    static func sport(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy).width(.condensed).italic()
    }
}

struct CardStyle: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.line, lineWidth: 1))
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View { modifier(CardStyle(padding: padding)) }

    func sectionTitle() -> some View {
        self.font(.sport(26)).textCase(.uppercase).foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LimeButton: ButtonStyle {
    var secondary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .heavy))
            .textCase(.uppercase)
            .tracking(0.6)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(secondary ? Color.white : Color.black)
            .background(secondary ? Color.card2 : Color.lime, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct Pill: View {
    let text: String
    var highlight = false
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 11).padding(.vertical, 5)
            .foregroundStyle(highlight ? Color.lime : .white)
            .background(highlight ? Color.lime.opacity(0.15) : Color.card2, in: Capsule())
    }
}

struct SessionIcon: View {
    let session: SessionType?
    var size: CGFloat = 34
    var body: some View {
        let c = session?.colors ?? ["#3A3A3E", "#1C1C1E"]
        Text(session?.icon ?? "")
            .font(.system(size: size * 0.5))
            .frame(width: size, height: size)
            .background(LinearGradient(colors: [Color(hex: c[0]), Color(hex: c.count > 1 ? c[1] : c[0])],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
    }
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}
