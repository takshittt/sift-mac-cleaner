# Sift — Technical Spec

Status: final (v1, closed 2026-10-26) · Audience: engineers building Sift · Companion to [intent.md](intent.md)

This document defines the system design, tech stack, internal APIs and wiring for Sift, a native macOS disk cleaner (SwiftUI, arm64, macOS 14+, no third-party frameworks).

---

## 1. Goals and non-goals

**Goals**
- Find regenerable and forgotten data in known locations, size it, classify it by risk, and remove what the user selects.
- Safety is enforced in code at deletion time, not only by which rules exist.
- Fully offline, single app bundle, no account, no telemetry.

**Non-goals**
- No background agent, menu-bar daemon, scheduled cleaning, "speed up" or malware features.
- No privileged helper / root operations. Sift only touches files the logged-in user owns, inside `$HOME`.
- No App Store distribution (sandbox would block the scan locations).

---

## 2. Architecture

"Frontend" and "backend" are two layers inside one process. There is no server. The backend is a Swift package (`SiftCore`) with no UI imports; the frontend is the SwiftUI app target that talks to it only through the protocols in §6.

```
┌──────────────────────────── Sift.app (single process) ────────────────────────────┐
│                                                                                    │
│  FRONTEND  (SwiftUI, @MainActor)                                                   │
│  ┌──────────┐  ┌─────────────┐  ┌────────────┐  ┌────────────────────────────┐     │
│  │ Sidebar  │  │OverviewView │  │CategoryView│  │ Confirm/Cleaning/Report    │     │
│  └────┬─────┘  └──────┬──────┘  └─────┬──────┘  │ sheets · SettingsView      │     │
│       └───────────────┴───────┬───────┴─────────┴────────────┬───────────────┘     │
│                               ▼                              │                     │
│                      AppState (@Observable)  ◄───────────────┘                     │
│                 phase · categories · selection · report · settings                 │
│                               │  async calls / AsyncStream<ScanEvent>              │
│ ─────────────────────────────-┼──────────────────────────────────────────────────  │
│  BACKEND  (SiftCore, actors, no SwiftUI)                                           │
│                               ▼                                                    │
│   ┌────────────┐   ┌──────────────┐   ┌──────────────┐   ┌────────────────┐        │
│   │ScanEngine  │──►│ RuleCatalog  │   │  AppIndex    │   │ProfileDetector │        │
│   │ (actor)    │   │ [Rule]       │   │ installed /  │   │                │        │
│   └─────┬──────┘   └──────────────┘   │ running apps │   └────────────────┘        │
│         │ uses                         └──────────────┘                            │
│         ▼                                                                          │
│   ┌────────────┐   ┌──────────────┐   ┌──────────────┐   ┌────────────────┐        │
│   │ SizeCalc   │   │ SafetyGuard  │◄──│ CleanEngine  │   │ SettingsStore  │        │
│   └────────────┘   └──────────────┘   │ (actor)      │   │ (UserDefaults) │        │
│                                       └──────┬───────┘   └────────────────┘        │
│                                              ▼                                     │
│                              FileManager · NSWorkspace · Process(mdfind)           │
└────────────────────────────────────────────────────────────────────────────────────┘
```

**Rules of the boundary**
- `SiftCore` is pure Foundation + AppKit-free where possible (`NSWorkspace` is isolated behind `AppIndex`), so it can be unit-tested and driven by a CLI.
- All filesystem work runs off the main actor. The UI only ever receives value types (`struct`, `Sendable`).
- Every deletion goes through `SafetyGuard.validate(_:)`. There is no other code path to `FileManager.removeItem` / `trashItem`.

---

## 3. Tech stack

| Concern | Choice | Notes |
|---|---|---|
| Language | Swift 6 (strict concurrency) | Native, first-party UI stack (Swift + SwiftUI) |
| UI | SwiftUI, `NavigationSplitView` | AppKit only via `NSApplicationDelegateAdaptor` for app lifecycle and `NSWorkspace` |
| State | Observation framework (`@Observable`) | macOS 14 minimum makes this available |
| Concurrency | async/await, actors, `TaskGroup`, `AsyncStream` | Cancellable scans |
| Filesystem | `FileManager`, `URL.resourceValues` | `totalFileAllocatedSizeKey`, `contentModificationDateKey`, `contentAccessDateKey`, `isPackageKey`, `isSymbolicLinkKey` |
| App discovery | `/Applications`, `/Volumes/*/Applications`, Spotlight via `mdfind "kMDItemContentTypeTree == 'com.apple.application-bundle'"` | Bundle IDs read from each `Info.plist` |
| Running apps | `NSWorkspace.shared.runningApplications` | |
| Settings | `UserDefaults` via a typed `SettingsStore` | |
| Icons | SF Symbols only | e.g. `internaldrive`, `hammer`, `cube`, `memorychip`, `envelope`, `iphone`, `archivebox`, `shippingbox`, `checkmark.shield` |
| Build | Single SwiftPM package (`swift build`); `scripts/build-app.sh` wraps the executable into `build/Sift.app` | Works with Command Line Tools only, no Xcode project. No third-party dependencies |
| Tests | Swift Testing (`@Test`) for `SiftCore`, XCUITest smoke test | Fixture home directory in a temp dir |
| Distribution | Developer ID signed, hardened runtime, notarized, shipped as `.dmg` | Not sandboxed |
| Minimum OS / arch | macOS 14.0, Apple Silicon (universal optional) | |

---

## 4. Project layout

```
Mac cleaner/                     # repo root = one SwiftPM package
├── Package.swift                # targets: SiftCore (lib), Sift (app), SiftCoreTests
├── Sources/
│   ├── Sift/                    # FRONTEND target (SwiftUI executable)
│   │   ├── SiftApp.swift        # @main, WindowGroup, Settings scene; `--fake` uses sample data
│   │   ├── AppDelegate.swift
│   │   └── Views/               # ContentView, Sidebar, CategoryView, ActionBar, Sheets, … (see §11.1)
│   ├── SiftAppModel/            # AppState (@Observable, no SwiftUI) so it can be unit-tested
│   └── SiftCore/                # BACKEND target
│       ├── Model/               # Profile, Risk, Rule, CleanItem, CleanCategory, ScanContext, …
│       ├── Engine/              # Engine + protocols (§6)
│       ├── Catalog/             # RuleCatalog + one file per section (M3+)
│       ├── Scan/                # ScanEngine, SizeCalc, finders (M3+)
│       ├── Apps/                # AppIndex, ProfileDetector, Leftovers.swift (M5)
│       ├── Clean/               # SafetyGuard, CleanEngine
│       ├── Settings/            # SettingsStore
│       └── Fake/                # Engine.fake() for previews and UI work
├── Tests/SiftCoreTests/
├── Support/Info.plist           # copied into the bundle by build-app.sh
└── scripts/build-app.sh         # builds build/Sift.app and ad-hoc signs it
```

`@State` in recent SDKs is a macro whose plugin ships only with full Xcode, so views use `@ViewState`, a typealias for `SwiftUI.State` (see `Sources/Sift/Views/ViewState.swift`).

---

## 5. Domain model (`SiftCore/Model`)

```swift
public enum Profile: String, CaseIterable, Codable, Sendable {
    case general      // caches, logs, browsers, leftovers
    case developer    // Xcode, npm, Homebrew, stale node_modules
    case localAI      // Ollama, LM Studio, Hugging Face models
}

public enum Risk: String, Codable, Sendable, Comparable {
    case safe         // green: rebuilt automatically. Preselected.
    case caution      // yellow: safe, but re-download / rebuild / re-sign-in
    case review       // red: may contain user data. Never preselected.
}

public enum SectionKind: String, CaseIterable, Sendable {
    case junk         // system & app junk
    case files        // installers, large files, old downloads, device backups
    case apps         // Apps & Leftovers
    case developer
    case localAI
}

public enum DeletionMode: String, Codable, Sendable {
    case smart        // default
    case trash        // "Always move to Trash"
    case permanent    // "Always delete permanently"
}

/// How a rule's items should be removed under `.smart`.
public enum Disposal: Sendable { case permanent, trash }

public struct Rule: Sendable, Identifiable {
    public let id: String                 // "xcode.derivedData"
    public let title: String              // "Xcode Build Data"
    public let subtitle: String           // plain-language explanation shown in UI
    public let symbol: String             // SF Symbol
    public let section: SectionKind
    public let profile: Profile
    public let risk: Risk
    public let defaultOn: Bool            // preselected when risk == .safe
    public let disposal: Disposal         // what .smart does
    public let forcePermanent: Bool       // e.g. emptying ~/.Trash: trashing is meaningless
    public let needsFDA: Bool             // path hidden without Full Disk Access
    public let broad: Bool                // covers a whole area; scanned after specific rules (§8.1)
    public let finder: any ItemFinder     // returns FinderResult { candidates, denied } (see §8)
}

public struct CleanItem: Sendable, Identifiable, Hashable {
    public let id: String                 // stable: rule.id + normalized path
    public let ruleID: String
    public let url: URL
    public let name: String
    public let detail: String?            // e.g. "Xcode is running", "No matching app installed"
    public let size: Int64                // allocated bytes
    public let modified: Date?
    public let risk: Risk                 // may be raised above rule.risk (never lowered)
    public let isRunningApp: Bool         // forces preselect = false
    public let group: String?             // grouping key for GroupedItemList (e.g. app name, model name)
}

public struct CleanCategory: Sendable, Identifiable {
    public let rule: Rule
    public var items: [CleanItem]
    public var total: Int64 { items.reduce(0) { $0 + $1.size } }
    public var needsFDA: Bool             // some candidates were unreadable
    public var id: String { rule.id }
}

public struct CleanReport: Sendable {
    public var deletedCount = 0, deletedBytes: Int64 = 0
    public var trashedCount = 0, trashedBytes: Int64 = 0
    public var failures: [Failure] = []
    public struct Failure: Sendable { public let item: CleanItem; public let message: String }
}

public enum Phase: Sendable, Equatable {
    case idle, scanning(progress: Double), ready, cleaning(progress: Double), done
}

public struct ScanContext: Sendable {        // snapshot passed to every finder
    public let home: URL
    public let now: Date
    public let apps: AppSnapshot                // installed and running bundle IDs
    public let enabledProfiles: Set<Profile>
}
```

---

## 6. Internal API (backend ⇄ frontend contract)

The frontend depends only on these protocols. Live implementations are injected at app start; tests and SwiftUI previews inject fakes.

```swift
public protocol Scanning: Sendable {
    /// Streams per-category results as they complete. Cancel the Task to stop.
    func scan(profiles: Set<Profile>) -> AsyncThrowingStream<ScanEvent, Error>
}

public enum ScanEvent: Sendable {
    case progress(Double, currentRule: String)
    case category(CleanCategory)
    case finished(fullDiskAccess: Bool)
}

public protocol Cleaning: Sendable {
    func clean(_ items: [CleanItem], mode: DeletionMode,
               progress: @Sendable (Double) -> Void) async -> CleanReport
}

public protocol AppIndexing: Sendable {
    func snapshot() async -> AppSnapshot
    func detectProfiles() async -> Set<Profile>
}

public protocol SystemInfo: Sendable {
    func disk() -> DiskInfo                   // total / free / used for DiskGauge
    func hasFullDiskAccess() -> Bool
    func openFullDiskAccessSettings()         // x-apple.systempreferences:…?Privacy_AllFiles
}

public protocol SettingsStoring: AnyObject {
    var mode: DeletionMode { get set }
    var enabledProfiles: Set<Profile> { get set }
    var detectedProfiles: Set<Profile> { get set }
    var lifetimeFreed: Int64 { get set }
    var ruleOverrides: [String: Bool] { get set }   // user toggled a rule's default
    func resetToRecommended()
}

public struct Engine: Sendable {               // composition root handed to AppState
    public let scanner: any Scanning
    public let cleaner: any Cleaning
    public let apps: any AppIndexing
    public let system: any SystemInfo
    public static func live() -> Engine
}
```

### Error model
- Scan errors per path (permission denied, vanished file) are swallowed and folded into `CleanCategory.needsFDA` or skipped. The scan as a whole only throws on cancellation.
- Clean errors are collected per item in `CleanReport.failures` and never abort the batch.

---

## 7. Rule catalog

All rules are declared in code in `Catalog/` as static data. Paths are relative to `$HOME` unless absolute. Glob segments (`*`) are expanded by the finder.

### 7.1 Junk (`profile: .general`)

| id | Title | Paths | Risk | Default | Smart disposal |
|---|---|---|---|---|---|
| `appCaches` | App Caches | `~/Library/Caches/*` (minus entries owned by other rules) | safe | on | permanent |
| `browserCaches` | Browser Caches | Safari (`~/Library/Caches/com.apple.Safari`, container caches), Chrome, Firefox/Mozilla, Edge, Brave, Arc (`company.thebrowser.Browser`), Opera | safe | on | permanent |
| `logs` | Log Files | `~/Library/Logs` | safe | on | permanent |
| `crashReports` | Crash Reports | `~/Library/Logs/DiagnosticReports`, `~/Library/Application Support/CrashReporter` | safe | on | permanent |
| `savedState` | Saved window state | `~/Library/Saved Application State` | safe | on | permanent |
| `mailDownloads` | Mail Downloads | `~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads` (FDA) | caution | off | trash |
| `trash` | Trash | `~/.Trash` | safe | on | permanent (`forcePermanent`) |

### 7.2 Apps & Leftovers (`profile: .general`)

| id | Title | Source | Risk | Default |
|---|---|---|---|---|
| `orphans` | Leftovers of Uninstalled Apps | Bundle-ID-named entries in `Preferences`, `Application Support`, `Containers`, `Group Containers`, `Application Scripts`, `Caches`, `HTTPStorages`, `WebKit`, `Cookies`, `Saved Application State` with no installed match (§8.3) | review | off |
| `brokenLoginItems` | Broken Login Items | `~/Library/LaunchAgents/*.plist` whose `Program`/`ProgramArguments[0]` doesn't exist | caution | off |

### 7.3 Files (`profile: .general`)

| id | Title | Criteria | Risk | Default |
|---|---|---|---|---|
| `installers` | Old Installers | `.dmg .pkg .mpkg .iso .xip` in `~/Downloads`, `~/Desktop` | caution | off |
| `largeFiles` | Large Files | files > 500 MB in `Downloads, Desktop, Documents, Movies` | review | off |
| `oldDownloads` | Old Downloads | top-level items in `~/Downloads` not modified **and** not opened for 90 days | review | off |
| `deviceBackups` | iOS Device Backups | `~/Library/Application Support/MobileSync/Backup/*` (FDA); label with `Last Backup Date` from `Info.plist` | review | off |

### 7.4 Developer (`profile: .developer`)

| id | Title | Paths | Risk | Default |
|---|---|---|---|---|
| `xcodeDerivedData` | Xcode Build Data | `~/Library/Developer/Xcode/DerivedData`, `~/Library/Caches/com.apple.dt.Xcode` | safe (preselect off if Xcode running) | on |
| `simulatorCache` | Simulator cache | `~/Library/Developer/CoreSimulator/Caches` | safe | on |
| `deviceSupport` | iOS / watchOS Device Support | `~/Library/Developer/Xcode/{iOS,watchOS,tvOS,visionOS} DeviceSupport/*` | caution | off |
| `xcodeArchives` | Xcode Archives | `~/Library/Developer/Xcode/Archives` | review | off |
| `pkgCaches` | Package Manager Caches | npm `~/.npm/_cacache`, Yarn `~/Library/Caches/Yarn`, pnpm `~/Library/pnpm/store`, Bun `~/.bun/install/cache`, pip `~/Library/Caches/pip`, uv `~/.cache/uv`, Homebrew `~/Library/Caches/Homebrew`, Cargo `~/.cargo/registry/cache`, Go `~/Library/Caches/go-build`, Gradle `~/.gradle/caches`, Maven `~/.m2/repository`, CocoaPods, Composer, SwiftPM | caution | off\* |
| `staleNodeModules` | Stale node_modules | `node_modules` under `~/Projects ~/Developer ~/Code ~/Coding ~/GitHub ~/repos ~/workspace ~/Documents ~/Desktop` whose project wasn't modified for 60 days | caution | off |

\* Decided per sub-item: npm, Yarn, pnpm cache, Bun, pip, uv, Homebrew, Cargo downloads, Go, CocoaPods, Composer and SwiftPM are `safe` (they only cost a re-download). The pnpm store ("Projects re-link on next install"), Gradle and Maven ("Offline builds need a re-download") are `caution`. Final for v1: set by judgement, not measured on real machines.

Xcode Build Data, Simulator Caches, Device Support and Archives name an owner app (`Rule.owner`). While Xcode (or Simulator) runs, all their items are marked "Xcode is running" and left unticked.

With the Developer profile off, caches under `~/Library/Caches` (Homebrew, pnpm, Xcode) stay in App Caches as ordinary regenerable caches.

### 7.5 Local AI (`profile: .localAI`)

| id | Title | Paths | Risk | Default |
|---|---|---|---|---|
| `ollamaModels` | Ollama Models | `~/.ollama/models` (one item per model, §8.5) | review | off |
| `lmStudioModels` | LM Studio Models | `~/.lmstudio/models`, `~/.cache/lm-studio/models` | review | off |
| `huggingFace` | Hugging Face Cache | one item per `~/.cache/huggingface/hub/{models,datasets,spaces}--*`, named `org/name`, plus legacy `transformers`. Never the login `token` | caution | off |
| `otherML` | Other ML Caches | `~/.cache/torch`, `~/.cache/whisper`, `~/.cache/clip`, `~/.keras/datasets`, `~/.keras/models` (not `keras.json` settings) | caution | off |

### 7.6 Known app table (`KnownApp`)

Used for profile detection and for marking "may contain your own files" folders. Entry shape: `bundleIDs`, `appFileNames`, `bins` (e.g. `/opt/homebrew/bin/ollama`), `evidence` (home-relative paths), `profile`, `userData` (home-relative folders that may hold the user's own files).
Seed entries: Xcode, VS Code, Cursor, Android Studio, Docker, Postman, Ollama, LM Studio, Jan, GPT4All (nomic.ai), ChatGPT, Slack, Discord, Teams, Zoom, Notion, Spotify, Steam, Dropbox, OneDrive (both variants), Google Drive, Chrome, Firefox.
Any item inside a `userData` folder (sync folders, models, games) is raised to `review` with the detail "May contain your own files", so it is never preselected.

---

## 8. Backend algorithms

### 8.1 Scan pipeline (`ScanEngine`)
1. `ctx = ScanContext(home, now, apps.snapshot(), enabledProfiles)`.
2. `rules = catalog.rules.filter { enabledProfiles.contains($0.profile) }`.
3. `withThrowingTaskGroup` over rules, concurrency capped at ~4 (disk-bound). Each task: `finder.candidates(ctx)` → `SafetyGuard.filterScan` → `SizeCalc` → build `CleanCategory` → yield `.category`.
4. Dedupe: each rule has a `pass` number. Pass 0 rules are specific; each later pass skips every path an earlier pass found (and splits a folder that *contains* a claimed path into its children). Current passes: 0 = specific rules and Old Installers; 1 = App Caches, Log Files, Large Files; 2 = Old Downloads. So a big old `.dmg` in Downloads is listed once, as an installer.
5. Yield `.finished(fullDiskAccess:)`.

### 8.2 Sizing (`SizeCalc`)
- Enumerate with `FileManager.enumerator(at:includingPropertiesForKeys:[.totalFileAllocatedSizeKey, .isSymbolicLinkKey], options: [])`, sum `totalFileAllocatedSize`. Don't follow symlinks.
- Hard-link/APFS-clone overcount is acceptable; report as "about".
- Check `Task.isCancelled` every N entries.

### 8.3 Orphan detection (`Leftovers.swift`)
1. Installed set = bundle IDs from `/Applications` (and one folder deeper, e.g. `Setapp/`), `/Applications/Utilities`, `~/Applications`, `/System/Applications`, `/Volumes/*/Applications`, plus Spotlight (`mdfind` app-bundle query) to catch apps elsewhere.
2. Locations: `Preferences`, `Application Support`, `Containers`, `Group Containers`, `Application Scripts`, `HTTPStorages`, `WebKit`, `Cookies`. Not `Caches` or `Saved Application State`: other rules already list those.
3. A name counts only if it clearly is a bundle ID: strip `.plist` / `.binarycookies`, a 10-character team ID prefix and a `group.` / `groups.` / `systemgroup.` prefix; then 3+ dotted parts, or 2 with a familiar first part (`com.docker`). Files must be `.plist` or `.binarycookies`.
4. It is an orphan only if no installed ID equals it or is a dotted prefix of it (either way). For shared locations (everything except `Containers` and `Application Scripts`), any installed app from the same vendor (`com.microsoft.*`) also counts as a match, because companies share these folders between apps.
5. Always skip: running apps; known apps with user data; system or shared-framework vendors (`com.apple`, `org.cups`, `com.openssh`, `org.sparkle-project`, `com.qtproject`, ...); and everything if the installed-app list came back empty.
6. One item per folder or file, named by location ("Preferences", "Container", ...) and grouped by bundle ID. Detail: "No matching app installed". Risk: `review`.

On the author's Mac this finds 38 leftovers (72 MB, mostly an old Excel container) with no false positives found.

### 8.4 Running-app protection
`AppSnapshot.runningIDs` from `NSWorkspace.runningApplications`. Any item whose bundle ID / known app is running gets `isRunningApp = true`, detail "App is running" (or "Xcode is running"), and is not preselected. If many cache items are skipped this way, the category shows: "Apps that are open often hold their cache files. Quit them, or grant Full Disk Access, and scan again."

### 8.5 Ollama models
Walk `~/.ollama/models/manifests/**`. Each manifest is JSON whose `config.digest` and `layers[].digest` name files in `blobs/` (`sha256:<hex>` → `sha256-<hex>`). A manifest that isn't valid JSON, or has any digest that isn't exactly `sha256:` plus 64 characters, is skipped.

One `CleanItem` per model: the manifest is the item's `url`, and the blobs **only that model** uses (refcount == 1) are its `additionalURLs`. Shared blobs are never offered. Name like `ollama list`: `llama3.1:8b`, `user/model:tag`, `hf.co/org/repo:Q4`. Detail: "Pull it again with `ollama pull <name>`", or "Keeps N files another model still uses".

**Multi-file items.** `CleanItem.additionalURLs` lists extra files removed with the item. The scanner and the clean engine run `SafetyGuard` on every file; if any one fails, nothing of that item is touched. The main file goes first, so a half-finished removal never leaves a manifest pointing at missing blobs.

### 8.6 Time-based finders
- `oldDownloads`: top-level items in Downloads where `max(modified, added to folder, Spotlight kMDItemLastUsedDate) < now - 90d`. Not the file access time: background indexing and backups bump it, so almost nothing would ever look old. The added date matters because downloads keep the server's modification date.
- `installers` / `largeFiles`: walk the folders with `.skipsHiddenFiles` and `.skipsPackageDescendants`, skipping `node_modules`, `.git`, `Pods`, `DerivedData`, `.build`. Depth limits: 3 for installers, 6 for large files. Large files counts the logical size of regular files only.
- `staleNodeModules`: walk the project roots (depth ≤ 5, hidden folders skipped). For each `node_modules`, the project is its parent folder; the project's age is the newest modification of the folder and its files two levels deep, ignoring `node_modules` and hidden files. Older than 60 days → listed, named after the project. Never descends into `node_modules`, so nested ones aren't listed separately.

### 8.7 Full Disk Access detection
Attempt `FileManager.contentsOfDirectory` on a TCC-protected path (e.g. `~/Library/Safari`). Success ⇒ FDA granted. Rules with `needsFDA` that hit `EPERM` set `category.needsFDA = true`.

---

## 9. Safety (`SafetyGuard`)

Called twice: when scanning (to filter candidates) and **again immediately before each delete** (the authoritative check). A failed check produces a `CleanReport.Failure`, never a deletion.

```swift
public enum SafetyGuard {
    public static func validate(_ url: URL, home: URL) -> Result<URL, Violation>
}
public enum Violation: Error { case notNormalised, outsideHome, resolvesOutsideHome, protected, isHomeOrTopLevel }
```

Checks, in order:
1. **Normalised**: `url.standardizedFileURL.path == url.path` and no `..` components → else `notNormalised` ("Path is not normalised").
2. **Inside home**: path has prefix `home + "/"` → else `outsideHome`.
3. **Resolves inside home**: `resolvingSymlinksInPath()` still inside home (handle `/private` prefix) → else `resolvesOutsideHome`.
4. **Not a top-level folder**: never `~`, `~/Library`, `~/Documents`, `~/Desktop`, `~/Downloads`, `~/Movies`, `~/Music`, `~/Pictures`, `~/Public`, `~/Sites` themselves.
5. **Not protected**: deny if path is or is inside any of:
   `Library/Keychains`, `Library/Mail`, `Library/Messages`, `Library/Safari` (data, not caches), `Library/Mobile Documents`, `Library/Application Support/CloudDocs`, `Library/Application Support/AddressBook`, `Library/Application Support/Knowledge`, `Library/Application Support/com.apple.TCC`, `Library/Calendars`, `Library/Contacts`, `Library/Accounts`, `Library/Fonts`, `Library/Preferences/ByHost`, `Library/Group Containers/group.com.apple*`, `Pictures/Photos Library.photoslibrary`, `Documents` (except explicit `largeFiles` / `staleNodeModules` items), `~/Library/CloudStorage/*`, `~/Dropbox`, `~/OneDrive*`.
   Explicit allowlist exceptions (e.g. `MobileSync/Backup`, `Mail Downloads`) are named per rule, not by loosening the denylist.

Unit tests must cover each violation, including symlink escape and `..` traversal.

---

## 10. Cleaning (`CleanEngine`)

```
for item in items (sequential, cancellable between items):
    url = SafetyGuard.validate(item.url) or record failure
    disposal = switch mode {
        .permanent: .permanent
        .trash:     rule.forcePermanent ? .permanent : .trash
        .smart:     rule.forcePermanent ? .permanent : (item.risk == .safe ? rule.disposal : .trash)
    }
    .permanent → FileManager.removeItem(at:)         → deletedCount/Bytes
    .trash     → FileManager.trashItem(at:resultingItemURL:) → trashedCount/Bytes
    error      → failures.append
    progress(i / n)
settings.lifetimeFreed += report.deletedBytes   // trashed bytes count once the Trash rule empties them
```

Rationale for Smart mode: moving a cache to the Trash frees nothing, so regenerable `safe` items are deleted for real. Anything that might hold user data goes to the Trash so it can be undone.

---

## 11. Frontend

### 11.1 Screens

| View | Purpose |
|---|---|
| `ContentView` | `NavigationSplitView`: `Sidebar` + detail |
| `Sidebar` | Overview, then one `SidebarItem` per enabled `SectionKind` with its total size |
| `OverviewView` | `DiskGauge` (used/free + "can free" overlay), one `Card` per section, "Freed with Sift so far: X", FDA banner, profile chips |
| `ProfilePicker` | "What do you use this Mac for?". Shows detected profiles preselected, toggles write `enabledProfiles`. Shown on first launch and from Settings |
| `CategoryView` | Rule title + subtitle, `RiskBadge`, `GroupedItemList` (`GroupHeader` per `item.group`, `ItemRow` with checkbox, name, detail, size, age); collapsible groups |
| `ActionBar` | Bottom bar: "N items · X GB selected", Scan / Clean buttons |
| `ConfirmSheet` | Summary split into "will be deleted permanently" vs "will be moved to the Trash"; extra warning if selection contains `review` items |
| `CleaningSheet` | Progress during `.cleaning` |
| `ReportSheet` | Freed / trashed / failures ("could not be removed"), reminder to empty Trash |
| `SettingsView` | Tabs: General (deletion mode, profile toggles, lifetime total, "Reset to Recommended"), Rules (which green rules are ticked by default), Safety ("How Sift keeps you safe", also a sheet from the sidebar) |

### 11.2 State (`AppState`)

```swift
@MainActor @Observable final class AppState {
    var phase: Phase = .idle
    var categories: [CleanCategory] = []
    var selection: Set<CleanItem.ID> = []
    var collapsedGroups: Set<String> = []
    var report: CleanReport?
    var showConfirm = false
    var fullDiskAccess = true
    var disk: DiskInfo
    let settings: SettingsStore
    private let engine: Engine
    private var scanTask: Task<Void, Never>?

    func onLaunch() async        // detect profiles (first run → ProfilePicker), read disk, scan
    func scan()                  // cancel previous, consume ScanEvent stream
    func cancelScan()
    func toggle(_ id: CleanItem.ID)
    func selectRecommended()     // risk == .safe && defaultOn && !isRunningApp
    func requestClean()          // showConfirm = true
    func clean() async           // engine.cleaner.clean → report → rescan
}
```

Selection rule, enforced in `AppState` not views: an item is preselected only if `risk == .safe`, its rule's effective default is on, and `!isRunningApp`.

---

## 12. Wiring

### 12.1 Startup
```
SiftApp.init
  └─ engine = Engine.live()
  └─ state  = AppState(engine, SettingsStore(.standard))
ContentView.task { await state.onLaunch() }
  ├─ apps.detectProfiles() → settings.detectedProfiles
  │    first run: enabledProfiles = detected, present ProfilePicker
  ├─ system.disk(), system.hasFullDiskAccess()
  └─ scan()
```

### 12.2 Scan
```
View ──scan()──► AppState ──scanner.scan(profiles)──► ScanEngine
                    ▲                                     │ TaskGroup over rules
                    │◄──── .progress / .category ─────────┤  finder → SafetyGuard → SizeCalc
                    │◄──── .finished(fda) ────────────────┘
   phase=.scanning(p) … categories.append … selectRecommended() … phase=.ready
```

### 12.3 Clean
```
ActionBar "Clean" → requestClean() → ConfirmSheet
  confirm → phase=.cleaning → cleaner.clean(selectedItems, settings.mode, progress)
          → per item: SafetyGuard.validate → remove/trash
          → report → settings.lifetimeFreed += … → ReportSheet → scan()
```

### 12.4 Settings → engine
`SettingsStore` changes don't touch in-flight work. Profile or rule toggles take effect on the next scan ("Changes apply on the next scan").

---

## 13. Persistence (UserDefaults keys)

| Key | Type | Default |
|---|---|---|
| `mode` | String (`DeletionMode`) | `smart` |
| `enabledProfiles` | [String] | detected on first run |
| `detectedProfiles` | [String] | — |
| `lifetimeFreed` | Int64 | 0 |
| `ruleOverrides` | [String: Bool] | empty |
| `hasCompletedOnboarding` | Bool | false |

No files on disk besides defaults. No logs containing user paths.

---

## 14. Permissions and distribution

- **Info.plist usage strings**: `NSDesktopFolderUsageDescription`, `NSDocumentsFolderUsageDescription`, `NSDownloadsFolderUsageDescription`, `NSRemovableVolumesUsageDescription` (written for Sift).
- **Full Disk Access**: optional. Banner explains what's hidden without it (Safari data, Mail downloads, device backups, some containers) and opens `x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles`.
- **Signing**: Developer ID Application, hardened runtime, no sandbox, notarized with `notarytool`, stapled DMG. `scripts/release.sh` does all of it given `SIGN_IDENTITY` and `NOTARY_PROFILE`; without them it builds an ad-hoc signed DMG.
- **Icon**: `Support/AppIcon.icns`, generated by `scripts/make-icon.swift`.
- Bundle ID: `com.<org>.sift`.

---

## 15. Testing

| Layer | What |
|---|---|
| `SafetyGuard` | Table-driven tests for every violation, symlinks, `..`, `/private` aliasing, every protected path |
| Finders | Build a fake `$HOME` in a temp dir with fixture trees (old/new mtimes, fake manifests, fake LaunchAgents); assert items, risks, sizes |
| Orphans | Fake `AppSnapshot` with installed IDs; assert prefix matching and `com.apple` skip |
| Ollama | Two models sharing a blob → shared blob never listed |
| CleanEngine | Each `DeletionMode` × risk × `forcePermanent` → expected disposal; failures don't abort |
| AppState | Fake `Engine`; preselection rule; running app never preselected; review warning |
| UI | Smoke test: `scripts/smoke-test.sh` launches the real app with `--smoke-test` (fake engine, throwaway settings) and checks scan, select, confirm, clean, report. XCUITest needs full Xcode |

`ScanContext.home` is always injected, so **no test touches the real home folder.**

---

## 16. Build order

1. **Skeleton**: Xcode project, `SiftCore` package, `Engine` protocols, fake engine, empty `ContentView` running on fakes.
2. **Safety first**: `SafetyGuard` + full test suite, `CleanEngine` with deletion modes.
3. **Scan core**: `ScanEngine`, `SizeCalc`, simple path-based finder, Junk rules (§7.1).
4. **UI vertical slice**: Sidebar → CategoryView → ActionBar → Confirm/Cleaning/Report on real Junk rules.
5. **Apps**: `AppIndex`, running-app protection, `ProfileDetector`, `ProfilePicker`, orphan + broken login item rules.
6. **Files**: installers, large files, old downloads, device backups; FDA detection and banner.
7. **Developer** rules incl. stale `node_modules`.
8. **Local AI** rules incl. Ollama refcounting.
9. **Polish**: Overview + DiskGauge, lifetime counter, Settings, safety info screen, icons.
10. **Ship**: signing, notarization, DMG, test on a clean macOS 14 VM and on a real used Mac with `trash` mode first.

---

## 17. Decisions (formerly open questions)

- Package-manager cache risks (§7.4 footnote): kept as set by judgement for v1.
- `/Volumes/*` is used only for app discovery. Large files on external drives are deferred (see plan.md, Later).
- Apple Silicon only. A universal (Intel) build is deferred.
- English only for v1.
