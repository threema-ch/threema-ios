import CocoaLumberjackSwift
import Foundation
import ThreemaMacros

enum AddThreemaWorkChannelAction {
    
    private static let threemaWorkChannelIdentity = "*3MAWORK"
    
    static func run(in viewController: UIViewController) {
        if let contact = ContactStore.shared().contact(for: threemaWorkChannelIdentity) {
            guard let contactEntity = contact as? ContactEntity else {
                fatalError("Contact must be of type `ContactEntity`")
            }

            let info = notificationInfo(for: contactEntity)
            showConversation(for: info)
            return
        }
        
        UIAlertTemplate.showAlert(
            owner: viewController,
            title: #localize("threema_work_channel_intro"),
            message: #localize("threema_work_channel_info"),
            titleOk: #localize("add_button"),
            actionOk: { _ in
                addWorkChannel(in: viewController)
            }
        )
    }
    
    private static func addWorkChannel(in viewController: UIViewController) {
        ContactStore.shared().addContact(
            with: threemaWorkChannelIdentity,
            verificationLevel: Int32(ContactEntity.VerificationLevel.unverified.rawValue),
            onCompletion: { contact, _ in
                guard let contactEntity = contact as? ContactEntity else {
                    UIAlertTemplate.showAlert(
                        owner: viewController,
                        title: #localize("threema_work_channel_failed"),
                        message: nil
                    )
                    return
                }
                
                let info = notificationInfo(for: contactEntity)
                showConversation(for: info)
                
                let initialMessages = createInitialMessages()
                dispatchInitialMessages(messages: initialMessages, with: contactEntity)
                
            }, onError: { error in
                UIAlertTemplate.showAlert(
                    owner: viewController,
                    title: #localize("threema_work_channel_failed"),
                    message: error.localizedDescription
                )
            }
        )
    }
    
    private static func notificationInfo(for contact: ContactEntity) -> [AnyHashable: Any] {
        [
            kKeyContact: contact,
            kKeyForceCompose: NSNumber(value: false),
        ]
    }
    
    private static func showConversation(for notificationInfo: [AnyHashable: Any]) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name(rawValue: kNotificationShowConversation),
                object: nil,
                userInfo: notificationInfo
            )
        }
    }
    
    private static func createInitialMessages() -> [String] {
        var initialMessages = [String]()
        
        if !(Bundle.main.preferredLocalizations[0].hasPrefix("de")) {
            initialMessages.append("en")
        }
        else {
            initialMessages.append("de")
        }
        initialMessages.append("Start iOS")
        initialMessages.append("Info")
        
        return initialMessages
    }
    
    private static func dispatchInitialMessages(messages: [String], with contact: ContactEntity) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            let businessInjector = BusinessInjector.ui

            guard let conversation = businessInjector.entityManager.entityFetcher
                .conversationEntity(for: contact.identity) else {
                DDLogWarn("Unable to add initial messages to Threema Work Channel. Reason: conversation not found.")
                return
            }
            
            for (index, message) in messages.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(index)) {
                    businessInjector.messageSender.sendTextMessage(
                        containing: message,
                        in: conversation
                    )
                }
            }
        }
    }
}
