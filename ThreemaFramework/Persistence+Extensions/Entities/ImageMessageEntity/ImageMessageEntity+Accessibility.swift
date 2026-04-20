import Foundation

import ThreemaMacros

extension ImageMessageEntity: MessageAccessibility {
    public var privateCustomAccessibilityLabel: String {
        var text = ""
        
        if let caption {
            text =
                "\(String.localizedStringWithFormat(#localize("accessibility_caption"), caption))."
        }
        
        return text
    }
    
    public var customAccessibilityHint: String? {
        #localize("accessibility_imageMessage_hint")
    }
    
    public var customAccessibilityTrait: UIAccessibilityTraits {
        [.button, .image]
    }
    
    public var accessibilityMessageTypeDescription: String {
        #localize("accessibility_imageMessage_description")
    }
}
