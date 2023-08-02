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
import ThreemaProtocols

/// Reflect `DeliveryReceiptMessage` (or `D2d_IncomingMessageUpdate` for read sync) for 1-1 messages
/// to mediator server is multi device enabled and send it to group members (CSP).
final class TaskExecutionSendDeliveryReceiptsMessage: TaskExecution, TaskExecutionProtocol {
    func execute() -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionSendDeliveryReceiptsMessage else {
            return Promise(error: TaskExecutionError.wrongTaskDefinitionType)
        }

        return firstly {
            try self.generateMessageNonces(for: taskDefinition)
            return isMultiDeviceRegistered()
        }
        .then { doReflect -> Promise<DeliveryReceiptMessage?> in
            // Check has to send read receipt to contact, all other receipt types will be send anyway
            var doSendReadReceipt = false
            if task.receiptType == .read {
                doSendReadReceipt = self.frameworkInjector.backgroundEntityManager.performAndWait {
                    if let contactEntity = self.frameworkInjector.backgroundEntityManager.entityFetcher
                        .contact(for: task.toIdentity) {
                        return self.frameworkInjector.messageSender.doSendReadReceipt(to: contactEntity)
                    }
                    return false
                }
            }

            var deliveryReceiptMessageForReflecting: DeliveryReceiptMessage?
            var deliveryReceiptMessageForSending: DeliveryReceiptMessage?
            if doSendReadReceipt || task.receiptType != .read {
                deliveryReceiptMessageForReflecting = self.getDeliveryReceiptMessage(
                    task.fromIdentity,
                    task.toIdentity,
                    task.receiptType,
                    task.receiptMessageIDs
                )
                deliveryReceiptMessageForSending = self.getDeliveryReceiptMessage(
                    task.fromIdentity,
                    task.toIdentity,
                    task.receiptType,
                    task.receiptMessageIDs.filter { !task.excludeFromSending.contains($0) }
                )
            }

            // Reflect group delivery receipts message if is necessary
            guard doReflect else {
                return Promise { seal in seal.fulfill(deliveryReceiptMessageForSending) }
            }

            if let deliveryReceiptMessageForReflecting {
                try self.reflectMessage(
                    message: deliveryReceiptMessageForReflecting,
                    ltReflect: self.taskContext.logReflectMessageToMediator,
                    ltAck: self.taskContext.logReceiveMessageAckFromMediator
                )
            }
            else if task.receiptType == .read {
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

            return Promise { seal in seal.fulfill(deliveryReceiptMessageForSending) }
        }
        .then { deliveryReceiptMessage -> Promise<Void> in
            guard let deliveryReceiptMessage, !deliveryReceiptMessage.receiptMessageIDs.isEmpty else {
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
        .then {
            DDLogNotice(
                "Sent delivery receipts (type \(task.receiptType.description)) for message IDs: \(task.receiptMessageIDs.map(\.hexString).joined(separator: ","))"
            )
            return Promise()
        }
    }
}
