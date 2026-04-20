import Foundation
import ThreemaMacros

extension LocationMessageEntity: MessageAccessibility {
    
    public var privateCustomAccessibilityLabel: String {
        previewText
    }
    
    public var customAccessibilityHint: String? {
        #localize("accessibility_locationMessage_hint")
    }
    
    public var customAccessibilityTrait: UIAccessibilityTraits {
        [.button, .staticText]
    }
    
    public var accessibilityMessageTypeDescription: String {
        #localize("accessibility_locationMessage_description")
    }
}
