import Foundation
import ThreemaMacros

extension TextMessageEntity: MessageAccessibility {
        
    public var privateCustomAccessibilityLabel: String {
        // We add an additional dot to improve the read text.
        "\(text)."
    }
    
    public var customAccessibilityTrait: UIAccessibilityTraits {
        .staticText
    }
    
    public var accessibilityMessageTypeDescription: String {
        #localize("accessibility_textMessage_description")
    }
}
