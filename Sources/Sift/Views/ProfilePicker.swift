import SwiftUI
import SiftCore
import SiftAppModel

/// "What do you use this Mac for?" Shown on first launch and from the toolbar.
struct ProfilePicker: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("What do you use this Mac for?")
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                Text("Sift detected these from what is installed. Switch any on or off; only enabled areas are scanned.")
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 8) {
                ForEach(Profile.allCases) { profile in
                    let on = state.settings.enabledProfiles.contains(profile)
                    Toggle(isOn: Binding(get: { on }, set: { state.setProfile(profile, enabled: $0) })) {
                        HStack(spacing: 12) {
                            IconTile(symbol: symbol(profile), size: 38, fill: gradient(profile))
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(profile.title).bold()
                                    if state.settings.detectedProfiles.contains(profile) {
                                        Text("Detected")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(Theme.accentDeep)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 2)
                                            .background(Theme.accentSoft, in: Capsule())
                                    }
                                }
                                Text(profile.summary).font(.callout).foregroundStyle(Theme.muted)
                            }
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(Theme.accent)
                    .disabled(profile == .general)
                    .focusEffectDisabled()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(padding: 12)
                }
            }

            HStack {
                Spacer()
                Button("Done") { state.closeProfilePicker() }
                    .buttonStyle(.primary)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 460)
        .background(Backdrop())
        .focusEffectDisabled()
    }

    private func gradient(_ profile: Profile) -> LinearGradient {
        switch profile {
        case .general: Theme.gradient(for: .junk)
        case .developer: Theme.gradient(for: .developer)
        case .localAI: Theme.gradient(for: .localAI)
        }
    }

    private func symbol(_ profile: Profile) -> String {
        switch profile {
        case .general: "sparkles"
        case .developer: "hammer"
        case .localAI: "cpu"
        }
    }
}
