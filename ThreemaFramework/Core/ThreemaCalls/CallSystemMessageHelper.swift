import CocoaLumberjackSwift
import Foundation

public enum CallSystemMessageHelper {
    public static func maybeAddMissedCallNotificationToConversation(
        with hangupMessage: VoIPCallHangupMessage,
        on businessInjector: BusinessInjectorProtocol,
        messsageCreateCompletion: ((ConversationEntity?, SystemMessageEntity?) -> Void)? = nil
    ) {
        Task {
            let callHistoryManager = CallHistoryManager(
                identity: hangupMessage.contactIdentity,
                businessInjector: businessInjector
            )
            if await callHistoryManager.isMissedCall(
                from: hangupMessage.contactIdentity,
                callID: hangupMessage.callID.callID
            ) {
                addMissedCallNotificationToConversation(
                    with: hangupMessage,
                    on: businessInjector,
                    messsageCreateCompletion: messsageCreateCompletion
                )
            }
            else {
                messsageCreateCompletion?(nil, nil)
                DDLogVerbose("Not a missed call. Do not add message!")
            }
        }
    }
    
    public static func addRejectedMessageToConversation(
        contactIdentity: String,
        reason: SystemMessageEntity.SystemMessageEntityType,
        on businessInjector: BusinessInjectorProtocol,
        messsageCreateCompletion: ((ConversationEntity, SystemMessageEntity) -> Void)? = nil
    ) {
        businessInjector.entityManager.performAndWait {
            guard let conversation = businessInjector.entityManager.conversation(
                for: contactIdentity,
                createIfNotExisting: true
            ) else {
                let msg = "Threema Calls: Can't add rejected message because conversation is nil"
                DDLogError("\(msg)")
                assertionFailure(msg)
                return
            }
            
            let systemMessage = businessInjector.entityManager.entityCreator.systemMessageEntity(
                for: reason,
                in: conversation,
                setLastUpdate: true
            )
            
            businessInjector.entityManager.performAndWaitSave {
                let callInfo = [
                    "DateString": DateFormatter.shortStyleTimeNoDate(Date()),
                    "CallInitiator": NSNumber(booleanLiteral: false),
                ] as [String: Any]
                do {
                    let callInfoData = try JSONSerialization.data(withJSONObject: callInfo, options: .prettyPrinted)
                    systemMessage.arg = callInfoData
                    systemMessage.isOwn = NSNumber(booleanLiteral: false)
                }
                catch {
                    DDLogError("An error occurred: \(error.localizedDescription)")
                }
            }
            messsageCreateCompletion?(conversation, systemMessage)
        }
    }
    
    // MARK: Private Functions
    
    private static func addMissedCallNotificationToConversation(
        with hangupMessage: VoIPCallHangupMessage,
        on businessInjector: BusinessInjectorProtocol,
        messsageCreateCompletion: ((ConversationEntity, SystemMessageEntity) -> Void)? = nil
    ) {
        businessInjector.entityManager.performAndWait {
            guard let conversation = businessInjector.entityManager.conversation(
                for: hangupMessage.contactIdentity,
                createIfNotExisting: true
            ) else {
                let msg = "Threema Calls: Can't add rejected message because conversation is nil"
                DDLogError("\(msg)")
                assertionFailure(msg)
                return
            }
            
            guard let contact = businessInjector.entityManager.entityFetcher
                .contactEntity(for: hangupMessage.contactIdentity) else {
                let msg = "Threema Calls: Can't add rejected message because contact can't be found"
                DDLogError("\(msg)")
                assertionFailure(msg)
                return
            }
            
            let systemMessage = businessInjector.entityManager.entityCreator.systemMessageEntity(
                for: .callMissed,
                in: conversation,
                setLastUpdate: true
            )
            
            businessInjector.entityManager.performAndWaitSave {
                systemMessage.remoteSentDate = hangupMessage.date
                
                let cont = Contact(contactEntity: contact)
                systemMessage.forwardSecurityMode = NSNumber(value: cont.forwardSecurityMode.rawValue)
                
                let callInfo = [
                    "DateString": DateFormatter.shortStyleTimeNoDate(Date()),
                    "CallInitiator": NSNumber(booleanLiteral: false),
                ] as [String: Any]
                do {
                    let callInfoData = try JSONSerialization.data(withJSONObject: callInfo, options: .prettyPrinted)
                    systemMessage.arg = callInfoData
                    systemMessage.isOwn = NSNumber(booleanLiteral: false)
                }
                catch {
                    DDLogError("An error occurred: \(error.localizedDescription)")
                }
            }
            
            messsageCreateCompletion?(conversation, systemMessage)
        }
    }
}
