import Foundation

/// Finds candidates at known locations under the home folder.
public struct PathFinder: ItemFinder {
    public enum Mode: Sendable {
        /// The path itself is one item (e.g. `~/Library/Caches/Google/Chrome`).
        case itself
        /// Each entry inside the path is one item (e.g. everything in `~/Library/Logs`).
        case children
    }

    public struct Entry: Sendable {
        /// Home-relative. A component may contain `*` (e.g. `Library/Application Support/Google/AndroidStudio*`).
        public let path: String
        public let mode: Mode
        public let group: String?
        /// Display name for `.itself` entries (e.g. "npm cache" instead of "_cacache").
        public let name: String?
        public let detail: String?
        /// Raises this entry's items above the rule's risk.
        public let risk: Risk?
        /// Group `.children` items by the folder they're in (useful with `*` paths).
        public let groupByFolder: Bool
        /// The app these items belong to, for the running-app check.
        public let owner: OwnerApp?

        public init(_ path: String, _ mode: Mode = .children, group: String? = nil,
                    name: String? = nil, detail: String? = nil, risk: Risk? = nil,
                    groupByFolder: Bool = false, owner: OwnerApp? = nil) {
            self.path = path
            self.mode = mode
            self.group = group
            self.name = name
            self.detail = detail
            self.risk = risk
            self.groupByFolder = groupByFolder
            self.owner = owner
        }
    }

    public let entries: [Entry]
    /// Child names to skip, compared case-insensitively.
    public let excluding: Set<String>

    public init(_ entries: [Entry], excluding: Set<String> = []) {
        self.entries = entries
        self.excluding = Set(excluding.map { $0.lowercased() })
    }

    public init(children paths: String..., excluding: Set<String> = []) {
        self.init(paths.map { Entry($0, .children) }, excluding: excluding)
    }

    /// Files macOS creates everywhere that are never worth listing.
    static let ignoredNames: Set<String> = [".ds_store", ".localized"]

    public func candidates(in context: ScanContext) async throws -> FinderResult {
        var result = FinderResult()
        for entry in entries {
            for url in Self.expand(entry.path, home: context.home) {
                switch entry.mode {
                case .itself:
                    if Self.exists(url) {
                        result.candidates.append(Candidate(url: url, name: entry.name, detail: entry.detail,
                                                           risk: entry.risk, group: entry.group, owner: entry.owner))
                    }
                case .children:
                    do {
                        let children = try FileManager.default.contentsOfDirectory(
                            at: url, includingPropertiesForKeys: nil, options: [])
                        for child in children where !skip(child) {
                            result.candidates.append(Candidate(
                                url: child, detail: entry.detail, risk: entry.risk,
                                group: entry.groupByFolder ? url.lastPathComponent : entry.group,
                                owner: entry.owner))
                        }
                    } catch {
                        if SizeCalc.isPermissionError(error) { result.denied = true }
                        // A missing folder just means that app isn't used here.
                    }
                }
            }
        }
        return result
    }

    private func skip(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        return Self.ignoredNames.contains(name) || excluding.contains(name)
    }

    /// Exists without following a final symlink.
    static func exists(_ url: URL) -> Bool {
        (try? FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false))) != nil
    }

    /// Expands `*` components against the filesystem. Paths without `*` are returned as-is.
    static func expand(_ relative: String, home: URL) -> [URL] {
        var results = [home]
        for part in relative.split(separator: "/").map(String.init) {
            guard part.contains("*") else {
                results = results.map { $0.appending(path: part) }
                continue
            }
            results = results.flatMap { base -> [URL] in
                let names = (try? FileManager.default.contentsOfDirectory(atPath: base.path(percentEncoded: false))) ?? []
                return names.sorted()
                    .filter { fnmatch(part, $0, FNM_CASEFOLD) == 0 }
                    .map { base.appending(path: $0) }
            }
        }
        return results
    }
}
