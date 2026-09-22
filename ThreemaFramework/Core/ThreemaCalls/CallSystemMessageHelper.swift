import CocoaLumberjackSwift
import Foundation

public enum CallSystemMessageHelper {
    public static func maybeAddMissedCallNotificationToConversation(
        with hangupMessage: VoIPCallHangupMessage,
        on businessInjector: BusinessInjectorProtocol,
        messageCreateCompletion: ((ConversationEntity?, SystemMessageEntity?) -> Void)? = nil
    ) {
        Task {
            let callHistoryManager = CallHistoryManager(
                identity: hangupMessage.contactIdentity,
                businessInjector: businessInjector
            )
            if await callHistoryManager.isMissedCall(
                from: hangupMessage.contactIdentity,
                callID: hangupMessage.callID
            ) {
                addMissedCallNotificationToConversation(
                    with: hangupMessage,
                    on: businessInjector,
                    messageCreateCompletion: messageCreateCompletion
                )
            }
            else {
                messageCreateCompletion?(nil, nil)
                DDLogVerbose("Not a missed call. Do not add message!")
            }
        }
    }
    
    public static func addRejectedMessageToConversation(
        contactIdentity: String,
        reason: SystemMessageEntity.SystemMessageEntityType,
        on businessInjector: BusinessInjectorProtocol,
        messageCreateCompletion: ((ConversationEntity, SystemMessageEntity) -> Void)? = nil
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
            messageCreateCompletion?(conversation, systemMessage)
        }
    }
    
    public static func addHangupMessage(
        hangup: VoIPCallHangupMessage,
        on businessInjector: any BusinessInjectorProtocol
    ) {
        businessInjector.entityManager.performAndWait {
            guard let conversation = businessInjector.entityManager.conversation(
                for: hangup.contactIdentity,
                createIfNotExisting: true
            ) else {
                let msg = "Threema Calls: Can't add hangup message because conversation is nil"
                DDLogError("\(msg)")
                assertionFailure(msg)
                return
            }
            
            let systemMessage = businessInjector.entityManager.entityCreator.systemMessageEntity(
                for: .callEnded,
                in: conversation,
                setLastUpdate: true
            )
            
            businessInjector.entityManager.performAndWaitSave {
                // TODO: (IOS-6281) Resolve issues when call was not made with leader, and other side hangs up
                let callStartedBySelf: Bool = false
                
                var callInfo = [
                    "DateString": DateFormatter.shortStyleTimeNoDate(Date()),
                    "CallInitiator": NSNumber(booleanLiteral: callStartedBySelf),
                ] as [String: Any]
                
                if hangup.receivedAsReflected ?? false, let duration = hangup.duration, duration > 0 {
                    callInfo["CallTime"] = DateFormatter.timeFormatted(TimeInterval(duration))
                }
                
                do {
                    let callInfoData = try JSONSerialization.data(withJSONObject: callInfo, options: .prettyPrinted)
                    systemMessage.arg = callInfoData
                    systemMessage.isOwn = NSNumber(booleanLiteral: hangup.isOutgoing)
                }
                catch {
                    DDLogError("An error occurred: \(error.localizedDescription)")
                }
            }
        }
    }
    
    public static func addRejectMessage(
        answer: VoIPCallAnswerMessage,
        on businessInjector: any BusinessInjectorProtocol
    ) {
        // Only add message for rejects
        guard answer.action == .reject else {
            return
        }
        
        businessInjector.entityManager.performAndWait {
            guard let conversation = businessInjector.entityManager.conversation(
                for: answer.contactIdentity,
                createIfNotExisting: true
            ) else {
                let msg = "Threema Calls: Can't add hangup message because conversation is nil"
                DDLogError("\(msg)")
                assertionFailure(msg)
                return
            }
            
            let systemMessage = businessInjector.entityManager.entityCreator.systemMessageEntity(
                for: .callRejected,
                in: conversation,
                setLastUpdate: true
            )
            
            businessInjector.entityManager.performAndWaitSave {
                let callInfo = [
                    "DateString": DateFormatter.shortStyleTimeNoDate(Date()),
                    "CallInitiator": NSNumber(booleanLiteral: answer.isOutgoing),
                ] as [String: Any]
                
                do {
                    let callInfoData = try JSONSerialization.data(withJSONObject: callInfo, options: .prettyPrinted)
                    systemMessage.arg = callInfoData
                    systemMessage.isOwn = NSNumber(booleanLiteral: answer.isOutgoing)
                }
                catch {
                    DDLogError("An error occurred: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: Private Functions
    
    private static func addMissedCallNotificationToConversation(
        with hangupMessage: VoIPCallHangupMessage,
        on businessInjector: BusinessInjectorProtocol,
        messageCreateCompletion: ((ConversationEntity, SystemMessageEntity) -> Void)? = nil
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
            
            messageCreateCompletion?(conversation, systemMessage)
        }
    }
}
