import Foundation

/// Runs every enabled rule, sizes what it finds and streams one category per rule.
public struct ScanEngine: Scanning {
    let rules: [Rule]
    let home: URL
    let apps: any AppIndexing
    let system: any SystemInfo
    let maxConcurrent: Int

    public init(rules: [Rule], home: URL = FileManager.default.homeDirectoryForCurrentUser,
                apps: any AppIndexing, system: any SystemInfo, maxConcurrent: Int = 4) {
        self.rules = rules
        self.home = home
        self.apps = apps
        self.system = system
        self.maxConcurrent = maxConcurrent
    }

    public func scan(profiles: Set<Profile>) -> AsyncThrowingStream<ScanEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await run(profiles: profiles) { continuation.yield($0) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Runs rules pass by pass (see `Rule.pass`). Each later pass skips
    /// everything earlier passes found, so nothing is listed (or counted) twice.
    func run(profiles: Set<Profile>, emit: @escaping @Sendable (ScanEvent) -> Void) async throws {
        let context = ScanContext(home: home, apps: await apps.snapshot(), enabledProfiles: profiles)
        let enabled = rules.filter { profiles.contains($0.profile) }
        let passes = Dictionary(grouping: enabled, by: \.pass).sorted { $0.key < $1.key }.map(\.value)
        let total = Double(max(enabled.count, 1))
        var done = 0

        var claimed: [String] = []
        for pass in passes {
            let claimedSoFar = claimed
            try await forEachConcurrently(pass) { rule in
                await Self.evaluate(rule, context: context, claimed: rule.broad ? claimedSoFar : [])
            } onResult: { result in
                let category = result.category
                done += 1
                claimed += result.claimed
                emit(.category(category))
                emit(.progress(Double(done) / total, currentRule: category.rule.title))
            }
        }
        try Task.checkCancellation()
        emit(.finished(fullDiskAccess: system.hasFullDiskAccess()))
    }

    /// Runs `work` for each rule with at most `maxConcurrent` in flight.
    private func forEachConcurrently(_ rules: [Rule],
                                     work: @escaping @Sendable (Rule) async -> Evaluated,
                                     onResult: (Evaluated) -> Void) async throws {
        try await withThrowingTaskGroup(of: Evaluated.self) { group in
            var pending = rules[...]
            for _ in 0..<maxConcurrent {
                guard let rule = pending.popFirst() else { break }
                group.addTask { await work(rule) }
            }
            while let result = try await group.next() {
                try Task.checkCancellation()
                onResult(result)
                if let rule = pending.popFirst() { group.addTask { await work(rule) } }
            }
        }
    }

    struct Evaluated: Sendable {
        let category: CleanCategory
        /// Every path the rule found, listed or not. Broad rules skip these.
        let claimed: [String]
    }

    /// Finds, filters, sizes and sorts one rule's items.
    static func evaluate(_ rule: Rule, context: ScanContext, claimed: [String]) async -> Evaluated {
        let found = (try? await rule.finder.candidates(in: context)) ?? FinderResult()
        var denied = found.denied
        var candidates = found.candidates
        if rule.broad { candidates = removeClaimed(candidates, claimed: claimed) }

        // Folders of known apps that may hold the user's files (synced folders, models, games).
        let userData = KnownApps.userDataPaths
        let homeKey = key(context.home)
        func parts(_ url: URL) -> [String] {
            let path = key(url)
            guard path.hasPrefix(homeKey + "/") else { return [] }
            return path.dropFirst(homeKey.count + 1).split(separator: "/").map(String.init)
        }

        var items: [CleanItem] = []
        for var candidate in candidates {
            if Task.isCancelled { break }
            let urls = [candidate.url] + candidate.additionalURLs
            guard urls.allSatisfy({ SafetyGuard.validate($0, home: context.home,
                                                          exceptions: rule.safetyExceptions).isSuccess })
            else { continue }
            if let owner = candidate.owner ?? rule.owner, owner.bundleIDs.contains(where: context.apps.isRunning) {
                candidate.isRunningApp = true
                candidate.detail = "\(owner.name) is running"
            } else if let id = BundleIDs.from(name: candidate.url.lastPathComponent), context.apps.isRunning(id) {
                candidate.isRunningApp = true
                candidate.detail = candidate.detail ?? "App is running"
            }
            if userData.contains(where: { SafetyGuard.isInside(parts(candidate.url), $0) }) {
                candidate.risk = .review
                candidate.detail = candidate.detail ?? "May contain your own files"
            }
            let sizes = urls.map(SizeCalc.measure)
            let bytes = sizes.reduce(0) { $0 + $1.bytes }
            denied = denied || sizes.contains(where: \.denied)
            guard bytes > 0 else { continue }
            items.append(CleanItem(rule: rule, candidate: candidate, size: bytes, modified: sizes[0].modified))
        }
        items.sort { $0.size > $1.size }
        return Evaluated(category: CleanCategory(rule: rule, items: items, needsFDA: denied && rule.needsFDA),
                         claimed: candidates.flatMap { ([$0.url] + $0.additionalURLs).map(key) })
    }

    /// Drops candidates already claimed by a specific rule. A candidate that
    /// *contains* a claimed path is split into its children, recursively, so
    /// e.g. `Caches/Google` still yields everything except `Caches/Google/Chrome`.
    static func removeClaimed(_ candidates: [Candidate], claimed: [String]) -> [Candidate] {
        guard !claimed.isEmpty else { return candidates }
        var kept: [Candidate] = []
        for candidate in candidates {
            let path = key(candidate.url)
            if claimed.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) { continue }
            if claimed.contains(where: { $0.hasPrefix(path + "/") }) {
                let children = (try? FileManager.default.contentsOfDirectory(
                    at: candidate.url, includingPropertiesForKeys: nil)) ?? []
                let split = children
                    .filter { !PathFinder.ignoredNames.contains($0.lastPathComponent.lowercased()) }
                    .map { Candidate(url: $0, group: candidate.group ?? candidate.name) }
                kept += removeClaimed(split, claimed: claimed)
                continue
            }
            kept.append(candidate)
        }
        return kept
    }

    /// Comparable form of a path: parent folder with symlinks resolved (so
    /// `/var/…` and `/private/var/…` agree), lowercased since APFS is
    /// case-insensitive by default. The item itself is not resolved.
    static func key(_ url: URL) -> String {
        let path = SafetyGuard.plainPath(url) ?? url.path(percentEncoded: false)
        let ns = path as NSString
        let parent = SafetyGuard.canonicalPath(ns.deletingLastPathComponent)
        return (parent as NSString).appendingPathComponent(ns.lastPathComponent).lowercased()
    }
}
