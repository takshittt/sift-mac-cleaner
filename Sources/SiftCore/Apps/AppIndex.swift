import AppKit
import Foundation

/// Finds installed apps (folders + Spotlight) and running apps.
public struct LiveAppIndex: AppIndexing {
    let home: URL
    let useSpotlight: Bool

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser, useSpotlight: Bool = true) {
        self.home = home
        self.useSpotlight = useSpotlight
    }

    public func snapshot() async -> AppSnapshot {
        let roots = Self.applicationFolders(home: home)
        var bundles = InstalledApps.bundles(in: roots)
        if useSpotlight { bundles += Spotlight.applicationBundles() }
        let running = await MainActor.run {
            Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        }
        return InstalledApps.snapshot(from: bundles, running: running)
    }

    public func detectProfiles() async -> Set<Profile> {
        ProfileDetector.detect(apps: await snapshot(), home: home)
    }

    /// Where apps usually live, including other volumes.
    static func applicationFolders(home: URL) -> [URL] {
        var roots = ["/Applications", "/Applications/Utilities", "/System/Applications",
                     "/System/Applications/Utilities"].map { URL(filePath: $0) }
        roots.append(home.appending(path: "Applications"))
        let volumes = (try? FileManager.default.contentsOfDirectory(atPath: "/Volumes")) ?? []
        roots += volumes.map { URL(filePath: "/Volumes").appending(path: $0).appending(path: "Applications") }
        return roots
    }
}

/// Reads app bundles into an `AppSnapshot`. Separate from `LiveAppIndex` so tests can use fixture folders.
public enum InstalledApps {
    /// `.app` bundles directly in each root and one folder deeper (e.g. `/Applications/Setapp/*.app`).
    public static func bundles(in roots: [URL]) -> [URL] {
        var found: [URL] = []
        for root in roots {
            let entries = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
            for entry in entries {
                if entry.pathExtension == "app" {
                    found.append(entry)
                } else if (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                    let inner = (try? FileManager.default.contentsOfDirectory(at: entry, includingPropertiesForKeys: nil)) ?? []
                    found += inner.filter { $0.pathExtension == "app" }
                }
            }
        }
        return found
    }

    public static func snapshot(from bundles: [URL], running: Set<String>) -> AppSnapshot {
        var ids = Set<String>(), names = Set<String>()
        for bundle in bundles {
            names.insert(bundle.deletingPathExtension().lastPathComponent.lowercased())
            if let id = bundleID(of: bundle) { ids.insert(id.lowercased()) }
        }
        return AppSnapshot(installedIDs: ids, runningIDs: Set(running.map { $0.lowercased() }),
                           installedNames: names)
    }

    static func bundleID(of bundle: URL) -> String? {
        let plist = bundle.appending(path: "Contents/Info.plist")
        guard let data = try? Data(contentsOf: plist),
              let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return info["CFBundleIdentifier"] as? String
    }
}

/// Spotlight finds apps outside the usual folders (e.g. inside other apps or project builds).
enum Spotlight {
    static func applicationBundles() -> [URL] {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/mdfind")
        process.arguments = ["kMDItemContentTypeTree == 'com.apple.application-bundle'"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
            .split(separator: "\n")
            .map { URL(filePath: String($0)) }
    }
}
