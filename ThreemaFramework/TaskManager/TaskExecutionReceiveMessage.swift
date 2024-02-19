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
        .then { (abstractMessageAndPFSSession: Any?)
            -> Promise<AbstractMessageAndPFSSession?> in
            guard let abstractMessageAndPFSSession = abstractMessageAndPFSSession as? AbstractMessageAndPFSSession,
                  let processedMsg = abstractMessageAndPFSSession.message else {
                DDLogWarn("Won't processing this message, because is invalid")
                return Promise { $0.fulfill(nil) }
            }
            
            guard processedMsg.toIdentity == self.frameworkInjector.myIdentityStore.identity else {
                throw TaskExecutionError
                    .reflectMessageFailed(message: "Wrong receiver identity \(processedMsg.toIdentity ?? "-")")
            }
            
            return Promise { $0.fulfill(abstractMessageAndPFSSession) }
        }
        .then { (abstractMessageAndPFSSession: AbstractMessageAndPFSSession?) -> Promise<AbstractMessageAndPFSSession?> in
            guard let processedMsg = abstractMessageAndPFSSession?.message else {
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
                    Promise { $0.fulfill(abstractMessageAndPFSSession) }
                }
        }
        .then { (abstractMessageAndPFSSession: AbstractMessageAndPFSSession?) -> Promise<AbstractMessageAndPFSSession?> in
            guard let processedMsg = abstractMessageAndPFSSession?.message else {
                DDLogWarn("Message would not be processed (skip send delivery receipt)")
                return Promise { $0.fulfill(nil) }
            }

            // Send and delivery receipt
            return self.frameworkInjector.messageSender.sendDeliveryReceipt(for: processedMsg)
                .then { _ -> Promise<AbstractMessageAndPFSSession?> in
                    Promise { $0.fulfill(abstractMessageAndPFSSession) }
                }
        }
        .then { (abstractMessageAndPFSSession: AbstractMessageAndPFSSession?) -> Promise<Void> in
            if AppGroup.getActiveType() == AppGroupTypeNotificationExtension,
               let processedMsg = abstractMessageAndPFSSession?.message,
               processedMsg.flagIsVoIP() == true,
               let fromIdentity = processedMsg.fromIdentity,
               !self.frameworkInjector.userSettings.blacklist.contains(fromIdentity) {
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
                
                if let processedMsg = abstractMessageAndPFSSession?.message {
                    // Message is processed, store message nonce
                    if !processedMsg.flagDontQueue() {
                        try self.frameworkInjector.nonceGuard.processed(message: processedMsg)
                    }
                    
                    // Commit the peer ratchet. Call this method after an incoming message has been processed
                    // completely.
                    if let session = abstractMessageAndPFSSession?.session as? DHSession {
                        try self.frameworkInjector.fsmp.updateRatchetCounters(session: session)
                    }
                    
                    self.frameworkInjector.backgroundEntityManager.performAndWait {
                        // Unarchive conversation if message type can unarchive a conversation and is archived
                        if processedMsg.canUnarchiveConversation(),
                           let conversation = self.frameworkInjector.backgroundEntityManager
                           .conversation(forMessage: processedMsg),
                           conversation.conversationVisibility == .archived {
                            self.frameworkInjector.conversationStore.unarchive(conversation)
                        }

                        // Attempt periodic group sync
                        if let abstractGroupMessage = processedMsg as? AbstractGroupMessage,
                           let group = self.frameworkInjector.backgroundGroupManager.getGroup(
                               abstractGroupMessage.groupID,
                               creator: abstractGroupMessage.groupCreator
                           ) {
                            self.frameworkInjector.backgroundGroupManager.periodicSyncIfNeeded(for: group)
                        }
                    }
                }
            }

            return Promise()
        }
    }
}
