import AppKit
import SiftCore
import SiftAppModel

/// `--smoke-test`: the real app on the fake engine walks launch → scan → select →
/// confirm → clean → report, checking which sheet the window shows at each step,
/// then quits with status 0 (pass) or 1 (fail). Stands in for an XCUITest, which
/// needs full Xcode. Run with scripts/smoke-test.sh.
@MainActor
enum SmokeTest {
    static let isEnabled = CommandLine.arguments.contains("--smoke-test")

    static func run(_ state: AppState) async {
        var failures: [String] = []
        func check(_ ok: Bool, _ what: String) {
            print(ok ? "  ok   \(what)" : "  FAIL \(what)")
            if !ok { failures.append(what) }
        }

        // The first launch shows the area picker; close it like the user would.
        if state.activeSheet?.id == "profiles" { state.closeProfilePicker() }
        await state.waitForScan()
        check(state.phase == .ready, "scan finishes")
        check(!state.categories.isEmpty, "scan finds categories")
        check(!state.selection.isEmpty, "recommended items are preselected")
        check(state.selectedItems.allSatisfy { $0.risk == .safe && !$0.isRunningApp },
              "only safe items of apps not running are preselected")

        state.requestClean()
        check(state.activeSheet?.id == "confirm", "Clean… shows the confirm sheet")
        try? await Task.sleep(for: .milliseconds(300))   // let the sheet render

        let selected = state.selection.count
        let cleaning = Task { await state.clean() }
        try? await Task.sleep(for: .milliseconds(20))
        check(state.activeSheet?.id == "cleaning", "confirming shows the cleaning sheet")
        await cleaning.value

        check(state.activeSheet?.id == "report", "cleaning ends on the report sheet")
        let report = state.report
        check((report?.deletedCount ?? 0) + (report?.trashedCount ?? 0) == selected, "report counts every selected item")
        try? await Task.sleep(for: .milliseconds(300))

        state.dismissReport()
        check(state.activeSheet == nil, "OK closes the report")
        await state.waitForScan()
        check(state.phase == .ready, "a rescan follows the clean")

        print(failures.isEmpty ? "Smoke test passed" : "Smoke test FAILED: \(failures.count) check(s)")
        exit(failures.isEmpty ? 0 : 1)
    }
}
