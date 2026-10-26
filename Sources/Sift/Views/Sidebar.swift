import SwiftUI
import SiftCore
import SiftAppModel

/// Custom-drawn sidebar. A native `List` selection is painted in the user's system
/// accent colour, which would override the purple theme.
struct Sidebar: View {
    @Environment(AppState.self) private var state
    @Binding var selection: SidebarSelection?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Theme.hero, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: Theme.accent.opacity(0.35), radius: 8, y: 3)
                Text("Sift").font(.system(size: 20, weight: .bold, design: .rounded))
            }
            .padding(.horizontal, 8)
            .padding(.top, 40)   // clears the window's traffic-light buttons
            .padding(.bottom, 18)

            SidebarRow(title: "Overview", symbol: "square.grid.2x2.fill", fill: Theme.gradient, total: 0,
                       selected: (selection ?? .overview) == .overview) { selection = .overview }
            Text("AREAS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 10)
                .padding(.top, 16)
                .padding(.bottom, 4)
            ForEach(SectionKind.allCases) { kind in
                SidebarRow(title: kind.title, symbol: kind.symbol, fill: Theme.gradient(for: kind),
                           total: state.total(of: kind),
                           selected: selection == .section(kind)) { selection = .section(kind) }
            }
            Spacer(minLength: 0)
            Button { state.showSafetyInfo = true } label: {
                Label("How Sift keeps you safe", systemImage: "lock.shield")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.accentDeep)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
            LifetimeBadge()
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct SidebarRow: View {
    let title: String
    let symbol: String
    let fill: LinearGradient
    let total: Int64
    let selected: Bool
    let action: () -> Void
    @ViewState private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                IconTile(symbol: symbol, size: 26, fill: fill)
                Text(title)
                    .font(.system(size: 13, weight: selected ? .semibold : .medium))
                    .lineLimit(1)
                Spacer(minLength: 4)
                if total > 0 {
                    Text(Format.bytes(total))
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(selected ? Theme.accentDeep : Theme.muted)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(selected ? Theme.accentSoft : Theme.accentSoft.opacity(hovering ? 0.5 : 0))
            }
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(Theme.gradient)
                    .frame(width: 3, height: selected ? 18 : 0)
                    .offset(x: -6)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(total > 0 ? "\(title), \(Format.bytes(total))" : title)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .animation(.spring(duration: 0.3), value: selected)
    }
}

/// Small "freed so far" note at the foot of the sidebar.
struct LifetimeBadge: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Freed with Sift")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            Text(Format.bytes(state.settings.lifetimeFreed))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.hero)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.accentSoft.opacity(0.7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
