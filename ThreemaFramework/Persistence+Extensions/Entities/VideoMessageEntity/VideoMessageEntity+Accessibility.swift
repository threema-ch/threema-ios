import Foundation
import ThreemaMacros

extension VideoMessageEntity: MessageAccessibility {
    public var privateCustomAccessibilityLabel: String {
        var text = ""
        
        if let caption {
            text =
                "\(String.localizedStringWithFormat(#localize("accessibility_caption"), caption))."
        }
        
        return text
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
        #localize("accessibility_videoMessage_hint")
    }
    
    public var customAccessibilityTrait: UIAccessibilityTraits {
        [.button, .playsSound, .startsMediaSession]
    }
    
    public var accessibilityMessageTypeDescription: String {
        #localize("accessibility_videoMessage_description")
    }
}
