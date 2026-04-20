import Foundation
import ThreemaEssentials

/// Threema Contact representation used in Group Calls only
public struct ContactModel: Sendable {
    var identity: ThreemaIdentity
    var nickname: String
    
    public init(identity: ThreemaIdentity, nickname: String) {
        self.identity = identity
        self.nickname = nickname
    }
}
