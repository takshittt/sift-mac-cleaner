import SwiftUI
import SiftCore

enum Format {
    static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    static func age(_ date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    static func items(_ count: Int) -> String {
        count == 1 ? "1 item" : "\(count) items"
    }
}

extension Risk {
    var color: Color {
        switch self {
        case .safe: Color(hex: 0x6FA800)
        case .caution: Color(red: 0.92, green: 0.55, blue: 0.12)
        case .review: Color(hex: 0xFF6347)
        }
    }
}
