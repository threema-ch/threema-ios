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
/// enbaled the message will be reflect to mediator server.
class TaskExecutionReceiveMessage: TaskExecution, TaskExecutionProtocol {
    func execute() -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionReceiveMessage, task.message != nil else {
            return Promise(error: TaskExecutionError.wrongTaskDefinitionType)
        }
        
        DDLogNotice(
            "\(LoggingTag.receiveIncomingMessageFromChat.hexString) \(LoggingTag.receiveIncomingMessageFromChat) \(task.message.loggingDescription)"
        )
        
        return frameworkInjector.messageProcessor.processIncomingMessage(
            task.message,
            receivedAfterInitialQueueSend: task.receivedAfterInitialQueueSend,
            maxBytesToDecrypt: task.maxBytesToDecrypt,
            timeoutDownloadThumbnail: task.timeoutDownloadThumbnail
        )
        .then { (abstractMessageAndPFSSession: Any?)
            -> Promise<(AbstractMessageAndPFSSession?, TaskDefinitionSendAbstractMessage?)> in
            guard let abstractMessageAndPFSSession = abstractMessageAndPFSSession as? AbstractMessageAndPFSSession,
                  let processedMsg = abstractMessageAndPFSSession.message else {
                
                DDLogError("Could not cast message to expected format")
                
                // Won't processing this message, because is invalid
                return Promise { $0.fulfill((nil, nil)) }
            }
            
            guard processedMsg.toIdentity == self.frameworkInjector.myIdentityStore.identity else {
                throw TaskExecutionError
                    .reflectMessageFailed(message: "Wrong receiver identity \(processedMsg.toIdentity ?? "-")")
            }
            
            return Promise { $0.fulfill(
                (
                    abstractMessageAndPFSSession,
                    TaskDefinitionSendAbstractMessage(
                        message: processedMsg,
                        doOnlyReflect: true,
                        isPersistent: false
                    )
                )
            ) }
        }
        .then { (
            abstractMessageAndPFSSession: AbstractMessageAndPFSSession?,
            task: TaskDefinitionSendAbstractMessage?
        ) -> Promise<AbstractMessageAndPFSSession?> in
            guard let abstractMessageAndPFSSession,
                  abstractMessageAndPFSSession.message != nil else {
                // Message would not be processed (skip reflecting message)
                return Promise { $0.fulfill(abstractMessageAndPFSSession) }
            }
            
            guard let task else {
                throw TaskExecutionError
                    .processIncomingMessageFailed(
                        message: "No task for reflecting message ID \(abstractMessageAndPFSSession.message?.messageID?.hexString ?? "nil")"
                    )
            }
            
            // Reflect processed incoming chat message
            // Notice: This message will be reflected immediately, before the next task will be executed!
            return task.create(frameworkInjector: self.frameworkInjector, taskContext: TaskContext(
                logReflectMessageToMediator: .reflectIncomingMessageToMediator,
                logReceiveMessageAckFromMediator: .receiveIncomingMessageAckFromMediator,
                logSendMessageToChat: .none,
                logReceiveMessageAckFromChat: .none
            )).execute()
                .then {
                    Promise { $0.fulfill(abstractMessageAndPFSSession) }
                }
        }
        .then { (abstractMessageAndPFSSession: AbstractMessageAndPFSSession?) -> Promise<AbstractMessageAndPFSSession?> in
            guard let processedMsg = abstractMessageAndPFSSession?.message,
                  !processedMsg.flagDontQueue(),
                  !((processedMsg as? AbstractGroupMessage)?.isGroupControlMessage() ?? false) else {
                // Skip sending / updating delivery receipt (for typing indicator or group control messages)
                return Promise { $0.fulfill(abstractMessageAndPFSSession) }
            }

            // Send and update delivery receipt
            if let delivered = processedMsg.delivered,
               let deliveryDate = processedMsg.deliveryDate {
                self.update(
                    message: processedMsg,
                    delivered: delivered.boolValue,
                    deliveryDate: deliveryDate
                )
                return Promise { $0.fulfill(abstractMessageAndPFSSession) }
            }
            else {
                return self.frameworkInjector.messageSender.sendDeliveryReceipt(for: processedMsg)
                    .then { _ -> Promise<AbstractMessageAndPFSSession?> in
                        self.update(message: processedMsg, delivered: true, deliveryDate: Date())
                        return Promise { $0.fulfill(abstractMessageAndPFSSession) }
                    }
            }
        }
        .then { (abstractMessageAndPFSSession: AbstractMessageAndPFSSession?) -> Promise<Void> in
            if AppGroup.getActiveType() == AppGroupTypeNotificationExtension,
               abstractMessageAndPFSSession?.message?.flagIsVoIP() == true,
               let identity = abstractMessageAndPFSSession?.message?.fromIdentity,
               !UserSettings.shared().blacklist.contains(identity) {
                // Do not ack message if it's a VoIP message in the notification extension
            }
            else {
                // Ack message
                if !self.frameworkInjector.serverConnector.completedProcessingMessage(task.message) {
                    throw TaskExecutionError.processIncomingMessageFailed(
                        message: abstractMessageAndPFSSession?.message?.loggingDescription ?? task.message
                            .loggingDescription
                    )
                }
                
                DDLogNotice(
                    "\(LoggingTag.sendIncomingMessageAckToChat.hexString) \(LoggingTag.sendIncomingMessageAckToChat) \(abstractMessageAndPFSSession?.message?.loggingDescription ?? task.message.loggingDescription)"
                )
                
                if ThreemaEnvironment.lateSessionSave {
                    if let session = abstractMessageAndPFSSession?.session as? DHSession {
                        try BusinessInjector().fsmp.updateRatchetCounters(session: session)
                    }
                }
                
                if let processedMsg = abstractMessageAndPFSSession?.message,
                   !processedMsg.flagDontQueue() {
                    let nonceGuard = NonceGuard(entityManager: self.frameworkInjector.backgroundEntityManager)
                    try nonceGuard.processed(message: processedMsg, isReflected: false)
                }

                // Unarchive conversation if is archived
                self.frameworkInjector.entityManager.performBlockAndWait {
                    if let processedMsg = abstractMessageAndPFSSession?.message,
                       let conversation = self.frameworkInjector.entityManager.conversation(forMessage: processedMsg),
                       conversation.conversationVisibility == .archived {
                        self.frameworkInjector.conversationStore.unarchive(conversation)
                    }
                }
            }
            
            self.frameworkInjector.backgroundEntityManager.performBlockAndWait {
                // Attempt periodic group sync
                if let processedMsg = abstractMessageAndPFSSession?.message as? AbstractGroupMessage,
                   let group = self.frameworkInjector.backgroundGroupManager.getGroup(
                       processedMsg.groupID,
                       creator: processedMsg.groupCreator
                   ) {
                    self.frameworkInjector.backgroundGroupManager.periodicSyncIfNeeded(for: group)
                }
            }
            
            return Promise()
        }
    }

    private func update(message: AbstractMessage, delivered: Bool, deliveryDate: Date) {
        frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
            var conversation: Conversation?
            
            if message.flagGroupMessage() {
                guard let groupMessage = message as? AbstractGroupMessage else {
                    DDLogError("Could not update message because it is not group message")
                    return
                }
                
                conversation = self.frameworkInjector.backgroundEntityManager.entityFetcher.conversation(
                    for: groupMessage.groupID,
                    creator: groupMessage.groupCreator
                )
            }
            else {
                conversation = self.frameworkInjector.backgroundEntityManager.entityFetcher
                    .conversation(forIdentity: message.fromIdentity)
            }
            
            guard let conversation else {
                DDLogError("Could not update message because we could not find the conversation")
                return
            }
            
            guard let msg = self.frameworkInjector.backgroundEntityManager.entityFetcher.message(
                with: message.messageID,
                conversation: conversation
            ) else {
                DDLogWarn(
                    "Could not update message because we could not find the message ID \(message.messageID?.hexString ?? "nil")"
                )
                return
            }
            
            msg.delivered = NSNumber(booleanLiteral: delivered)
            msg.deliveryDate = deliveryDate
        }
    }
}
