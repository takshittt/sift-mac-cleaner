import SwiftUI
import SiftCore
import SiftAppModel

/// The Settings window (⌘,): how files are removed, which areas are scanned,
/// which rules are ticked by default, and how Sift keeps you safe.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            RuleSettings()
                .tabItem { Label("Rules", systemImage: "checklist") }
            ScrollView { SafetyInfo().padding(24) }
                .tabItem { Label("Safety", systemImage: "lock.shield") }
        }
        .frame(width: 560, height: 520)
        .tint(Theme.accent)
        .foregroundStyle(Theme.ink)
    }
}

struct GeneralSettings: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var settings = state.settings
        Form {
            Section {
                Picker("When cleaning", selection: $settings.mode) {
                    ForEach(DeletionMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                Text(settings.mode.explanation)
                    .font(.callout)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Deletion mode")
            }

            Section {
                ForEach(Profile.allCases) { profile in
                    Toggle(isOn: Binding(get: { settings.enabledProfiles.contains(profile) },
                                         set: { state.setProfile(profile, enabled: $0) })) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(profile.title)
                            Text(profile.summary).font(.caption).foregroundStyle(Theme.muted)
                        }
                    }
                    .disabled(profile == .general)
                }
            } header: {
                Text("Areas to scan")
            } footer: {
                Text("Changes apply on the next scan.").foregroundStyle(Theme.muted)
            }

            Section {
                LabeledContent("Freed with Sift so far", value: Format.bytes(settings.lifetimeFreed))
                HStack {
                    Text("Smart mode, the detected areas and every rule back to its default.")
                        .font(.callout)
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Button("Reset to Recommended") { state.resetToRecommended() }
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// Per-rule "tick by default" switches. Only green rules are listed: caution
/// and review items are never ticked for you, whatever the setting.
struct RuleSettings: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let settings = state.settings
        Form {
            ForEach(SectionKind.allCases) { kind in
                let rules = RuleCatalog.all.filter { $0.section == kind && $0.risk == .safe }
                if !rules.isEmpty {
                    Section(kind.title) {
                        ForEach(rules) { rule in
                            Toggle(isOn: Binding(get: { settings.isOn(rule) },
                                                 set: { state.setRule(rule, on: $0) })) {
                                HStack(spacing: 10) {
                                    IconTile(symbol: rule.symbol, size: 26, fill: Theme.gradient(for: kind))
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(rule.title)
                                        if !settings.enabledProfiles.contains(rule.profile) {
                                            Text("Not scanned: \(rule.profile.title) is off")
                                                .font(.caption)
                                                .foregroundStyle(Theme.muted)
                                        }
                                    }
                                }
                            }
                            .help(rule.subtitle)
                        }
                    }
                }
            }
            Section {
                Text("Choose which green (Safe) categories are ticked for you after a scan. Caution and Review items are never ticked automatically.")
                    .font(.callout)
                    .foregroundStyle(Theme.muted)
            }
        }
        .formStyle(.grouped)
    }
}

/// "How Sift keeps you safe": the safety rules from intent.md, in plain words.
struct SafetyInfo: View {
    private let rules: [(symbol: String, title: String, text: String)] = [
        ("hand.raised.fill", "Some places are never touched",
         "Documents, Photos, iCloud Drive, passwords (Keychain), Mail, Messages, Contacts, Calendars and Safari data are blocked. This is built into the app's logic, so a mistake in a list can't undo it."),
        ("trash.fill", "Anything that might be yours goes to the Trash first",
         "You can still get it back. Only true throwaway files (caches and logs that rebuild themselves) are deleted right away, because moving them to the Trash wouldn't free any space."),
        ("app.badge.checkmark.fill", "Open apps are left alone",
         "If an app is running, its files are not selected, because it is probably using them."),
        ("icloud.fill", "Cloud and sync folders are flagged",
         "Folders for Dropbox, OneDrive, Google Drive, Docker, games and AI models can hold your own files. They are clearly marked and never pre-selected."),
        ("house.fill", "Nothing outside your user folder is removed",
         "Sift won't follow shortcuts (symlinks) that point somewhere else."),
        ("eye.fill", "Upfront about what it can't see",
         "macOS hides some folders unless Sift has Full Disk Access. Sift tells you when that happens and offers a button to open the right setting."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("How Sift keeps you safe")
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                Text("Freeing space is only useful if nothing important is lost.")
                    .foregroundStyle(Theme.muted)
            }
            ForEach(rules, id: \.title) { rule in
                HStack(alignment: .top, spacing: 12) {
                    IconTile(symbol: rule.symbol, size: 34)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rule.title).font(.body.weight(.semibold))
                        Text(rule.text)
                            .font(.callout)
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("What the colours mean").font(.body.weight(.semibold))
                ForEach(Risk.allCases, id: \.self) { risk in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        RiskBadge(risk: risk)
                        Text(risk.explanation).font(.callout).foregroundStyle(Theme.muted)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Main-window sheet wrapper around `SafetyInfo`.
struct SafetySheet: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView { SafetyInfo().padding(28) }
            HStack {
                Spacer()
                Button("Done") { state.showSafetyInfo = false }
                    .buttonStyle(.primary)
                    .keyboardShortcut(.defaultAction)
            }
            .padding([.horizontal, .bottom], 20)
        }
        .frame(width: 520, height: 560)
        .background(Backdrop())
        .focusEffectDisabled()
    }
}
