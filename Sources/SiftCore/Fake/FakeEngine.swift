import Foundation

// Canned data for previews, UI work and tests. Never touches the filesystem.

extension Engine {
    public static func fake(delay: Duration = .milliseconds(150)) -> Engine {
        Engine(scanner: FakeScanner(delay: delay), cleaner: FakeCleaner(),
               apps: FakeApps(), system: FakeSystem())
    }
}

public struct FakeScanner: Scanning {
    let delay: Duration
    public init(delay: Duration = .zero) { self.delay = delay }

    public func scan(profiles: Set<Profile>) -> AsyncThrowingStream<ScanEvent, Error> {
        let categories = FakeData.categories().filter { profiles.contains($0.rule.profile) }
        let delay = delay
        return AsyncThrowingStream { continuation in
            let task = Task {
                for (index, category) in categories.enumerated() {
                    try await Task.sleep(for: delay)
                    continuation.yield(.progress(Double(index) / Double(max(categories.count, 1)),
                                                 currentRule: category.rule.title))
                    continuation.yield(.category(category))
                }
                continuation.yield(.progress(1, currentRule: ""))
                continuation.yield(.finished(fullDiskAccess: false))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

public struct FakeCleaner: Cleaning {
    public init() {}

    public func clean(_ items: [CleanItem], mode: DeletionMode,
                      progress: @escaping @Sendable (Double) -> Void) async -> CleanReport {
        var report = CleanReport()
        for (index, item) in items.enumerated() {
            try? await Task.sleep(for: .milliseconds(40))
            switch CleanEngine.disposal(for: item, mode: mode) {
            case .permanent:
                report.deletedCount += 1
                report.deletedBytes += item.size
            case .trash:
                report.trashedCount += 1
                report.trashedBytes += item.size
            }
            progress(Double(index + 1) / Double(items.count))
        }
        return report
    }
}

public struct FakeApps: AppIndexing {
    public init() {}
    public func snapshot() async -> AppSnapshot { AppSnapshot(runningIDs: ["com.tinyspeck.slackmacgap"]) }
    public func detectProfiles() async -> Set<Profile> { [.general, .developer] }
}

public struct FakeSystem: SystemInfo {
    public init() {}
    public func disk() -> DiskInfo { DiskInfo(total: 494_000_000_000, free: 61_000_000_000) }
    public func hasFullDiskAccess() -> Bool { false }
    public func openFullDiskAccessSettings() {}
}

enum FakeData {
    static let home = URL(filePath: "/Users/fake")
    static let gb: Int64 = 1_000_000_000
    static let mb: Int64 = 1_000_000

    static func categories() -> [CleanCategory] {
        [
            make(Rule(id: "appCaches", title: "App Caches",
                      subtitle: "Temporary data apps keep in ~/Library/Caches. Apps recreate what they need. Apps that are running are left unticked.",
                      symbol: "shippingbox", section: .junk, profile: .general, risk: .safe,
                      finder: StaticFinder()),
                 [("Library/Caches/com.spotify.client", 1_400 * mb, nil, false, "Spotify"),
                  ("Library/Caches/com.tinyspeck.slackmacgap", 620 * mb, "App is running", true, "Slack"),
                  ("Library/Caches/com.microsoft.VSCode", 310 * mb, nil, false, "Visual Studio Code")]),
            make(Rule(id: "browserCaches", title: "Browser Caches",
                      subtitle: "Cached pages and images for Safari, Chrome, Firefox, Edge, Brave, Arc and Opera. Bookmarks, passwords and history are untouched.",
                      symbol: "globe", section: .junk, profile: .general, risk: .safe,
                      finder: StaticFinder()),
                 [("Library/Caches/Google/Chrome", 2 * gb, nil, false, "Chrome"),
                  ("Library/Caches/com.apple.Safari", 450 * mb, nil, false, "Safari")]),
            make(Rule(id: "logs", title: "Log Files",
                      subtitle: "Diagnostic logs written by apps and the system.",
                      symbol: "doc.text", section: .junk, profile: .general, risk: .safe,
                      finder: StaticFinder()),
                 [("Library/Logs/JetBrains", 180 * mb, nil, false, nil)]),
            make(Rule(id: "installers", title: "Old Installers",
                      subtitle: "Disk images and installer packages (.dmg, .pkg, .iso, .xip) in Downloads and Desktop.",
                      symbol: "archivebox", section: .files, profile: .general, risk: .caution,
                      finder: StaticFinder()),
                 [("Downloads/Docker.dmg", 900 * mb, nil, false, nil),
                  ("Downloads/Zoom.pkg", 120 * mb, nil, false, nil)]),
            make(Rule(id: "orphans", title: "Leftovers of Uninstalled Apps",
                      subtitle: "Preferences, containers and support folders whose app can't be found anywhere on this Mac.",
                      symbol: "questionmark.folder", section: .apps, profile: .general, risk: .review,
                      finder: StaticFinder()),
                 [("Library/Application Support/com.example.OldApp", 240 * mb, "No matching app installed", false, nil)]),
            make(Rule(id: "xcodeDerivedData", title: "Xcode Build Data",
                      subtitle: "DerivedData, Xcode and Simulator caches. Rebuilt on the next build.",
                      symbol: "hammer", section: .developer, profile: .developer, risk: .safe,
                      finder: StaticFinder()),
                 [("Library/Developer/Xcode/DerivedData/MyApp-abc", 6 * gb, nil, false, nil)]),
            make(Rule(id: "ollamaModels", title: "Ollama Models",
                      subtitle: "Each downloaded model with the files only it uses. Pull it again with `ollama pull`.",
                      symbol: "cube", section: .localAI, profile: .localAI, risk: .review,
                      finder: StaticFinder()),
                 [(".ollama/models/llama3.1:8b", 4_700 * mb, nil, false, nil)]),
        ]
    }

    private static func make(_ rule: Rule,
                             _ rows: [(String, Int64, String?, Bool, String?)]) -> CleanCategory {
        let items = rows.map { path, size, detail, running, group in
            CleanItem(rule: rule,
                      candidate: Candidate(url: home.appending(path: path), detail: detail,
                                           group: group, isRunningApp: running),
                      size: size, modified: .now.addingTimeInterval(-86_400 * 30))
        }
        return CleanCategory(rule: rule, items: items)
    }
}
