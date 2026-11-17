import Foundation

public final class ShowConversationInformation {
    /// How the message the chat opens at is pointed out
    public enum MessageMarking {
        /// Selected until the user taps elsewhere, e.g. for a search result
        case select
        /// Flashed briefly, e.g. for the message a notification refers to
        case highlight
    }

    public let conversation: ConversationEntity
    public let forceCompose: Bool
    public let precomposedText: String?
    public let image: UIImage?
    public let messageObjectID: NSManagedObjectID?
    public let messageMarking: MessageMarking

    // TODO: (IOS-4617) Remove once logic is improved. We need a solution to inject these dynamically into a initialized chat view.
    public var forceReopenChat: Bool {
        precomposedText != nil || image != nil || messageObjectID != nil
    }
    
    public init(
        conversation: ConversationEntity,
        forceCompose: Bool = true,
        precomposedText: String? = nil,
        image: UIImage? = nil,
        messageObjectID: NSManagedObjectID? = nil,
        messageMarking: MessageMarking = .select
    ) {
        self.conversation = conversation
        self.forceCompose = forceCompose
        self.precomposedText = precomposedText
        self.image = image
        self.messageObjectID = messageObjectID
        self.messageMarking = messageMarking
    }
    
    public static func createInfo(
        for notification: NSNotification
    ) -> ShowConversationInformation? {
        guard let info = notification.userInfo else {
            return nil
        }
        
        var resolvedConversation: ConversationEntity?

        if let conversation = info[kKeyConversation] as? ConversationEntity {
            resolvedConversation = conversation
        }
        else if let contact = info[kKeyContact] as? ContactEntity {
            let em = BusinessInjector.ui.entityManager
            em.performAndWait {
                resolvedConversation = em.conversation(for: contact.identity, createIfNotExisting: true)
            }
        }
        else if let identity = info[kKeyContactIdentity] as? String {
            let em = BusinessInjector.ui.entityManager
            em.performAndWait {
                resolvedConversation = em.conversation(for: identity, createIfNotExisting: true)
            }
        }
        else {
            assertionFailure("Could not create ShowConversationInformation for notification.")
            return nil
        }
        
        guard let resolvedConversation else {
            assertionFailure("Could not create ShowConversationInformation for notification.")
            return nil
        }
        
        let forceCompose: Bool = info[kKeyForceCompose] as? Bool ?? true
        let text = info[kKeyText] as? String
        let image = info[kKeyImage] as? UIImage
        let baseMessage = info[kKeyMessage] as? BaseMessageEntity
        let messageMarking = info[kKeyMessageMarking] as? MessageMarking ?? .select

        return ShowConversationInformation(
            conversation: resolvedConversation,
            forceCompose: forceCompose,
            precomposedText: text,
            image: image,
            messageObjectID: baseMessage?.objectID,
            messageMarking: messageMarking
        )
    }
}
