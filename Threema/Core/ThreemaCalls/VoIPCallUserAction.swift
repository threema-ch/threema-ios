import Foundation
import ThreemaFramework

final class VoIPCallUserAction: VoIPCallIDProtocol {
    
    enum Action: Equatable {
        case call
        
        case accept
        case acceptCallKit
        
        case reject(sendMessage: Bool)
        case rejectTimeout(sendMessage: Bool)
        case rejectUnknown(sendMessage: Bool)
        
        case end
        
        case speakerOn
        case speakerOff
        
        case muteAudio
        case unmuteAudio
    }
        
    let action: Action
    let contactIdentity: String!
    let callID: VoIPCallID
    let completion: (() -> Void)?
    
    init(action: Action, contactIdentity: String, callID: VoIPCallID, completion: (() -> Void)?) {
        self.action = action
        self.contactIdentity = contactIdentity
        self.completion = completion
        self.callID = callID
    }
}
