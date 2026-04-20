import CocoaLumberjackSwift
import Foundation
import PromiseKit
import ThreemaProtocols

/// Reflect `GroupDeliveryReceiptMessage` (or `D2d_IncomingMessageUpdate` for read sync) for group messages
/// to mediator server is multi device enabled and send it to group members (CSP).
final class TaskExecutionSendGroupDeliveryReceiptsMessage: TaskExecution, TaskExecutionProtocol {
    func execute() -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionSendGroupDeliveryReceiptsMessage else {
            return Promise(error: TaskExecutionError.wrongTaskDefinitionType)
        }
        
        guard let groupID = task.groupID, let groupCreatorIdentity = task.groupCreatorIdentity else {
            return Promise(error: TaskExecutionError.missingGroupInformation)
        }

        return firstly {
            try self.generateMessageNonces(for: taskDefinition)
            return isMultiDeviceRegistered()
        }
        .then { doReflect -> Promise<Bool> in
            // Reflect group delivery receipts message if is necessary
            guard doReflect else {
                return Promise { seal in seal.fulfill(true) }
            }

            if task.receiptType == .ack || task.receiptType == .decline {
                return Promise { seal in seal.fulfill(true) }
            }
            else if task.receiptType == .read {
                // Reflect read receipt for incoming message
                // swiftformat:disable:next all
                var conversationID = D2d_ConversationId()
                var groupIdentity = Common_GroupIdentity()
                groupIdentity.groupID = try groupID.littleEndian()
                groupIdentity.creatorIdentity = groupCreatorIdentity
                conversationID.group = groupIdentity

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
                return Promise { seal in seal.fulfill(false) }
            }

            return Promise { seal in seal.fulfill(false) }
        }
        .then { doSend -> Promise<Void> in
            guard doSend else {
                return Promise()
            }

            // Send group delivery receipts messages
            var sendMessages = [Promise<AbstractMessage?>]()
            for toMember in task.toMembers {
                if toMember == self.frameworkInjector.myIdentityStore.identity {
                    continue
                }
            
                let msg = self.getGroupDeliveryReceiptMessage(
                    groupID,
                    groupCreatorIdentity,
                    task.fromMember,
                    toMember,
                    task.receiptType,
                    task.receiptMessageIDs
                )
                sendMessages.append(
                    self.sendMessage(
                        message: msg,
                        ltSend: self.taskContext.logSendMessageToChat,
                        ltAck: self.taskContext.logReceiveMessageAckFromChat
                    )
                )
            }

            return when(fulfilled: sendMessages)
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
