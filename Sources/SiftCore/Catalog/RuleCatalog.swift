import Foundation

/// Every rule Sift knows, declared as data. One file per section.
public enum RuleCatalog {
    public static var all: [Rule] { junk + files + apps + developer + localAI }

    public static func rule(id: String) -> Rule? { all.first { $0.id == id } }
}
