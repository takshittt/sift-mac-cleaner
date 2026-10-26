import Foundation

// Spec §7.2: Apps & Leftovers, profile `.general`.

extension RuleCatalog {
    public static let apps: [Rule] = [
        Rule(id: "orphans", title: "Leftovers of Uninstalled Apps",
             subtitle: "Preferences, containers and support folders whose app can't be found anywhere on this Mac (checked against /Applications, other volumes and Spotlight).",
             symbol: "questionmark.folder", section: .apps, profile: .general, risk: .review,
             finder: OrphanFinder()),

        Rule(id: "brokenLoginItems", title: "Broken Login Items",
             subtitle: "Launch agents that try to start a program that no longer exists.",
             symbol: "bolt.slash", section: .apps, profile: .general, risk: .caution,
             finder: BrokenLoginItemFinder()),
    ]
}
