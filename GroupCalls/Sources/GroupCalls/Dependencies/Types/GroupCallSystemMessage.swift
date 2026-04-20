import Foundation
import ThreemaEssentials

public enum GroupCallSystemMessage: Sendable {
    case groupCallStartedBy(ThreemaIdentity, Date)
    case groupCallStarted(Date)
    case groupCallEnded
}
