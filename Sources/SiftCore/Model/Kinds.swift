import Foundation

/// What the user does with their Mac. Decides which rules are scanned.
public enum Profile: String, CaseIterable, Codable, Sendable, Identifiable {
    case general
    case developer
    case localAI

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .general: "Everyday use"
        case .developer: "Software development"
        case .localAI: "AI and machine learning"
        }
    }

    public var summary: String {
        switch self {
        case .general: "Caches, logs, browsers, leftovers"
        case .developer: "Xcode, npm, Homebrew, stale node_modules"
        case .localAI: "Ollama, LM Studio, Hugging Face models"
        }
    }
}

/// How safe an item is to remove. Ordered: safe < caution < review.
public enum Risk: String, CaseIterable, Codable, Sendable, Comparable {
    /// Rebuilt automatically. Preselected.
    case safe
    /// Safe, but may need a re-download, rebuild or sign-in.
    case caution
    /// May contain the user's own data. Never preselected.
    case review

    public var title: String {
        switch self {
        case .safe: "Safe"
        case .caution: "Caution"
        case .review: "Review"
        }
    }

    public var explanation: String {
        switch self {
        case .safe: "Rebuilt automatically by macOS or the app. Nothing of yours is lost."
        case .caution: "Safe, but you may need to re-download, rebuild or sign in again."
        case .review: "May contain your own data. Look through the list before removing."
        }
    }

    private var order: Int {
        switch self {
        case .safe: 0
        case .caution: 1
        case .review: 2
        }
    }

    public static func < (lhs: Risk, rhs: Risk) -> Bool { lhs.order < rhs.order }
}

/// Sidebar sections.
public enum SectionKind: String, CaseIterable, Sendable, Identifiable {
    case junk
    case files
    case apps
    case developer
    case localAI

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .junk: "System Junk"
        case .files: "Files"
        case .apps: "Apps & Leftovers"
        case .developer: "Developer"
        case .localAI: "Local AI"
        }
    }

    public var symbol: String {
        switch self {
        case .junk: "trash"
        case .files: "doc.text"
        case .apps: "questionmark.folder"
        case .developer: "hammer"
        case .localAI: "memorychip"
        }
    }
}

/// The user's global choice of how files are removed.
public enum DeletionMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case smart
    case trash
    case permanent

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .smart: "Smart (recommended)"
        case .trash: "Always move to Trash"
        case .permanent: "Always delete permanently"
        }
    }

    public var explanation: String {
        switch self {
        case .smart:
            "Regenerable caches are deleted for real (moving them to the Trash would not free space). Anything that could hold your data goes to the Trash so you can undo."
        case .trash:
            "Everything goes to the Trash. Space is only freed once you empty it."
        case .permanent:
            "Everything is deleted immediately and cannot be recovered."
        }
    }
}

/// What actually happens to one item.
public enum Disposal: String, Sendable, Codable {
    case permanent
    case trash
}
