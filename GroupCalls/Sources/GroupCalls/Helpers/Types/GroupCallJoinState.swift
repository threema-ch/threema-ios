import Foundation

/// Simplified group call join state of local participant
public enum GroupCallJoinState: Sendable {
    /// ConnectionState is `Unjoined`, `Ending` or `Ended`
    case notJoined
    /// ConnectionState is `Connecting` or `Joining`
    case joining
    /// ConnectionState is `Connected`
    case joined
}
