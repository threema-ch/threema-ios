import CocoaLumberjackSwift
import Intents
import ThreemaEssentials
import ThreemaFramework
import ThreemaMacros
import UIKit

@MainActor
final class IntentHandler: IntentHandling {

    private let entityManager: EntityManager
    private let voipCallStateManager: VoIPCallStateManager
    private let hasAudioCallSupportForContact: (ContactEntity) -> Bool
    private let handleConversation: (ConversationEntity) -> Void
    private let rootViewControllerProvider: () -> UIViewController?
    private let urlHandlerFactory: () -> URLHandler
    private lazy var urlHandler = urlHandlerFactory()

    init(
        entityManager: EntityManager,
        voipCallStateManager: VoIPCallStateManager,
        hasAudioCallSupportForContact: @escaping (ContactEntity) -> Bool,
        handleConversation: @escaping (ConversationEntity) -> Void,
        rootViewControllerProvider: @escaping () -> UIViewController?,
        urlHandlerFactory: @escaping () -> URLHandler
    ) {
        self.entityManager = entityManager
        self.voipCallStateManager = voipCallStateManager
        self.hasAudioCallSupportForContact = hasAudioCallSupportForContact
        self.handleConversation = handleConversation
        self.rootViewControllerProvider = rootViewControllerProvider
        self.urlHandlerFactory = urlHandlerFactory
    }

    @discardableResult
    func handle(userActivity: NSUserActivity) -> Bool {
        DDLogNotice("[IntentHandler] Handle user activity of type: \(userActivity.activityType)")

        if let messageIntent = userActivity.interaction?.intent as? INSendMessageIntent {
            return handleMessageIntent(messageIntent)
        }
        else if let callIntent = userActivity.interaction?.intent as? INStartCallIntent {
            return handleCallIntent(callIntent)
        }
        else if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
                let url = userActivity.webpageURL {
            DDLogNotice("[IntentHandler] Handle browsing web user activity")
            urlHandler.handle(url)
            return true
        }

        DDLogWarn("[IntentHandler] Unable to handle user activity of type: \(userActivity.activityType)")
        return false
    }

    @discardableResult
    func handle(openURL url: URL) -> Bool {
        DDLogNotice("[IntentHandler] Handle open URL")
        urlHandler.handle(url)
        return true
    }

    @discardableResult
    func handle(shortcutItem: UIApplicationShortcutItem) -> Bool {
        DDLogNotice("[IntentHandler] Handle shortcut item: \(shortcutItem.type)")
        return urlHandler.handle(item: shortcutItem)
    }

    private func handleMessageIntent(_ intent: INSendMessageIntent) -> Bool {
        DDLogNotice("[IntentHandler] Handle send message intent")

        if let selectedIdentity = intent.conversationIdentifier as String? {
            guard let managedObject = entityManager.entityFetcher.existingObject(
                with: selectedIdentity
            ) else {
                DDLogWarn("[IntentHandler] No managed object found for conversation identifier")
                return false
            }

            if let contact = managedObject as? ContactEntity,
               let conversation = entityManager.entityFetcher.conversationEntity(
                   for: contact.identity
               ) {
                handleConversation(conversation)
            }
            else if let group = managedObject as? ConversationEntity {
                handleConversation(group)
            }
            else {
                DDLogWarn("[IntentHandler] Managed object is neither contact with conversation nor conversation")
            }
        }
        else if let recipient = intent.recipients?.first as? INPerson,
                let identity = recipient.personHandle?.value,
                identity.count == ThreemaIdentity.length {

            guard let conversation = entityManager.entityFetcher.conversationEntity(
                for: identity
            ) else {
                DDLogWarn("[IntentHandler] No conversation found for recipient identity")
                return false
            }

            handleConversation(conversation)
        }
        else {
            DDLogWarn("[IntentHandler] Send message intent has neither conversation identifier nor valid recipient")
            return false
        }

        return true
    }

    private func handleCallIntent(_ intent: INStartCallIntent) -> Bool {
        DDLogNotice("[IntentHandler] Handle start call intent")

        guard let personHandle = intent.contacts?.first?.personHandle?.value else {
            DDLogWarn("[IntentHandler] Start call intent has no person handle")
            return false
        }

        let contact = entityManager.performAndWait {
            self.entityManager.entityFetcher.contactEntity(for: personHandle)
        }

        guard let contact else {
            DDLogWarn("[IntentHandler] No contact found for person handle")
            return false
        }

        guard hasAudioCallSupportForContact(contact) else {
            DDLogNotice("[IntentHandler] Contact does not support 1:1 audio calls")

            guard let vc = rootViewControllerProvider() else {
                DDLogWarn("[IntentHandler] No root view controller to present unsupported call alert")
                return false
            }

            UIAlertTemplate.showOKAlert(
                owner: vc,
                title: #localize("call_voip_not_supported_title"),
                message: #localize("call_voip_not_supported_text")
            )

            return false
        }

        DDLogNotice("[IntentHandler] Start call for contact")
        CallProvider.shared.startOutgoingCall(with: contact.identity)

        return true
    }
}
