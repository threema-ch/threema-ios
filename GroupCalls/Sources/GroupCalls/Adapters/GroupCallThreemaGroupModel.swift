import Foundation
import ThreemaEssentials

/// Threema Group Conversation representation used in group calls
public struct GroupCallThreemaGroupModel: Hashable, Sendable {
    // MARK: - Public Properties

    public let groupIdentity: GroupIdentity
    public let groupName: String
    
    // MARK: - Lifecycle

    public init(groupIdentity: GroupIdentity, groupName: String) {
        self.groupIdentity = groupIdentity
        self.groupName = groupName
    }
}

// MARK: - Equatable

extension GroupCallThreemaGroupModel: Equatable {
    public static func == (lhs: GroupCallThreemaGroupModel, rhs: GroupCallThreemaGroupModel) -> Bool {
        lhs.groupIdentity == rhs.groupIdentity
    }
}
