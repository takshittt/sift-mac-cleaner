import Foundation

/// One removable file or folder, sized and classified.
///
/// Carries the deletion facts it needs from its rule so the clean engine
/// never has to look rules up.
public struct CleanItem: Sendable, Identifiable, Hashable {
    public let id: String
    public let ruleID: String
    public let url: URL
    public let name: String
    public let detail: String?
    /// Allocated bytes on disk.
    public let size: Int64
    public let modified: Date?
    public let risk: Risk
    public let isRunningApp: Bool
    public let group: String?
    public let disposal: Disposal
    public let forcePermanent: Bool
    public let safetyExceptions: [String]
    /// Other files removed together with `url` (e.g. an Ollama model's blobs).
    public let additionalURLs: [URL]

    /// Every file this item removes, main one first.
    public var allURLs: [URL] { [url] + additionalURLs }

    public init(ruleID: String, url: URL, name: String? = nil, detail: String? = nil,
                size: Int64, modified: Date? = nil, risk: Risk, isRunningApp: Bool = false,
                group: String? = nil, disposal: Disposal, forcePermanent: Bool = false,
                safetyExceptions: [String] = [], additionalURLs: [URL] = []) {
        self.id = "\(ruleID):\(url.path(percentEncoded: false))"
        self.ruleID = ruleID
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.detail = detail
        self.size = size
        self.modified = modified
        self.risk = risk
        self.isRunningApp = isRunningApp
        self.group = group
        self.disposal = disposal
        self.forcePermanent = forcePermanent
        self.safetyExceptions = safetyExceptions
        self.additionalURLs = additionalURLs
    }

    /// Builds an item from a rule and one of its candidates. The item's risk is
    /// the higher of the two; a candidate can never make an item look safer.
    public init(rule: Rule, candidate: Candidate, size: Int64, modified: Date? = nil) {
        self.init(ruleID: rule.id, url: candidate.url, name: candidate.name,
                  detail: candidate.detail, size: size, modified: modified,
                  risk: max(rule.risk, candidate.risk ?? rule.risk),
                  isRunningApp: candidate.isRunningApp, group: candidate.group,
                  disposal: rule.disposal, forcePermanent: rule.forcePermanent,
                  safetyExceptions: rule.safetyExceptions, additionalURLs: candidate.additionalURLs)
    }
}

/// A rule plus everything the scan found for it.
public struct CleanCategory: Sendable, Identifiable {
    public let rule: Rule
    public var items: [CleanItem]
    /// Some candidates could not be read without Full Disk Access.
    public var needsFDA: Bool

    public var id: String { rule.id }
    public var total: Int64 { items.reduce(0) { $0 + $1.size } }

    public init(rule: Rule, items: [CleanItem], needsFDA: Bool = false) {
        self.rule = rule
        self.items = items
        self.needsFDA = needsFDA
    }
}

/// What a clean run did.
public struct CleanReport: Sendable, Equatable {
    public var deletedCount = 0
    public var deletedBytes: Int64 = 0
    public var trashedCount = 0
    public var trashedBytes: Int64 = 0
    public var failures: [Failure] = []

    public struct Failure: Sendable, Equatable {
        public let item: CleanItem
        public let message: String
    }

    public init() {}
}

public enum Phase: Sendable, Equatable {
    case idle
    case scanning(progress: Double)
    case ready
    case cleaning(progress: Double)
    case done
}
