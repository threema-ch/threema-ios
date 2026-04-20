import Foundation
import ThreemaFramework
import ThreemaMacros

class ShareExtensionHelpers {
    static func getDescription(for conversations: [ConversationEntity]) -> NSAttributedString {
        let attrString = NSMutableAttributedString(
            string: ShareExtensionHelpers.getRecipientListHeading(for: conversations),
            attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .headline)]
        )

        let convListAttrString = NSAttributedString(
            string: ShareExtensionHelpers.getRecipientListDescription(for: conversations),
            attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .body)]
        )
        
        attrString.append(convListAttrString)
        
        return attrString
    }
    
    static func getRecipientListHeading(for conversations: [ConversationEntity]) -> String {
        "\(#localize("sending_to")) (\(conversations.count)) : "
    }
    
    static func getRecipientListDescription(for conversations: [ConversationEntity]) -> String {
        var convDescriptionString = ""
        var second = false
        
        for conversation in conversations {
            if second {
                convDescriptionString.append(", ")
            }

            convDescriptionString.append(conversation.displayName)

            second = true
        }
        
        return convDescriptionString
    }
}
