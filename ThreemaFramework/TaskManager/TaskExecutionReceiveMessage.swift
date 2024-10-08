//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import CocoaLumberjackSwift
import Foundation
import PromiseKit

/// Process and ack incoming message from chat server, is multi device
/// enabled the message will be reflect to mediator server.
final class TaskExecutionReceiveMessage: TaskExecution, TaskExecutionProtocol {
    func execute() -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionReceiveMessage, task.message != nil else {
            return Promise(error: TaskExecutionError.wrongTaskDefinitionType)
        }
        
        DDLogNotice(
            "\(LoggingTag.receiveIncomingMessageFromChat.hexString) \(LoggingTag.receiveIncomingMessageFromChat) \(task.message.loggingDescription)"
        )
        
        return frameworkInjector.messageProcessor.processIncoming(
            boxedMessage: task.message,
            receivedAfterInitialQueueSend: task.receivedAfterInitialQueueSend,
            maxBytesToDecrypt: task.maxBytesToDecrypt,
            timeoutDownloadThumbnail: task.timeoutDownloadThumbnail
        )
        // Validate message
        .then { (abstractMessageAndFSMessageInfo: AbstractMessageAndFSMessageInfo?)
            -> Promise<AbstractMessageAndFSMessageInfo?> in
            guard let processedMsg = abstractMessageAndFSMessageInfo?.message else {
                DDLogWarn("Won't processing this message, because is invalid")
                return Promise { $0.fulfill(nil) }
            }
            
            guard processedMsg.toIdentity == self.frameworkInjector.myIdentityStore.identity else {
                throw TaskExecutionError
                    .reflectMessageFailed(message: "Wrong receiver identity \(processedMsg.toIdentity ?? "-")")
            }
            
            return Promise { $0.fulfill(abstractMessageAndFSMessageInfo) }
        }
        // Update FS version if needed and send empty message if any upgrade happened
        .then { (abstractMessageAndFSMessageInfo: AbstractMessageAndFSMessageInfo?)
            -> Promise<AbstractMessageAndFSMessageInfo?> in
            guard let processedMsg = abstractMessageAndFSMessageInfo?.message,
                  let fsMessageInfo = abstractMessageAndFSMessageInfo?.fsMessageInfo as? FSMessageInfo else {
                DDLogDebug(
                    "[ForwardSecurity] FS version upgrade not processed, because message or FS message info is empty"
                )
                return Promise { $0.fulfill(abstractMessageAndFSMessageInfo) }
            }
            
            if fsMessageInfo.updateVersionsIfNeeded() {
                return Promise { seal in
                    // TODO: (IOS-4417) This might reset the commit state in case of a race condition with a new session created while sending a message
                    if !fsMessageInfo.session.newSessionCommitted {
                        DDLogWarn("[ForwardSecurity] (IOS-4417) Versions upgrade in uncommitted session")
                    }
                    
                    // This will persist our own ratchets, the commit state and last sent date and versions (if same or
                    // bigger)
                    self.sendEmptyFSMessage(in: fsMessageInfo.session)
                        .done { _ in
                            DDLogNotice("[ForwardSecurity] Upgraded versions and successfully send out empty message")
                            seal.fulfill(abstractMessageAndFSMessageInfo)
                        }
                        .catch { error in
                            // TODO: (IOS-4421) In this case the message already shows up in the chat but does not complete processing (no delivery receipt & server ack). This can be improved: IOS-4421
                            DDLogNotice(
                                "[ForwardSecurity] Upgraded versions, but no persisted them, because failed to send out empty message"
                            )
                            seal.reject(error)
                        }
                }
            }
            else {
                return Promise { $0.fulfill(abstractMessageAndFSMessageInfo) }
            }
        }
        .then { (abstractMessageAndFSMessageInfo: AbstractMessageAndFSMessageInfo?) -> Promise<
            AbstractMessageAndFSMessageInfo?
        > in
            guard let processedMsg = abstractMessageAndFSMessageInfo?.message else {
                DDLogWarn("Message would not be processed (skip reflecting message)")
                return Promise { $0.fulfill(nil) }
            }

            // Reflect processed incoming chat message
            // Notice: This message will be reflected immediately, before the next task will be executed!
            let task = TaskDefinitionReflectIncomingMessage(message: processedMsg)
            return task.create(frameworkInjector: self.frameworkInjector, taskContext: TaskContext(
                logReflectMessageToMediator: .reflectIncomingMessageToMediator,
                logReceiveMessageAckFromMediator: .receiveIncomingMessageAckFromMediator,
                logSendMessageToChat: .none,
                logReceiveMessageAckFromChat: .none
            )).execute()
                .then {
                    Promise { $0.fulfill(abstractMessageAndFSMessageInfo) }
                }
        }
        .then { (abstractMessageAndFSMessageInfo: AbstractMessageAndFSMessageInfo?) -> Promise<
            AbstractMessageAndFSMessageInfo?
        > in
            guard let processedMsg = abstractMessageAndFSMessageInfo?.message else {
                DDLogWarn("Message would not be processed (skip send delivery receipt)")
                return Promise { $0.fulfill(nil) }
            }

            guard !processedMsg.noDeliveryReceiptFlagSet() else {
                return Promise { $0.fulfill(abstractMessageAndFSMessageInfo) }
            }

            guard let messageID = processedMsg.messageID else {
                return Promise(error: TaskExecutionError.processIncomingMessageFailed(
                    message: "Missing message ID for \(processedMsg.loggingDescription)"
                ))
            }

            // Send and delivery receipt
            // Notice: This message will be (reflected) sent immediately, before the next task will be executed!
            let task = TaskDefinitionSendDeliveryReceiptsMessage(
                fromIdentity: self.frameworkInjector.myIdentityStore.identity,
                toIdentity: processedMsg.fromIdentity,
                receiptType: .received,
                receiptMessageIDs: [messageID],
                receiptReadDates: [Date](),
                excludeFromSending: [Data]()
            )
            return task.create(frameworkInjector: self.frameworkInjector, taskContext: TaskContext(
                logReflectMessageToMediator: .reflectOutgoingMessageToMediator,
                logReceiveMessageAckFromMediator: .receiveOutgoingMessageAckFromMediator,
                logSendMessageToChat: .sendOutgoingMessageToChat,
                logReceiveMessageAckFromChat: .receiveOutgoingMessageAckFromChat
            )).execute()
                .then {
                    Promise { $0.fulfill(abstractMessageAndFSMessageInfo) }
                }
        }
        .then { (abstractMessageAndFSMessageInfo: AbstractMessageAndFSMessageInfo?) -> Promise<Void> in
            if AppGroup.getActiveType() == AppGroupTypeNotificationExtension,
               let processedMsg = abstractMessageAndFSMessageInfo?.message,
               processedMsg.flagIsVoIP() == true,
               let fromIdentity = processedMsg.fromIdentity,
               !self.frameworkInjector.userSettings.blacklist.contains(fromIdentity),
               self.frameworkInjector.userSettings.enableThreemaCall,
               self.frameworkInjector.pushSettingManager.canMasterDndSendPush() {
                // Do not ack message if it's a VoIP message in the notification extension
                // But only if threema call is enabled and master dnd can receive messages
            }
            else {
                // Ack message
                if !self.frameworkInjector.serverConnector.completedProcessingMessage(task.message) {
                    throw TaskExecutionError.processIncomingMessageFailed(
                        message: abstractMessageAndFSMessageInfo?.message?.loggingDescription ?? task.message
                            .loggingDescription
                    )
                }

                DDLogNotice(
                    "\(LoggingTag.sendIncomingMessageAckToChat.hexString) \(LoggingTag.sendIncomingMessageAckToChat) \(abstractMessageAndFSMessageInfo?.message?.loggingDescription ?? task.message.loggingDescription)"
                )
                
                if let processedMsg = abstractMessageAndFSMessageInfo?.message {
                    // Message is processed, store message nonce
                    if !processedMsg.flagDontQueue() {
                        try self.frameworkInjector.nonceGuard.processed(message: processedMsg)
                    }
                    
                    // Commit the peer ratchet & session version. Call this method after an incoming message has been
                    // processed completely.
                    if let fsMessageInfo = abstractMessageAndFSMessageInfo?.fsMessageInfo as? FSMessageInfo {
                        // TODO: (IOS-4417) This might reset the commit state in case of a race condition with a new session created while sending a message
                        if !fsMessageInfo.session.newSessionCommitted {
                            DDLogWarn("[ForwardSecurity] (IOS-4417) Received message in uncommitted session.")
                        }
                        
                        try self.frameworkInjector.fsmp
                            .updatePeerRatchetsNewSessionCommittedSendDateAndVersions(session: fsMessageInfo.session)
                    }
                    
                    self.frameworkInjector.entityManager.performAndWait {
                        // Unarchive conversation if message type can unarchive a conversation and is archived
                        if processedMsg.canUnarchiveConversation(),
                           let conversation = self.frameworkInjector.entityManager
                           .conversation(forMessage: processedMsg),
                           conversation.conversationVisibility == .archived {
                            self.frameworkInjector.conversationStore.unarchive(conversation)
                        }

                        // Attempt periodic group sync
                        if let abstractGroupMessage = processedMsg as? AbstractGroupMessage,
                           let group = self.frameworkInjector.groupManager.getGroup(
                               abstractGroupMessage.groupID,
                               creator: abstractGroupMessage.groupCreator
                           ) {
                            self.frameworkInjector.groupManager.periodicSyncIfNeeded(for: group)
                        }
                    }
                }
            }

            return Promise()
        }
    }
}
