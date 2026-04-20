import Foundation
import ThreemaMacros

extension BallotMessageEntity: MessageAccessibility {
    public var privateCustomAccessibilityLabel: String {
        guard let ballot else {
            return ""
        }

        if !ballot.isClosed {
            return String.localizedStringWithFormat(
                #localize("accessibility_poll_content_open"),
                #localize("accessibility_poll_open"),
                ballot.title ?? "",
                ballot.localizedMessageSecondaryText().string
            )
        }
        else {
            return String.localizedStringWithFormat(
                #localize("accessibility_poll_content_open"),
                #localize("accessibility_poll_closed"),
                ballot.title ?? "",
                ballot.localizedClosingMessageText
            )
        }
    }
    
    public var customAccessibilityHint: String? {
        guard let ballot else {
            return nil
        }

        if ballot.isClosed {
            return #localize("accessibility_ballotMessage_hint_closed")
        }
        else {
            return #localize("accessibility_ballotMessage_hint_open")
        }
    }

    public var customAccessibilityTrait: UIAccessibilityTraits {
        [.button, .staticText]
    }
    
    public var accessibilityMessageTypeDescription: String {
        #localize("accessibility_pollMessage_description")
    }
}
