import Foundation
import ThreemaMacros

extension SystemMessageEntity: MessageAccessibility {
    
    public var privateCustomAccessibilityLabel: String {
        
        switch systemMessageType {
        case let .callMessage(type: call):
            var localizedLabel = call.localizedMessage
            
            if let duration = callDuration() {
                let durationString = String.localizedStringWithFormat(
                    #localize("call_duration"),
                    duration
                )
                localizedLabel.append(durationString)
            }
            
            return "\(localizedLabel)."
            
        case let .workConsumerInfo(type: wcInfo):
            return String.localizedStringWithFormat(
                #localize("accessibility_senderDescription_systemMessage"),
                wcInfo.localizedMessage
            )
            
        case let .systemMessage(type: infoType):
            return String.localizedStringWithFormat(
                #localize("accessibility_senderDescription_systemMessage"),
                infoType.localizedMessage()
            )
        }
    }
    
    public var customAccessibilityHint: String? {
        switch systemMessageType {
        case .callMessage:
            #localize("accessibility_systemCallMessage_hint")
        case .workConsumerInfo, .systemMessage:
            nil
        }
    }
    
    public var customAccessibilityTrait: UIAccessibilityTraits {
        switch systemMessageType {
        case .callMessage:
            [.button, .staticText]
            
        case .workConsumerInfo, .systemMessage:
            [.staticText, .notEnabled]
        }
    }
    
    public var accessibilityMessageTypeDescription: String {
        // The other system message types do not need a description
        guard case .callMessage = systemMessageType else {
            return ""
        }
        
        return #localize("accessibility_systemCallMessage_description")
    }
}
