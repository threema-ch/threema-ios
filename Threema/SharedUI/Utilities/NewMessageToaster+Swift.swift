import Foundation
import ThreemaMacros

extension NewMessageToaster {
    @objc func accessibilityText(for message: BaseMessageEntity) -> String? {
        guard let previewableMessage = message as? PreviewableMessage else {
            return nil
        }
        var accessibilityText = #localize("new_message_accessibility")
        
        if message.isGroupMessage,
           let sender = message.accessibilityMessageSender {
            accessibilityText += "\(#localize("from")) "
            accessibilityText += "\(sender). "
        }
        
        accessibilityText += previewableMessage.previewText
        return accessibilityText
    }
}
