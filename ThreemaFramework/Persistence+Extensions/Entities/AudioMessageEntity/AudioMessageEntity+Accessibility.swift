import Foundation
import ThreemaMacros

extension AudioMessageEntity: MessageAccessibility {
    public var privateCustomAccessibilityLabel: String {
        "" // No value since duration is handled as accessibilityValue and captions are not allowed
    }
    
    public var customAccessibilityValue: String? {
        guard let duration = durationTimeInterval, duration > 0.0 else {
            return nil
        }
        
        let formattedDuration = DateFormatter.timeFormatted(Int(duration))
        return String.localizedStringWithFormat(
            #localize("accessibility_file_duration"),
            formattedDuration
        )
    }
    
    public var customAccessibilityHint: String? {
        #localize("accessibility_audioMessage_hint")
    }
    
    public var customAccessibilityTrait: UIAccessibilityTraits {
        [.playsSound, .allowsDirectInteraction]
    }
    
    public var accessibilityMessageTypeDescription: String {
        #localize("accessibility_voiceMessage_description")
    }
}
