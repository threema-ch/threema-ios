import Foundation

public struct IntermediateItem {
    public var itemProvider: NSItemProvider
    public var type: String
    public var secondType: String?
    public var caption: String?
}

// MARK: - Equatable

extension IntermediateItem: Equatable {
    public static func == (lhs: IntermediateItem, rhs: IntermediateItem) -> Bool {
        lhs.itemProvider == rhs.itemProvider &&
            lhs.type == rhs.type &&
            lhs.secondType == rhs.secondType &&
            lhs.caption == rhs.caption
    }
}

// MARK: - Comparable

extension IntermediateItem: Comparable {
    public static func < (lhs: IntermediateItem, rhs: IntermediateItem) -> Bool {
        lhs.itemProvider.description < rhs.itemProvider.description &&
            lhs.type < rhs.type &&
            lhs.secondType ?? "" < rhs.secondType ?? "" &&
            lhs.caption ?? "" < rhs.caption ?? ""
    }
}

// MARK: - Hashable

extension IntermediateItem: Hashable { }
