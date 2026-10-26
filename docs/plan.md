# Sift — Build Plan

Status: closed (v1, 2026-10-26) · Audience: engineers building Sift · What: [intent.md](intent.md) · How: [spec.md](spec.md)

Ten milestones, each ending in something that runs. Work top to bottom: safety (M2) lands before anything can delete a real file. Section references (§) point to spec.md.

**Ground rules for every milestone**
- No code path deletes a file except `CleanEngine` → `SafetyGuard` (§9).
- Tests use a fake `$HOME` in a temp dir. Nothing touches the real home folder in tests.
- While developing, run the app with deletion mode set to **Always move to Trash** until M10.
- A milestone is done when every "Done when" box is ticked and `swift test` + the Xcode build are green.

---

## v1 closeout

The project is closed at v1. Boxes still unticked below are marked *Not done in v1*. They are manual checks that need a person, a real well-used Mac, a clean VM, or an Apple Developer ID account. The release tooling for that last one is in place (`scripts/release.sh`). Everything else is done; see the notes on each item.

---

## M1 · Skeleton

Get an empty app running on fake data, with the frontend/backend split in place.

- [x] Create SwiftPM package `Sift` (macOS 14, SwiftUI, Swift 6 strict concurrency, bundle ID `com.takshitsaini.sift`); `scripts/build-app.sh` makes `build/Sift.app`
- [x] Add `SiftCore` library target and link it to the app target
- [x] Add model types: `Profile`, `Risk`, `SectionKind`, `DeletionMode`, `Rule`, `CleanItem`, `CleanCategory`, `CleanReport`, `Phase`, `ScanContext` (§5)
- [x] Add protocols `Scanning`, `Cleaning`, `AppIndexing`, `SystemInfo`, `SettingsStoring` and the `Engine` composition root (§6)
- [x] Add `Engine.fake()` returning canned categories with a mix of safe / caution / review items
- [x] `AppState` (§11.2) wired to the engine, `ContentView` with `NavigationSplitView` and a placeholder sidebar
- [x] Add `Info.plist` usage strings (§14)

**Done when**
- [x] App launches and lists fake categories in the sidebar (launches and stays up; window not visually checked)
- [x] `SiftCore` builds and tests with no SwiftUI import (37 tests pass)

---

## M2 · Safety and deletion

Build the part that can hurt users first, and test it hardest.

- [x] `SafetyGuard.validate(_:home:)` with all five checks and the protected-path list (§9)
- [x] Table-driven tests: each `Violation`, symlink escaping home, `..` traversal, `/private` aliasing, every protected path, top-level folders
- [x] `CleanEngine` with the disposal matrix for Smart / Trash / Permanent and `forcePermanent` (§10)
- [x] Per-item failures collected in `CleanReport`, batch never aborts
- [x] Cancellation between items

**Done when**
- [x] 100% branch coverage on `SafetyGuard` (measured as region coverage, since `llvm-cov` reports no branch data for Swift: 100% regions, functions and lines with `swift test --enable-code-coverage`)
- [x] Disposal tests pass for every mode × risk × `forcePermanent` combination
- [x] A test proves a protected path gets a failure and survives on disk, even when passed directly to `CleanEngine`

---

## M3 · Scan engine and Junk rules

The first real scan.

- [x] `SizeCalc` using `totalFileAllocatedSize`, no symlink following, cancellation checks (§8.2)
- [x] `ItemFinder` protocol + `PathFinder` (fixed paths and `*` globs)
- [x] `ScanEngine`: `TaskGroup` capped at ~4, `AsyncThrowingStream<ScanEvent>`, two-pass dedupe so specific rules win over `appCaches` (§8.1)
- [x] `RuleCatalog` with Junk rules: App Caches, Browser Caches, Logs, Crash Reports, Saved window state, Mail Downloads, Trash (§7.1)
- [x] `SettingsStore` on `UserDefaults` (§13) (done in M1)
- [x] `sift-cli` prints a scan as a table (`swift run sift-cli -v`). Read-only, no path to the clean engine

**Done when**
- [x] Fixture-home tests pass for each Junk rule (items, sizes, risks)
- [x] A real scan of your own Mac finishes and the totals roughly match Finder's "Get Info" (5.26 GB in 0.5–3 s; sizes match `du` exactly)
- [x] Cancelling mid-scan stops within ~1 second

---

## M4 · UI vertical slice

Scan → select → clean → report, end to end, on Junk rules.

- [x] `Sidebar` / `SidebarItem` with section totals
- [x] `CategoryView`, `GroupedItemList`, `GroupHeader` (collapsible), `ItemRow`, `RiskBadge`
- [x] `ActionBar` with selected count and size, Scan and Clean buttons
- [x] Preselection rule in `AppState.selectRecommended()` (§11.2)
- [x] `ConfirmSheet` splitting "deleted permanently" vs "moved to Trash", plus the review-items warning
- [x] `CleaningSheet` progress, `ReportSheet` with failures, automatic rescan afterward
- [x] `Engine.live()` replaces the fake in the app; `--fake` launch flag keeps the sample data (no previews: `#Preview` needs full Xcode)

**Done when**
- [x] Cleaning App Caches in Trash mode puts them in the Trash and the report numbers match (2026-10-27, on the real Mac through `AppState` + `Engine.live()`: 3 items, 44.6 MB trashed, all three listed in the Finder Trash, report equals the plan)
- [x] Review items are never preselected; selecting one shows the warning
- [x] `AppState` unit tests for preselection and phase transitions pass (moved to `SiftAppModel` target to make it testable)

---

## M5 · Apps and profiles

Know what's installed and running, and find leftovers from deleted apps.

- [x] `AppIndex`: bundle IDs from `/Applications`, `/Applications/Utilities`, `~/Applications`, `/System/Applications`, `/Volumes/*/Applications`, plus `mdfind` app-bundle query
- [x] Running IDs from `NSWorkspace.runningApplications`; mark items `isRunningApp` with "App is running" detail (§8.4)
- [x] `KnownApp` table (§7.6) and `ProfileDetector`
- [x] `ProfilePicker` on first launch; toggles write `enabledProfiles`
- [x] `Leftovers.swift`: orphan detection with prefix matching, `com.apple.*` skip, `userData` apps skipped (§8.3)
- [x] Broken Login Items: parse `~/Library/LaunchAgents/*.plist`, flag missing `Program` / `ProgramArguments[0]`

**Done when**
- [x] Orphan tests pass with a fake snapshot (prefix match, `group.` / team-ID prefixes, `com.apple` skip)
- [x] With Slack open, Slack's cache is listed but unticked (covered by tests with a stubbed running app)
- [x] First launch on a dev Mac auto-detects the Developer profile (this Mac: Everyday, Developer and AI, via Xcode/Homebrew/Ollama)

---

## M6 · Files and Full Disk Access

User-file categories, all review or caution, never preselected.

- [x] Old Installers (`.dmg .pkg .mpkg .iso .xip` in Downloads, Desktop)
- [x] Large Files (> 500 MB in Downloads, Desktop, Documents, Movies)
- [x] Old Downloads (not modified and not opened for 90 days) (§8.6)
- [x] iOS Device Backups with `Last Backup Date` from each backup's `Info.plist`
- [x] `SafetyGuard` per-rule allowlist exceptions for `MobileSync/Backup` and `Mail Downloads`
- [x] FDA detection (§8.7), `needsFDA` on categories, banner with "Open Settings" button

**Done when**
- [x] Fixture tests for the 90-day and 500 MB thresholds (just under / just over)
- [x] Without FDA, the banner shows and affected categories say some items are hidden
- [ ] *Not done in v1:* After granting FDA and rescanning, Mail Downloads and device backups appear (manual: grant Sift.app Full Disk Access. Ad-hoc signed builds may lose the grant after each rebuild)

---

## M7 · Developer rules

- [x] Xcode Build Data, Simulator cache, Device Support, Xcode Archives (§7.4); "Xcode is running" handling
- [x] Package Manager Caches as sub-items (npm, Yarn, pnpm, Bun, pip, uv, Homebrew, Cargo, Go, Gradle, Maven, CocoaPods, Composer, SwiftPM), each with its own risk and detail text
- [x] Package caches under App Caches: decided to leave them there when the Developer profile is off. They're regenerable caches either way; with the profile on they move to Package Manager Caches
- [x] Stale `node_modules`: scan the project roots, 60-day cutoff on the project's newest file, `skipDescendants` (§8.6)

**Done when**
- [x] Fixture test: a project untouched for 61 days is listed, one touched 59 days ago is not
- [x] With Xcode open, DerivedData is listed but unticked (tested with a stubbed running Xcode)
- [ ] *Not done in v1:* Test on real machines and settle the per-cache risk levels (spec §17). Not done: risks set by judgement, see spec §7.4

---

## M8 · Local AI rules

- [x] Ollama: parse manifests, refcount blobs, one item per model with only its unshared blobs (§8.5)
- [x] LM Studio models, Hugging Face cache, Other ML Caches (§7.5)
- [x] Group items by model name in `GroupedItemList`

**Done when**
- [x] Test: two models sharing a blob; the shared blob is never offered and deleting one model leaves the other working
- [x] On a Mac with Ollama, deleting a model in Trash mode then `ollama list` no longer shows it, and the remaining models still run (2026-10-27: pulled smollm:135m and smollm2:135m, trashed smollm2; `ollama list` shows only smollm, which still answers prompts; shared blobs kept)

---

## M9 · Polish

- [x] `OverviewView`: `DiskGauge` (used / free / can-free, drawn as `DiskRing`), section `Card`s, FDA banner, profile chips
- [x] Lifetime counter "Freed with Sift so far"
- [x] `SettingsView`: deletion mode, profile toggles, "Reset to Recommended", per-rule overrides (Rules tab)
- [x] "How Sift keeps you safe" screen (copy from intent.md safety rules): Settings › Safety and a sidebar link
- [x] Empty states ("Nothing to clean in the enabled areas") on Overview and each area, error states (FDA notes, failures in the report), Dark Mode check: the app always uses the light theme by design (`AppDelegate`)
- [x] App icon (`Support/AppIcon.icns`, generated by `scripts/make-icon.swift`), SF Symbols per rule
- [x] Accessibility: VoiceOver labels on rows, checkboxes, badges, area cards, sidebar and the gauge (not yet tried with VoiceOver running)

**Done when**
- [ ] *Not done in v1:* A non-technical tester can scan and clean without help, and can explain what the colours mean
- [x] Smoke test (fake engine: launch → scan → select → confirm → report) passes: `scripts/smoke-test.sh` runs the real app with `--smoke-test`. XCUITest itself needs full Xcode, which isn't installed

---

## M10 · Ship v1

- [ ] *Not done in v1:* Developer ID signing, hardened runtime, no sandbox (`scripts/release.sh` does it given `SIGN_IDENTITY`; this Mac has no Developer ID certificate, so v1 is ad-hoc signed)
- [ ] *Not done in v1:* Notarize with `notarytool`, staple, package as `.dmg` (`scripts/release.sh` builds `build/Sift-1.0.dmg`; notarizing needs a Developer ID and `NOTARY_PROFILE`)
- [ ] *Not done in v1:* Test on a clean macOS 14 VM (first launch, no FDA, permission prompts)
- [ ] *Not done in v1:* Test on a real, well-used Mac: full scan, clean in Smart mode, check that nothing in the protected list changed (2026-10-27, partly done: full scan of all areas (130 MB, 0.5 s, no false-positive leftovers), Trash-mode clean, and a before/after snapshot showing no protected folder changed. The permanent Smart-mode clean was not run: it needs the owner's go-ahead. The scan found a bug, now fixed: a running browser's cache (Brave) was preselected because browser cache folders aren't named by bundle ID; entries now name their owner app)
- [x] Switch the dev default back to Smart mode (`AppState.developmentForcesTrash = false`: cleans now follow the user's deletion mode)
- [x] Write a short README: what Sift does, how to grant FDA, how to undo (Trash)

**Done when**
- [ ] *Not done in v1:* Notarized DMG opens on another Mac without Gatekeeper warnings
- [x] No unexpected failures in the report on the real-Mac test (0 failures in the Trash-mode and Ollama cleans)

---

## Later (not v1)

- Large files on external volumes
- Intel / universal build
- Localization
- Per-rule "never show again" exclusions
