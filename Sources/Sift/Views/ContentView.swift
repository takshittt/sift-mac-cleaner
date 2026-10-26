import SwiftUI
import SiftCore
import SiftAppModel

enum SidebarSelection: Hashable {
    case overview
    case section(SectionKind)
}

struct ContentView: View {
    @Environment(AppState.self) private var state
    @ViewState private var selection: SidebarSelection? = .overview

    var body: some View {
        let current = selection ?? .overview
        HStack(spacing: 0) {
            Sidebar(selection: $selection)
                .frame(width: 252)
                .card(padding: 0)
                .padding(.leading, 12)
                .padding(.vertical, 12)
            VStack(spacing: 0) {
                PageHeader(title: current.title)
                switch current {
                case .overview: OverviewView(selection: $selection)
                case .section(let kind): CategoryView(kind: kind)
                }
            }
            .overlay(alignment: .bottom) {
                ActionBar()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 18)
            }
        }
        .background(Backdrop())
        .ignoresSafeArea(.container, edges: .top)
        .foregroundStyle(Theme.ink)
        .tint(Theme.accent)
        .accentColor(Theme.accent)
        .focusEffectDisabled()
        .task {
            await state.onLaunch()
            if SmokeTest.isEnabled { await SmokeTest.run(state) }
        }
        // One sheet slot for the whole confirm → cleaning → report flow.
        .sheet(item: Binding(get: { state.activeSheet }, set: { if $0 == nil { state.closeSheet() } })) { sheet in
            switch sheet {
            case .profiles: ProfilePicker()
            case .safety: SafetySheet()
            case .confirm: ConfirmSheet()
            case .cleaning: CleaningSheet()
            case .report(let report): ReportSheet(report: report)
            }
        }
    }
}

extension SidebarSelection {
    var title: String {
        switch self {
        case .overview: "Overview"
        case .section(let kind): kind.title
        }
    }
}

/// Large page title with the "what do you use this Mac for?" control on the right.
struct PageHeader: View {
    @Environment(AppState.self) private var state
    let title: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Spacer()
            Button { state.openProfilePicker() } label: {
                Label("Areas", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.secondary)
            .help("Choose which areas Sift scans")
            .disabled(state.isBusy)
        }
        .padding(.horizontal, 32)
        .padding(.top, 34)
        .padding(.bottom, 4)
    }
}

enum ActiveSheet: Identifiable {
    case profiles, safety, confirm, cleaning, report(CleanReport)

    var id: String {
        switch self {
        case .profiles: "profiles"
        case .safety: "safety"
        case .confirm: "confirm"
        case .cleaning: "cleaning"
        case .report: "report"
        }
    }
}

extension AppState {
    var activeSheet: ActiveSheet? {
        if showProfilePicker { return .profiles }
        if showSafetyInfo { return .safety }
        if showConfirm { return .confirm }
        if case .cleaning = phase { return .cleaning }
        if let report { return .report(report) }
        return nil
    }

    /// Called when a sheet is dismissed by the system (e.g. Escape).
    func closeSheet() {
        if showProfilePicker { closeProfilePicker() }
        else if showSafetyInfo { showSafetyInfo = false }
        else if showConfirm { showConfirm = false }
        else if report != nil { dismissReport() }
    }
}
