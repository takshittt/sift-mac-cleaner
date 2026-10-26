import SwiftUI
import SiftCore
import SiftAppModel

struct ActionBar: View {
    @Environment(AppState.self) private var state

    var body: some View {
        HStack(spacing: 10) {
            switch state.phase {
            case .scanning(let progress):
                ProgressView(value: progress)
                    .tint(Theme.accent)
                    .frame(width: 140)
                Text(state.currentRule.isEmpty ? "Scanning…" : "Scanned \(state.currentRule)")
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                Spacer()
                Button("Stop") { state.cancelScan() }
                    .buttonStyle(.secondary)
            default:
                VStack(alignment: .leading, spacing: 0) {
                    Text(Format.bytes(state.selectedBytes))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.hero)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("\(Format.items(state.selection.count)) selected")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                .accessibilityElement(children: .combine)
                Spacer()
                Button("Select Recommended") { state.selectRecommended() }
                    .buttonStyle(.secondary)
                    .disabled(state.isBusy || state.categories.isEmpty)
                Button("Scan Again") { state.scan() }
                    .buttonStyle(.secondary)
                    .disabled(state.isBusy)
                Button("Clean…") { state.requestClean() }
                    .buttonStyle(.primary)
                    .keyboardShortcut(.defaultAction)
                    .disabled(state.selection.isEmpty || state.isBusy)
            }
        }
        .padding(.leading, 22)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .background {
            Capsule()
                .fill(.white.opacity(0.85))
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(color: Theme.shadow.opacity(2), radius: 24, y: 10)
        }
        .overlay(Capsule().strokeBorder(.white, lineWidth: 1))
        .animation(.snappy, value: state.selectedBytes)
    }
}
