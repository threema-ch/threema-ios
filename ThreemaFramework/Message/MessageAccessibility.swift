import Foundation
import ThreemaMacros
import UIKit

public protocol MessageAccessibility: BaseMessageEntity {
    /// For private use only, use `customAccessibilityLabel` instead
    @available(*, deprecated, message: "For private use only, use `customAccessibilityLabel` instead")
    var privateCustomAccessibilityLabel: String { get }
    var customAccessibilityValue: String? { get }
    var customAccessibilityHint: String? { get }
    var customAccessibilityTrait: UIAccessibilityTraits { get }
    var accessibilityMessageTypeDescription: String { get }
}

extension MessageAccessibility {
    public var customAccessibilityLabel: String {
        // If deleted we return the default text
        guard deletedAt == nil else {
            return #localize("deleted_message")
        }
        
        return privateCustomAccessibilityLabel
    }
    
    public var customAccessibilityValue: String? {
        nil
    }

    public var customAccessibilityHint: String? {
        nil
    }

    public var customAccessibilityTrait: UIAccessibilityTraits {
        .none
    }
}
