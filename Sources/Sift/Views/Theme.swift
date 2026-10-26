import SwiftUI
import SiftCore

/// Lavender primary, with chartreuse and tomato red as secondary accents. The app always runs in light appearance (see AppDelegate).
enum Theme {
    static let accent = Color(hex: 0x8A63D2)
    static let accentSoft = Color(hex: 0xEFE8FB)
    static let accentDeep = Color(hex: 0x6A44B8)
    static let ink = Color(hex: 0x1F1A33)
    static let muted = Color(hex: 0x7A7391)
    static let surface = Color.white.opacity(0.78)
    static let hairline = Color.white.opacity(0.9)
    static let shadow = Color(hex: 0x7A55C8).opacity(0.10)
    static let tomato = Color(hex: 0xFF6347)
    static let chartreuse = Color(hex: 0xB8F000)

    static let gradient = LinearGradient(colors: [Color(hex: 0xA889E6), Color(hex: 0x8A63D2), Color(hex: 0x6A44B8)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
    static let hero = LinearGradient(colors: [Color(hex: 0x6A44B8), Color(hex: 0x8A63D2), Color(hex: 0xB79CF0)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)

    static let radius: CGFloat = 18

    /// Each area gets its own gradient so the overview reads at a glance.
    static func gradient(for kind: SectionKind) -> LinearGradient {
        let (a, b): (UInt32, UInt32) = switch kind {
        case .junk: (0xC9B3F5, 0x8A63D2)
        case .files: (0xFF9A85, 0xFF6347)
        case .apps: (0xD4FF4A, 0x86C400)
        case .developer: (0xB79CF0, 0xFF6347)
        case .localAI: (0xC6F04A, 0x9B7BE0)
        }
        return LinearGradient(colors: [Color(hex: a), Color(hex: b)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// Soft lavender canvas with a chartreuse and a tomato glow with blurred colour blobs behind everything.
struct Backdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xF5F0FF), Color(hex: 0xFAF8FF), Color(hex: 0xF1EBFD)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            GeometryReader { geo in
                Circle()
                    .fill(Color(hex: 0xDFFF66).opacity(0.35))
                    .frame(width: 520, height: 520)
                    .blur(radius: 120)
                    .position(x: geo.size.width * 0.85, y: geo.size.height * 0.05)
                Circle()
                    .fill(Color(hex: 0xFFB4A3).opacity(0.35))
                    .frame(width: 460, height: 460)
                    .blur(radius: 120)
                    .position(x: geo.size.width * 0.15, y: geo.size.height * 0.95)
            }
        }
        .ignoresSafeArea()
    }
}

/// Frosted white card with a soft lavender shadow, the base surface for grouped content.
struct CardBackground: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .fill(Theme.surface)
                    .shadow(color: Theme.shadow, radius: 18, y: 8)
            }
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1))
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View { modifier(CardBackground(padding: padding)) }
}

/// Rounded square holding an SF Symbol: soft lavender by default, or filled with a gradient.
struct IconTile: View {
    let symbol: String
    var size: CGFloat = 32
    var fill: LinearGradient? = nil

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(fill == nil ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.white))
            .frame(width: size, height: size)
            .background {
                let shape = RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                if let fill {
                    shape.fill(fill).shadow(color: Theme.shadow.opacity(2), radius: 6, y: 3)
                } else {
                    shape.fill(Theme.accentSoft)
                }
            }
            .accessibilityHidden(true)   // decorative: the text beside it says what it is
    }
}

/// Filled lavender capsule for the main action on a screen.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 9)
            .background(Theme.gradient, in: Capsule())
            .shadow(color: Theme.accent.opacity(isEnabled ? 0.35 : 0), radius: 10, y: 4)
            .overlay(FocusRing(visible: isFocused))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Quiet capsule for secondary actions.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(Theme.accentDeep)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Theme.accentSoft, in: Capsule())
            .overlay(FocusRing(visible: isFocused))
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Lavender keyboard-focus ring, replacing the system one (which follows the user's accent colour).
private struct FocusRing: View {
    let visible: Bool

    var body: some View {
        Capsule()
            .strokeBorder(Theme.accent.opacity(0.6), lineWidth: 2)
            .padding(-3)
            .opacity(visible ? 1 : 0)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

/// White ring for the hero card: used disk space, with a chartreuse arc for what can be freed.
struct DiskRing: View {
    let used: Int64
    let total: Int64
    let reclaimable: Int64

    var body: some View {
        let usedFraction = total > 0 ? Double(used) / Double(total) : 0
        let freeable = total > 0 ? min(Double(reclaimable) / Double(total), usedFraction) : 0
        ZStack {
            Group {
                Circle().stroke(.white.opacity(0.18), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: usedFraction)
                    .stroke(.white.opacity(0.45), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                Circle()
                    .trim(from: max(usedFraction - freeable, 0), to: usedFraction)
                    .stroke(Theme.chartreuse, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .shadow(color: Theme.chartreuse.opacity(0.6), radius: 6)
            }
            .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int((usedFraction * 100).rounded()))%")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("used").font(.caption.weight(.medium)).opacity(0.8)
            }
            .foregroundStyle(.white)
        }
        .animation(.easeInOut(duration: 0.6), value: reclaimable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Disk usage")
        .accessibilityValue("\(Int((usedFraction * 100).rounded())) percent used, \(Format.bytes(reclaimable)) can be freed")
    }
}
