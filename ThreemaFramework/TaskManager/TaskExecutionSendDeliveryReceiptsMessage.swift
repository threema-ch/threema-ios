//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

import Foundation

/// Reflect DeliveryReceipts to mediator server is multi device enabled
/// and send it to group members (CSP).
class TaskExecutionSendDeliveryReceiptsMessage: TaskExecution, TaskExecutionProtocol {
    func execute() -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionSendDeliveryReceiptsMessage else {
            return Promise(error: TaskExecutionError.wrongTaskDefinitionType)
        }

        return firstly {
            isMultiDeviceActivated()
        }
        .then { doReflect -> Promise<DeliveryReceiptMessage?> in
            // Check has to send read receipt to contact, all other receipt types will be send anyway
            var doSendReadReceipt = false
            if task.receiptType == DELIVERYRECEIPT_MSGREAD {
                doSendReadReceipt = self.frameworkInjector.backgroundEntityManager.performAndWait {
                    if let contactEntity = self.frameworkInjector.backgroundEntityManager.entityFetcher
                        .contact(for: task.toIdentity) {
                        return self.frameworkInjector.messageSender.doSendReadReceipt(to: contactEntity)
                    }
                    return false
                }
            }

            var deliveryReceiptMessage: DeliveryReceiptMessage?
            if doSendReadReceipt || task.receiptType != DELIVERYRECEIPT_MSGREAD {
                deliveryReceiptMessage = self.getDeliveryReceiptMessage(
                    task.fromIdentity,
                    task.toIdentity,
                    task.receiptType,
                    task.receiptMessageIDs
                )
            }

            // Reflect group delivery receipts message if is necessary
            guard doReflect else {
                return Promise { seal in seal.fulfill(deliveryReceiptMessage) }
            }

            if let deliveryReceiptMessage {
                try self.reflectMessage(
                    message: deliveryReceiptMessage,
                    ltReflect: self.taskContext.logReflectMessageToMediator,
                    ltAck: self.taskContext.logReceiveMessageAckFromMediator
                )
            }
            else if task.receiptType == DELIVERYRECEIPT_MSGREAD {
                // Reflect read receipt for incoming message
                // swiftformat:disable:next all
                var conversationID = D2d_ConversationId()
                conversationID.contact = task.toIdentity

                let envelope = self.frameworkInjector.mediatorMessageProtocol
                    .getEnvelopeForIncomingMessageUpdate(
                        messageIDs: task.receiptMessageIDs,
                        messageReadDates: task.receiptReadDates,
                        conversationID: conversationID
                    )

                try self.reflectMessage(
                    envelope: envelope,
                    ltReflect: .reflectOutgoingMessageUpdateToMediator,
                    ltAck: .receiveOutgoingMessageUpdateAckFromMediator
                )
            }

            return Promise { seal in seal.fulfill(deliveryReceiptMessage) }
        }
        .then { deliveryReceiptMessage -> Promise<Void> in
            guard let deliveryReceiptMessage else {
                return Promise()
            }

            // Send delivery receipt message (CSP)
            return self.sendMessage(
                message: deliveryReceiptMessage,
                ltSend: self.taskContext.logSendMessageToChat,
                ltAck: self.taskContext.logReceiveMessageAckFromChat
            )
            .then { _ in
                Promise()
            }
        }
    }
}
