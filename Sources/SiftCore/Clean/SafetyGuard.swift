import Foundation

/// Why a path may not be removed.
extension Result {
    public var isSuccess: Bool { if case .success = self { true } else { false } }
}

public enum Violation: Error, Equatable, Sendable {
    case notNormalised
    case outsideHome
    case resolvesOutsideHome
    case isHomeOrTopLevel
    case protected

    public var message: String {
        switch self {
        case .notNormalised: "Path is not normalised"
        case .outsideHome: "Outside your home folder"
        case .resolvesOutsideHome: "Resolves outside your home folder"
        case .isHomeOrTopLevel: "Protected folder"
        case .protected: "Protected personal or system data"
        }
    }
}

/// The single authority on whether a path may be removed.
///
/// Called when scanning and again immediately before every deletion. This is
/// what makes safety "enforced in code, not just in the list": even if a rule
/// is wrong, these checks still stand between it and the file.
public enum SafetyGuard {

    /// Folders that must never be removed themselves (their contents may be).
    /// Home-relative, compared case-insensitively.
    public static let topLevel: [String] = [
        "Applications", "Desktop", "Documents", "Downloads", "Library", "Movies",
        "Music", "Pictures", "Public", "Sites", ".Trash",
        "Library/Application Support", "Library/Caches", "Library/Containers",
        "Library/Developer", "Library/Developer/Xcode", "Library/Group Containers",
        "Library/LaunchAgents", "Library/Logs", "Library/Preferences",
    ]

    /// Areas that are never removed, nor anything inside them, unless a rule
    /// names an explicit exception. Home-relative, case-insensitive. A trailing
    /// `*` on a component matches any suffix.
    public static let protectedPaths: [String] = [
        "Documents",
        "Dropbox",
        "OneDrive*",
        "Library/Accounts",
        "Library/Application Support/AddressBook",
        "Library/Application Support/CloudDocs",
        "Library/Application Support/Knowledge",
        "Library/Application Support/MobileSync",
        "Library/Application Support/com.apple.TCC",
        "Library/Calendars",
        "Library/CloudStorage",
        "Library/Contacts",
        "Library/Containers/com.apple.mail",
        "Library/Fonts",
        "Library/Group Containers/group.com.apple*",
        "Library/Keychains",
        "Library/Mail",
        "Library/Messages",
        "Library/Mobile Documents",
        "Library/Preferences/ByHost",
        "Library/Safari",
    ]

    /// Package extensions protected wherever they appear (e.g. Photos libraries).
    public static let protectedExtensions: Set<String> = ["photoslibrary"]

    /// Returns the URL if it may be removed, or the first rule it breaks.
    ///
    /// - Parameter exceptions: home-relative paths inside a protected area that
    ///   the caller's rule is explicitly allowed to remove. They only lift the
    ///   protected-path check; every other check still applies.
    public static func validate(_ url: URL, home: URL,
                                exceptions: [String] = []) -> Result<URL, Violation> {
        // 1. Normalised: absolute file path, no ".", "..", or empty components.
        guard url.isFileURL, let path = plainPath(url), path.hasPrefix("/"),
              !components(path).contains(where: { $0.isEmpty || $0 == "." || $0 == ".." })
        else { return .failure(.notNormalised) }

        guard let homePath = plainPath(home) else { return .failure(.outsideHome) }

        // 2. Literally inside home (either spelling of it, e.g. /var vs /private/var).
        let canonicalHome = canonicalPath(homePath)
        guard let literalRel = relative(path, to: homePath) ?? relative(path, to: canonicalHome) else {
            return .failure(.outsideHome)
        }

        // 3. Still inside home once symlinks (on the item or any parent) are resolved.
        guard let canonicalRel = relative(canonicalPath(path), to: canonicalHome) else {
            return .failure(.resolvesOutsideHome)
        }

        // 4 & 5 are checked against both spellings, so a symlink inside home
        // can't be used to reach a protected folder.
        for rel in Set([literalRel, canonicalRel]) {
            let parts = rel.split(separator: "/").map(String.init)
            if parts.isEmpty || topLevel.contains(where: { matches(parts, exactly: $0) }) {
                return .failure(.isHomeOrTopLevel)
            }
            let excepted = exceptions.contains { isInside(parts, $0) }
            if !excepted {
                if protectedPaths.contains(where: { isInside(parts, $0) }) { return .failure(.protected) }
                if parts.contains(where: { protectedExtensions.contains(($0 as NSString).pathExtension.lowercased()) }) {
                    return .failure(.protected)
                }
            }
        }
        return .success(url)
    }

    // MARK: - Path helpers

    static func plainPath(_ url: URL) -> String? {
        var path = url.path(percentEncoded: false)
        if path.count > 1, path.hasSuffix("/") { path.removeLast() }
        return path.isEmpty ? nil : path
    }

    /// Components of an absolute path, keeping empty ones so "//" can be detected.
    static func components(_ path: String) -> [String] {
        path.split(separator: "/", omittingEmptySubsequences: false).dropFirst().map(String.init)
    }

    /// `path` relative to `base` (lowercased, since every later comparison is
    /// case-insensitive), or nil if not inside it. Home itself gives "".
    static func relative(_ path: String, to base: String) -> String? {
        let p = path.lowercased(), b = base.lowercased()
        if p == b { return "" }
        let prefix = b.hasSuffix("/") ? b : b + "/"
        guard p.hasPrefix(prefix) else { return nil }
        return String(p.dropFirst(prefix.count))
    }

    /// Resolves every symlink in the deepest existing ancestor, then re-appends
    /// the parts that don't exist yet. Matches `/var` ↔ `/private/var` too.
    static func canonicalPath(_ path: String) -> String {
        var existing = path
        var missing: [String] = []
        while true {
            if let resolved = realpath(existing, nil) {
                defer { free(resolved) }
                var result = String(cString: resolved)
                for part in missing.reversed() {
                    result = (result as NSString).appendingPathComponent(part)
                }
                return result
            }
            let ns = existing as NSString
            if existing == "/" || existing.isEmpty { return path }
            missing.append(ns.lastPathComponent)
            existing = ns.deletingLastPathComponent
        }
    }

    /// True if `parts` is `pattern` or inside it.
    static func isInside(_ parts: [String], _ pattern: String) -> Bool {
        let pat = pattern.split(separator: "/").map(String.init)
        guard parts.count >= pat.count else { return false }
        return zip(parts, pat).allSatisfy(componentMatches)
    }

    static func matches(_ parts: [String], exactly pattern: String) -> Bool {
        parts.count == pattern.split(separator: "/").count && isInside(parts, pattern)
    }

    static func componentMatches(_ part: String, _ pattern: String) -> Bool {
        let a = part.lowercased(), b = pattern.lowercased()
        return b.hasSuffix("*") ? a.hasPrefix(b.dropLast()) : a == b
    }
}
