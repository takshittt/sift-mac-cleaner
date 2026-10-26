import SwiftUI
import SiftCore
import SiftAppModel

struct ConfirmSheet: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let plan = state.plan
        VStack(alignment: .leading, spacing: 14) {
            IconTile(symbol: "sparkles", size: 48, fill: Theme.hero)
            Text("Clean \(Format.items(state.selection.count))?")
                .font(.system(.title2, design: .rounded).weight(.semibold))

            if plan.permanentCount > 0 {
                Label {
                    Text("\(Format.items(plan.permanentCount)) (\(Format.bytes(plan.permanentBytes))) will be deleted permanently: caches, logs and other files that are rebuilt automatically.")
                } icon: { Image(systemName: "bolt.fill").foregroundStyle(Theme.accent) }
            }
            if plan.trashCount > 0 {
                Label {
                    Text("\(Format.items(plan.trashCount)) (\(Format.bytes(plan.trashBytes))) will be moved to the Trash. Empty it to reclaim the space.")
                } icon: { Image(systemName: "trash").foregroundStyle(Theme.muted) }
            }
            if state.selectionHasReviewItems {
                Label {
                    Text("Your selection includes items marked Review that may contain personal data.")
                } icon: { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Risk.review.color) }
            }
            if AppState.developmentForcesTrash {
                Text("Development build: everything except the Trash itself goes to the Trash.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { state.showConfirm = false }
                    .buttonStyle(.secondary)
                    .keyboardShortcut(.cancelAction)
                Button("Clean \(Format.bytes(state.selectedBytes))") {
                    Task { await state.clean() }
                }
                .buttonStyle(.primary)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 6)
        }
        .padding(28)
        .frame(width: 460)
        .background(Backdrop())
        .focusEffectDisabled()
    }
}

struct CleaningSheet: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 14) {
            IconTile(symbol: "wand.and.stars", size: 48, fill: Theme.hero)
                .symbolEffect(.pulse)
            Text("Cleaning…").font(.system(.title3, design: .rounded).weight(.semibold))
            if case .cleaning(let progress) = state.phase {
                ProgressView(value: progress).tint(Theme.accent)
            }
        }
        .padding(28)
        .frame(width: 360)
        .background(Backdrop())
        .interactiveDismissDisabled()
    }
}

struct ReportSheet: View {
    @Environment(AppState.self) private var state
    let report: CleanReport

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            IconTile(symbol: "checkmark", size: 48, fill: Theme.hero)
            Text("All clean").font(.system(.title2, design: .rounded).weight(.semibold))
            if report.deletedCount > 0 {
                Label("\(Format.bytes(report.deletedBytes)) freed (\(Format.items(report.deletedCount)) deleted)",
                      systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accentDeep)
            }
            if report.trashedCount > 0 {
                Label("\(Format.items(report.trashedCount)) (\(Format.bytes(report.trashedBytes))) moved to the Trash. Empty it to reclaim the space.",
                      systemImage: "trash")
            }
            if !report.failures.isEmpty {
                Label("\(Format.items(report.failures.count)) could not be removed", systemImage: "xmark.octagon")
                    .foregroundStyle(Risk.review.color)
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(report.failures.enumerated()), id: \.offset) { _, failure in
                            Text("\(failure.item.name): \(failure.message)")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 140)
            }
            HStack {
                Spacer()
                Button("OK") { state.dismissReport() }
                    .buttonStyle(.primary)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 6)
        }
        .padding(28)
        .frame(width: 440)
        .background(Backdrop())
        .focusEffectDisabled()
    }
}
