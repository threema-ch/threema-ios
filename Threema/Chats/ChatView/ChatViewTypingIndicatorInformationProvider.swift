import Foundation
import ThreemaMacros

protocol ChatViewTypingIndicatorInformationProviderProtocol {
    var currentlyTypingPublisher: Published<Bool>.Publisher { get }
}

final class ChatViewTypingIndicatorInformationProvider: ChatViewTypingIndicatorInformationProviderProtocol {
    // MARK: - Properties

    var currentlyTypingPublisher: Published<Bool>.Publisher { $currentlyTyping }
    
    // MARK: - Private Properties

    @Published private var currentlyTyping: Bool
    
    private var conversationIsTypingToken: NSKeyValueObservation?
    
    // MARK: - Lifecycle

    init(conversation: ConversationEntity, entityManager: EntityManager) {
        self.currentlyTyping = conversation.typing.boolValue
        
        setupObservers(conversation: conversation)
    }
    
    // MARK: - Configuration Functions

    private func setupObservers(conversation: ConversationEntity) {
        conversationIsTypingToken = conversation.observe(\.typing, options: .new) { [weak self] _, change in
            self?.currentlyTyping = change.newValue?.boolValue ?? false
            
            Task { @MainActor in
                self?.accessibilityTyping(conversation: conversation)
            }
        }
    }
    
    /// Announce the typing indicator for accessibility if the current chat is the top view controller.
    /// - Parameter conversation: Conversation
    @MainActor
    private func accessibilityTyping(conversation: ConversationEntity) {
        guard
            let appCoordinator = AppDelegate.shared().appCoordinator as? AppCoordinator,
            appCoordinator.splitViewController.isTopControllerChat(for: conversation.contact)
        else {
            return
        }
        
        // Inform with accessibility notification post when user is typing or stops typing
        guard let displayName = conversation.contact?.displayName else {
            // If there is no display name, it will use the string 'Contact'
            let messageKey = currentlyTyping
                ? #localize("accessibility_senderDescription_typing")
                : #localize("accessibility_senderDescription_stopped_typing")
            UIAccessibility.post(
                notification: UIAccessibility.Notification.announcement,
                argument: messageKey
            )
            return
        }
        
        let messageKey = currentlyTyping
            ? #localize("accessibility_senderDescription_contact_typing")
            : #localize("accessibility_senderDescription_contact_stopped_typing")
        let message = String(format: messageKey, displayName)
        
        DispatchQueue.main.async {
            UIAccessibility.post(
                notification: UIAccessibility.Notification.announcement,
                argument: message
            )
        }
    }
}
