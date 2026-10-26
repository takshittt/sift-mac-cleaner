import Foundation

// Spec §7.1: everyday junk, profile `.general`.

extension RuleCatalog {
    static let mailDownloadsPath = "Library/Containers/com.apple.mail/Data/Library/Mail Downloads"

    /// Caches that look regenerable but back system services (iCloud, account
    /// sign-in, Sift itself). Never offered by App Caches.
    static let appCacheExclusions: Set<String> = [
        "com.apple.bird", "CloudKit", "com.apple.cloudkit", "com.apple.akd",
        "com.apple.ap.adprivacyd", "FamilyCircle", "com.takshitsaini.sift",
    ]

    static let safari = OwnerApp("Safari", "com.apple.Safari")
    static let firefox = OwnerApp("Firefox", "org.mozilla.firefox", "org.mozilla.nightly",
                                  "org.mozilla.firefoxdeveloperedition")

    public static let junk: [Rule] = [
        Rule(id: "browserCaches", title: "Browser Caches",
             subtitle: "Cached pages and images for Safari, Chrome, Firefox, Edge, Brave, Arc and Opera. Bookmarks, passwords and history are untouched.",
             symbol: "globe", section: .junk, profile: .general, risk: .safe, needsFDA: true,
             finder: PathFinder([
                .init("Library/Caches/com.apple.Safari", .itself, group: "Safari", owner: safari),
                .init("Library/Containers/com.apple.Safari/Data/Library/Caches", .children, group: "Safari", owner: safari),
                .init("Library/Caches/Google/Chrome", .itself, group: "Chrome",
                      owner: OwnerApp("Chrome", "com.google.Chrome")),
                .init("Library/Caches/Firefox", .itself, group: "Firefox", owner: firefox),
                .init("Library/Caches/Mozilla", .itself, group: "Firefox", owner: firefox),
                .init("Library/Caches/Microsoft Edge", .itself, group: "Edge",
                      owner: OwnerApp("Edge", "com.microsoft.edgemac")),
                .init("Library/Caches/BraveSoftware", .itself, group: "Brave",
                      owner: OwnerApp("Brave", "com.brave.Browser")),
                .init("Library/Caches/company.thebrowser.Browser", .itself, group: "Arc",
                      owner: OwnerApp("Arc", "company.thebrowser.Browser")),
                .init("Library/Caches/com.operasoftware.Opera", .itself, group: "Opera",
                      owner: OwnerApp("Opera", "com.operasoftware.Opera")),
             ])),

        Rule(id: "crashReports", title: "Crash Reports",
             subtitle: "Reports macOS stores after an app crashes.",
             symbol: "exclamationmark.triangle", section: .junk, profile: .general, risk: .safe,
             finder: PathFinder(children: "Library/Logs/DiagnosticReports",
                                "Library/Application Support/CrashReporter")),

        Rule(id: "savedState", title: "Saved window state",
             subtitle: "Window positions apps restore when they reopen. Apps start with fresh windows next time.",
             symbol: "macwindow", section: .junk, profile: .general, risk: .safe,
             finder: PathFinder(children: "Library/Saved Application State")),

        Rule(id: "mailDownloads", title: "Mail Downloads",
             subtitle: "Attachments Mail saved when you opened them. The originals stay on the mail server.",
             symbol: "envelope", section: .junk, profile: .general, risk: .caution, needsFDA: true,
             safetyExceptions: [mailDownloadsPath],
             finder: PathFinder(children: mailDownloadsPath)),

        Rule(id: "trash", title: "Trash",
             subtitle: "Items you already moved to the Trash. Emptied permanently.",
             symbol: "trash", section: .junk, profile: .general, risk: .safe,
             forcePermanent: true, needsFDA: true,
             finder: PathFinder(children: ".Trash")),

        // Broad rules: scanned last, minus anything the rules above claimed.

        Rule(id: "appCaches", title: "App Caches",
             subtitle: "Temporary data apps keep in ~/Library/Caches. Apps recreate what they need. Apps that are running are left unticked.",
             symbol: "shippingbox", section: .junk, profile: .general, risk: .safe, pass: 1,
             finder: PathFinder(children: "Library/Caches", excluding: appCacheExclusions)),

        Rule(id: "logs", title: "Log Files",
             subtitle: "Diagnostic logs written by apps and the system.",
             symbol: "doc.text", section: .junk, profile: .general, risk: .safe, pass: 1,
             finder: PathFinder(children: "Library/Logs")),
    ]
}
