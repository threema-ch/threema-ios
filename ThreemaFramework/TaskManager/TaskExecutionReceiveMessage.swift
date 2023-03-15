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
        .then { (processedMsg: Any?) -> Promise<(AbstractMessage?, TaskDefinitionSendAbstractMessage?)> in
            guard let processedMsg = processedMsg as? AbstractMessage else {
                // Won't processing this message, because is invalid
                return Promise { $0.fulfill((nil, nil)) }
            }
            guard processedMsg.toIdentity == self.frameworkInjector.myIdentityStore.identity else {
                throw TaskExecutionError
                    .reflectMessageFailed(message: "Wrong receiver identity \(processedMsg.toIdentity ?? "-")")
            }

            return Promise { $0.fulfill(
                (
                    processedMsg,
                    TaskDefinitionSendAbstractMessage(
                        message: processedMsg,
                        doOnlyReflect: true,
                        isPersistent: false
                    )
                )
            ) }
        }
        .then { (processedMsg: AbstractMessage?, task: TaskDefinitionSendAbstractMessage?) -> Promise<AbstractMessage?> in
            guard let processedMsg = processedMsg else {
                // Message would not be processed (skip reflecting message)
                return Promise { $0.fulfill(processedMsg) }
            }
            guard let task = task else {
                throw TaskExecutionError.processIncomingMessageFailed(message: processedMsg.messageID.hexString)
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
                    Promise { $0.fulfill(processedMsg) }
                }
        }
        .then { (processedMsg: AbstractMessage?) -> Promise<AbstractMessage?> in
            guard let processedMsg = processedMsg else {
                // Message would not be processed (skip sending delivery receipt)
                return Promise { $0.fulfill(processedMsg) }
            }

            // Send and update devlivery receipt
            if let delivered = processedMsg.delivered,
               let deliveryDate = processedMsg.deliveryDate {
                self.update(
                    message: processedMsg,
                    delivered: delivered.boolValue,
                    deliveryDate: deliveryDate
                )
                return Promise { $0.fulfill(processedMsg) }
            }
            else {
                return self.frameworkInjector.messageSender.sendDeliveryReceipt(for: processedMsg)
                    .then { _ -> Promise<AbstractMessage?> in
                        self.update(message: processedMsg, delivered: true, deliveryDate: Date())
                        return Promise { $0.fulfill(processedMsg) }
                    }
            }
        }
        .then { (processedMsg: AbstractMessage?) -> Promise<Void> in
            
            if AppGroup.getActiveType() == AppGroupTypeNotificationExtension,
               processedMsg?.flagImmediateDeliveryRequired() == true,
               let identity = processedMsg?.fromIdentity,
               !UserSettings.shared().blacklist.contains(identity) {
                // Do not ack message if it's a VoIP message in the notification extension
            }
            else {
                // Ack message
                if !self.frameworkInjector.serverConnector.completedProcessingMessage(task.message) {
                    throw TaskExecutionError.processIncomingMessageFailed(
                        message: processedMsg?.loggingDescription ?? task.message.loggingDescription
                    )
                }

                DDLogNotice(
                    "\(LoggingTag.sendIncomingMessageAckToChat.hexString) \(LoggingTag.sendIncomingMessageAckToChat) \(processedMsg?.loggingDescription ?? task.message.loggingDescription)"
                )

                if let processedMsg {
                    let nonceGuard = NonceGuard(entityManager: self.frameworkInjector.backgroundEntityManager)
                    try nonceGuard.processed(message: processedMsg, isReflected: false)
                }
            }
            
            self.frameworkInjector.backgroundEntityManager.performBlockAndWait {
                // Attempt periodic group sync
                if let processedMsg = processedMsg as? AbstractGroupMessage,
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
                DDLogError("Could not update message because we could not find the message")
                return
            }
            
            msg.delivered = NSNumber(booleanLiteral: delivered)
            msg.deliveryDate = deliveryDate
        }
    }
}
