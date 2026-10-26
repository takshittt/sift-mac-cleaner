import Foundation

/// Something a finder found that might be cleaned. Sized later by the scan engine.
public struct Candidate: Sendable, Hashable {
    public var url: URL
    public var name: String
    public var detail: String?
    /// Raises the rule's risk for this item. Never lowers it.
    public var risk: Risk?
    public var group: String?
    public var isRunningApp: Bool
    /// The app this item belongs to, when its name isn't a bundle ID (e.g. "BraveSoftware").
    /// While that app runs, the item is never preselected.
    public var owner: OwnerApp?
    /// Other files that belong to this item and go with it (e.g. a model's data files).
    public var additionalURLs: [URL]

    public init(url: URL, name: String? = nil, detail: String? = nil, risk: Risk? = nil,
                group: String? = nil, isRunningApp: Bool = false, owner: OwnerApp? = nil,
                additionalURLs: [URL] = []) {
        self.url = url
        self.owner = owner
        self.additionalURLs = additionalURLs
        self.name = name ?? url.lastPathComponent
        self.detail = detail
        self.risk = risk
        self.group = group
        self.isRunningApp = isRunningApp
    }
}

/// What a finder found, and whether macOS hid anything from it.
public struct FinderResult: Sendable {
    public var candidates: [Candidate]
    /// A folder couldn't be read for lack of permission (usually Full Disk Access).
    public var denied: Bool

    public init(_ candidates: [Candidate] = [], denied: Bool = false) {
        self.candidates = candidates
        self.denied = denied
    }
}

/// Produces candidates for one rule.
public protocol ItemFinder: Sendable {
    func candidates(in context: ScanContext) async throws -> FinderResult
}

/// A finder that returns a fixed list. Used by fakes and tests.
public struct StaticFinder: ItemFinder {
    public let items: [Candidate]
    public init(_ items: [Candidate] = []) { self.items = items }
    public func candidates(in context: ScanContext) async throws -> FinderResult { FinderResult(items) }
}

/// The app a rule's files belong to. While it runs, the rule's items stay unticked.
public struct OwnerApp: Sendable, Hashable {
    public let name: String
    public let bundleIDs: [String]

    public init(_ name: String, _ bundleIDs: String...) {
        self.name = name
        self.bundleIDs = bundleIDs
    }
}

/// One cleanable category, declared as data in the rule catalog.
public struct Rule: Sendable, Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let symbol: String
    public let section: SectionKind
    public let profile: Profile
    public let risk: Risk
    /// Preselected by default. Only meaningful for `.safe` rules.
    public let defaultOn: Bool
    /// What `.smart` mode does with this rule's `.safe` items.
    public let disposal: Disposal
    /// Always delete permanently, whatever the mode (e.g. emptying the Trash).
    public let forcePermanent: Bool
    /// Some of its paths are hidden without Full Disk Access.
    public let needsFDA: Bool
    /// Home-relative paths inside a protected area that this rule alone may remove.
    public let safetyExceptions: [String]
    /// Scan order. Rules in pass 0 are specific; later passes cover wider areas
    /// (e.g. all of ~/Library/Caches) and skip anything an earlier pass found,
    /// so no file is listed twice.
    public let pass: Int
    public var broad: Bool { pass > 0 }
    /// While this app runs, every item of the rule is marked running (unticked).
    public let owner: OwnerApp?
    public let finder: any ItemFinder

    public init(id: String, title: String, subtitle: String, symbol: String,
                section: SectionKind, profile: Profile, risk: Risk,
                defaultOn: Bool? = nil, disposal: Disposal? = nil,
                forcePermanent: Bool = false, needsFDA: Bool = false,
                safetyExceptions: [String] = [], pass: Int = 0, owner: OwnerApp? = nil,
                finder: any ItemFinder) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.section = section
        self.profile = profile
        self.risk = risk
        self.defaultOn = defaultOn ?? (risk == .safe)
        self.disposal = disposal ?? (risk == .safe ? .permanent : .trash)
        self.forcePermanent = forcePermanent
        self.needsFDA = needsFDA
        self.safetyExceptions = safetyExceptions
        self.pass = pass
        self.owner = owner
        self.finder = finder
    }
}
