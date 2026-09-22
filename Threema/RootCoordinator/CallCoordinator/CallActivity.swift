import GroupCalls
import ThreemaEssentials
import ThreemaFramework

// MARK: - CallActivity

enum CallActivity: Equatable {
    case none
    case oneToOne(identity: String, state: CallActivityState)
    case group(groupID: GroupIdentity, state: CallActivityState)
}

// MARK: - CallActivityState

enum CallActivityState: Equatable {
    case ringingIncoming
    case ringingOutgoing
    case connecting
    case active
    case ending
}

// MARK: - CallType

enum CallType: Equatable {
    case oneToOne(identity: String, incoming: Bool)
    case group(group: Group, intent: GroupCallUserIntent)

    static func == (lhs: CallType, rhs: CallType) -> Bool {
        switch (lhs, rhs) {
        case let (.oneToOne(lhsIdentity, _), .oneToOne(rhsIdentity, _)):
            lhsIdentity == rhsIdentity
        case let (.group(lhsGroup, _), .group(rhsGroup, _)):
            lhsGroup.groupIdentity == rhsGroup.groupIdentity
        default:
            false
        }
    }
}
