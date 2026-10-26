import SwiftUI
import SiftCore
import SiftAppModel

/// First screen: disk usage, what was found per area, lifetime total.
struct OverviewView: View {
    @Environment(AppState.self) private var state
    @Binding var selection: SidebarSelection?

    private let columns = [GridItem(.adaptive(minimum: 200), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero
                ProfileChips()
                if !state.fullDiskAccess { FullDiskAccessBanner() }
                if state.phase == .ready, state.foundBytes == 0 { AllClearCard() }
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(SectionKind.allCases) { kind in
                        let total = state.total(of: kind)
                        if total > 0 {
                            AreaCard(kind: kind, total: total, share: share(total)) { selection = .section(kind) }
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 14)
            .padding(.bottom, 110)   // room for the floating action bar
            .frame(maxWidth: 860, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.never)
    }

    private func share(_ total: Int64) -> Double {
        state.foundBytes > 0 ? Double(total) / Double(state.foundBytes) : 0
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: 30) {
            VStack(alignment: .leading, spacing: 10) {
                Text(state.isBusy && state.categories.isEmpty ? "SCANNING YOUR MAC" : "READY TO CLEAN")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .opacity(0.85)
                Text(state.isBusy && state.categories.isEmpty ? "Looking around…" : Format.bytes(state.foundBytes))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if state.disk.total > 0 {
                    Text("\(Format.bytes(state.disk.free)) free of \(Format.bytes(state.disk.total))")
                        .font(.callout.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.2), in: Capsule())
                }
            }
            Spacer(minLength: 0)
            if state.disk.total > 0 {
                DiskRing(used: state.disk.used, total: state.disk.total, reclaimable: state.foundBytes)
                    .frame(width: 136, height: 136)
            }
        }
        .foregroundStyle(.white)
        .padding(30)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Theme.hero)
                // Soft highlight blobs for depth.
                Circle().fill(.white.opacity(0.18)).frame(width: 260).blur(radius: 50).offset(x: 220, y: -90)
                Circle().fill(Color(hex: 0x5B3FB5).opacity(0.35)).frame(width: 240).blur(radius: 60).offset(x: -200, y: 90)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: Color(hex: 0x8A63D2).opacity(0.35), radius: 24, y: 12)
        }
    }
}

struct AreaCard: View {
    let kind: SectionKind
    let total: Int64
    let share: Double
    let action: () -> Void
    @ViewState private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    IconTile(symbol: kind.symbol, size: 40, fill: Theme.gradient(for: kind))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 28, height: 28)
                        .background(Theme.accentSoft, in: Circle())
                        .opacity(hovering ? 1 : 0.6)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.muted)
                    Text(Format.bytes(total))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.accentSoft)
                        Capsule().fill(Theme.gradient(for: kind))
                            .frame(width: max(6, geo.size.width * share))
                    }
                }
                .frame(height: 6)
            }
            .card(padding: 18)
            .scaleEffect(hovering ? 1.02 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(kind.title), \(Format.bytes(total))")
        .accessibilityHint("Shows what Sift found in this area")
        .onHover { hovering = $0 }
        .animation(.spring(duration: 0.25), value: hovering)
    }
}

/// The areas being scanned, as chips. Clicking one opens the area picker.
struct ProfileChips: View {
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(spacing: 8) {
            Text("Scanning for")
                .font(.callout)
                .foregroundStyle(Theme.muted)
            ForEach(Profile.allCases.filter { state.settings.enabledProfiles.contains($0) }) { profile in
                Button { state.openProfilePicker() } label: {
                    Text(profile.title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(Theme.accentDeep)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Theme.accentSoft, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(state.isBusy)
                .accessibilityHint("Choose which areas Sift scans")
            }
        }
    }
}

/// Shown when a finished scan found nothing in the enabled areas.
struct AllClearCard: View {
    var body: some View {
        HStack(spacing: 14) {
            IconTile(symbol: "checkmark", size: 40, fill: Theme.gradient(for: .apps))
            VStack(alignment: .leading, spacing: 2) {
                Text("All clear").font(.body.weight(.semibold))
                Text("Nothing to clean in the enabled areas.")
                    .font(.callout)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
        }
        .card(padding: 16)
        .accessibilityElement(children: .combine)
    }
}

struct FullDiskAccessBanner: View {
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            IconTile(symbol: "lock.shield.fill", size: 40,
                     fill: LinearGradient(colors: [Color(hex: 0xFF9A85), Color(hex: 0xFF6347)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack(alignment: .leading, spacing: 3) {
                Text("Grant Full Disk Access for a complete scan").font(.body.weight(.semibold))
                Text("macOS hides Safari data, Mail downloads, device backups and some app containers without it. Add Sift under Privacy & Security › Full Disk Access, then scan again.")
                    .font(.callout)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("Open Settings") { state.openFullDiskAccessSettings() }
                .buttonStyle(.secondary)
        }
        .card(padding: 16)
    }
}
