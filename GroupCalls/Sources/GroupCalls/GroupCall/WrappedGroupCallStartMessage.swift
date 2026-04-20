import CoreData
import Foundation
import ThreemaEssentials
import ThreemaProtocols

/// Used to pass back information needed for sending the `CspE2e_GroupCallStart` after a new call was successfully set
/// up
public struct WrappedGroupCallStartMessage: Sendable {
    public let startMessage: CspE2e_GroupCallStart
    public let groupIdentity: GroupIdentity
    
    public init(startMessage: CspE2e_GroupCallStart, groupIdentity: GroupIdentity) {
        self.startMessage = startMessage
        self.groupIdentity = groupIdentity
    }
}
