import Foundation

/// Measures how much disk space a file or folder really takes.
public enum SizeCalc {
    public struct Measurement: Sendable, Equatable {
        public var bytes: Int64 = 0
        public var modified: Date?
        /// Part of the tree couldn't be read for lack of permission.
        public var denied = false
    }

    /// Sums allocated bytes (what Finder's "on disk" shows). Symlinks are counted
    /// as links, never followed. Returns a partial total if the task is cancelled.
    public static func measure(_ url: URL) -> Measurement {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
                                         .isDirectoryKey, .isSymbolicLinkKey,
                                         .contentModificationDateKey]
        var result = Measurement()
        guard let top = try? url.resourceValues(forKeys: keys) else { return result }
        result.modified = top.contentModificationDate

        guard top.isDirectory == true, top.isSymbolicLink != true else {
            result.bytes = allocated(top)
            return result
        }

        let denied = DeniedFlag()
        let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: Array(keys), options: [],
            errorHandler: { _, error in
                if isPermissionError(error) { denied.set() }
                return true
            })

        var seen = 0
        while let child = enumerator?.nextObject() as? URL {
            seen += 1
            if seen % 1_000 == 0, Task.isCancelled { break }
            if let values = try? child.resourceValues(forKeys: keys) {
                result.bytes += allocated(values)
            }
        }
        result.denied = denied.value
        return result
    }

    private static func allocated(_ values: URLResourceValues) -> Int64 {
        Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
    }

    /// True for "not allowed" errors, which on macOS usually mean Full Disk Access is missing.
    public static func isPermissionError(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain, ns.code == NSFileReadNoPermissionError { return true }
        if ns.domain == NSPOSIXErrorDomain, ns.code == Int(EPERM) || ns.code == Int(EACCES) { return true }
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error { return isPermissionError(underlying) }
        return false
    }
}

/// Set from the enumerator's error callback, read once enumeration is done.
private final class DeniedFlag: @unchecked Sendable {
    private(set) var value = false
    func set() { value = true }
}
