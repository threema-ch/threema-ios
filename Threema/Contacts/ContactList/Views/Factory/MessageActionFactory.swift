import ThreemaMacros

public struct MessageActionFactory: Factory {
    
    private static let showConversationNotificationName =
        NSNotification.Name(rawValue: kNotificationShowConversation)
    
    private let action: () -> Void
    
    init(action: @escaping () -> Void) {
        self.action = action
    }
    
    public func make() -> UIContextualAction {
        let messageAction = UIContextualAction(
            style: .normal,
            title: #localize("message")
        ) { _, _, handler in
            action()
            handler(true)
        }
        
        messageAction.image = UIImage(resource: .threemaLockBubbleRightFill)
        messageAction.backgroundColor = .primary
        
        return messageAction
    }
}

extension MessageActionFactory {
    public static func make(for contact: Contact) -> UIContextualAction {
        MessageActionFactory {
            NotificationCenter.default.post(
                name: showConversationNotificationName,
                object: nil,
                userInfo: [
                    kKeyContactIdentity: contact.identity.rawValue,
                    kKeyForceCompose: true,
                ]
            )
        }.make()
    }
    
    public static func make(for conversationEntity: ConversationEntity) -> UIContextualAction {
        MessageActionFactory {
            NotificationCenter.default.post(
                name: showConversationNotificationName,
                object: nil,
                userInfo: [
                    kKeyConversation: conversationEntity,
                    kKeyForceCompose: true,
                ]
            )
        }.make()
    }
}
