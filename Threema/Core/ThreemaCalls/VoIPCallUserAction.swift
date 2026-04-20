import Foundation
import ThreemaFramework

public final class VoIPCallUserAction: VoIPCallIDProtocol {

    public enum Action {
        case call
        case accept
        case acceptCallKit
        case reject
        case rejectDisabled
        case rejectTimeout
        case rejectBusy
        case rejectUnknown
        case rejectOffHours
        case end
        case speakerOn
        case speakerOff
        case muteAudio
        case unmuteAudio
    }
        
    public let action: Action
    public let contactIdentity: String!
    public let completion: (() -> Void)?
    public let callID: VoIPCallID
    
    public init(action: Action, contactIdentity: String, callID: VoIPCallID, completion: (() -> Void)?) {
        self.action = action
        self.contactIdentity = contactIdentity
        self.completion = completion
        self.callID = callID
    }
}
