import Foundation

/// Finds support files whose app can't be found anywhere on this Mac (spec §8.3).
///
/// Deliberately conservative: a false "orphan" could be another app's data,
/// so anything uncertain is skipped, and every result is Review (never preselected).
public struct OrphanFinder: ItemFinder {
    struct Location: Sendable {
        let path: String
        let label: String
        /// Per-app folders (sandbox containers): match the app exactly, not its vendor.
        let perApp: Bool
    }

    /// Not Caches or Saved Application State: other rules already list those.
    static let locations: [Location] = [
        Location(path: "Library/Preferences", label: "Preferences", perApp: false),
        Location(path: "Library/Application Support", label: "Application Support", perApp: false),
        Location(path: "Library/Containers", label: "Container", perApp: true),
        Location(path: "Library/Group Containers", label: "Shared container", perApp: false),
        Location(path: "Library/Application Scripts", label: "Scripts", perApp: true),
        Location(path: "Library/HTTPStorages", label: "Web data", perApp: false),
        Location(path: "Library/WebKit", label: "Web data", perApp: false),
        Location(path: "Library/Cookies", label: "Cookies", perApp: false),
    ]

    public init() {}

    public func candidates(in context: ScanContext) async throws -> FinderResult {
        let installed = context.apps.installedIDs
        let protectedIDs = Set(KnownApps.all.filter { !$0.userData.isEmpty }.flatMap(\.bundleIDs))
        var result = FinderResult()

        for location in Self.locations {
            let folder = context.home.appending(path: location.path)
            let entries: [URL]
            do {
                entries = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            } catch {
                if SizeCalc.isPermissionError(error) { result.denied = true }
                continue
            }
            for entry in entries {
                // Files must be settings or cookie files; folders can be anything.
                let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                guard isDirectory || ["plist", "binarycookies"].contains(entry.pathExtension.lowercased()),
                      let id = BundleIDs.from(name: entry.lastPathComponent),
                      !BundleIDs.isSystemOrShared(id),
                      !context.apps.runningIDs.contains(id),
                      !protectedIDs.contains(id),
                      BundleIDs.isOrphan(id, installed: installed, perApp: location.perApp)
                else { continue }
                result.candidates.append(Candidate(url: entry, name: location.label,
                                                   detail: "No matching app installed", group: id))
            }
        }
        return result
    }
}

public enum BundleIDs {
    /// The bundle ID a support file or folder is named after, lowercased, or
    /// nil if the name doesn't clearly look like one.
    ///
    /// Handles `.plist`/`.binarycookies` suffixes, a `group.`/`groups.` prefix and
    /// a 10-character team ID prefix (`UBF8T346G9.com.microsoft.teams`).
    public static func from(name: String) -> String? {
        var id = name.lowercased()
        for suffix in [".plist", ".binarycookies", ".savedstate"] where id.hasSuffix(suffix) {
            id.removeLast(suffix.count)
        }
        var parts = id.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        if let first = parts.first, first.count == 10, first.allSatisfy({ $0.isLetter || $0.isNumber }),
           first.contains(where: \.isNumber) {
            parts.removeFirst()
        }
        if ["group", "groups", "systemgroup"].contains(parts.first) { parts.removeFirst() }

        guard parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" } })
        else { return nil }
        let reverseDNS: Set<String> = ["com", "org", "net", "io", "app", "dev", "co", "ai", "me", "us", "de", "uk", "fr", "jp", "ru", "pro", "info", "tv", "so", "sh", "xyz"]
        // Three or more parts (com.vendor.app), or two with a familiar top-level part (com.docker).
        guard parts.count >= 3 || (parts.count == 2 && reverseDNS.contains(parts[0])) else { return nil }
        return parts.joined(separator: ".")
    }

    /// Vendors whose settings belong to macOS or are shared by many apps'
    /// frameworks, so they're never one uninstalled app's leftovers.
    static let systemOrSharedVendors: Set<String> = [
        "com.apple", "org.cups", "com.openssh", "org.openssh", "org.sparkle-project",
        "com.qtproject", "com.trolltech", "org.python", "org.swift", "com.github.sparkle",
    ]

    public static func isSystemOrShared(_ id: String) -> Bool {
        systemOrSharedVendors.contains(vendor(id))
    }

    /// The vendor part of an ID: `com.microsoft.teams` → `com.microsoft`.
    static func vendor(_ id: String) -> String {
        id.split(separator: ".").prefix(2).joined(separator: ".")
    }

    /// True if no installed app matches. An installed ID matches when it equals
    /// the folder's ID or one is a dotted prefix of the other (helpers, extensions).
    /// Shared folders also match any installed app from the same vendor.
    public static func isOrphan(_ id: String, installed: Set<String>, perApp: Bool) -> Bool {
        guard !installed.isEmpty else { return false }   // couldn't list apps: assume nothing is orphaned
        let vendor = vendor(id)
        return !installed.contains { app in
            app == id || id.hasPrefix(app + ".") || app.hasPrefix(id + ".")
                || (!perApp && vendor.contains(".") && Self.vendor(app) == vendor)
        }
    }
}

/// Launch agents whose program no longer exists (spec §7.2).
public struct BrokenLoginItemFinder: ItemFinder {
    public init() {}

    public func candidates(in context: ScanContext) async throws -> FinderResult {
        let folder = context.home.appending(path: "Library/LaunchAgents")
        let entries = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        var result = FinderResult()
        for entry in entries where entry.pathExtension == "plist" {
            guard let program = Self.program(of: entry),
                  program.hasPrefix("/"),
                  !program.hasPrefix("/Volumes/"),   // may be on a drive that isn't plugged in
                  !FileManager.default.fileExists(atPath: program)
            else { continue }
            result.candidates.append(Candidate(url: entry,
                                               detail: "Starts \(program), which no longer exists"))
        }
        return result
    }

    static func program(of plist: URL) -> String? {
        guard let data = try? Data(contentsOf: plist),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        if let program = dict["Program"] as? String { return program }
        return (dict["ProgramArguments"] as? [String])?.first
    }
}
