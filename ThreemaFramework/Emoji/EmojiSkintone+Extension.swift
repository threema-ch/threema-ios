import Foundation

// MARK: - Emoji.SkinTone + Comparable, Identifiable

extension Emoji.SkinTone: Comparable, Identifiable {
    public var id: Self { self }
    
    public static func < (lhs: Emoji.SkinTone, rhs: Emoji.SkinTone) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
    
    var sortOrder: Int {
        switch self {
        case .light: 0
        case .mediumLight: 1
        case .medium: 2
        case .mediumDark: 3
        case .dark: 4
        }
    }
}
