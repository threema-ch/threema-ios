//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2025 Threema GmbH
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

@objc final class TaskDefinitionSendAbstractMessage: TaskDefinition, TaskDefinitionSendMessageNonceProtocol,
    TaskDefinitionSendMessageProtocol {
    override func create(
        frameworkInjector: FrameworkInjectorProtocol,
        taskContext: TaskContextProtocol
    ) -> TaskExecutionProtocol {
        TaskExecutionSendAbstractMessage(
            taskContext: taskContext,
            taskDefinition: self,
            backgroundFrameworkInjector: frameworkInjector
        )
    }

    override func create(frameworkInjector: FrameworkInjectorProtocol) -> TaskExecutionProtocol {
        create(
            frameworkInjector: frameworkInjector,
            taskContext: TaskContext(
                logReflectMessageToMediator: .reflectOutgoingMessageToMediator,
                logReceiveMessageAckFromMediator: .receiveOutgoingMessageAckFromMediator,
                logSendMessageToChat: .sendOutgoingMessageToChat,
                logReceiveMessageAckFromChat: .receiveOutgoingMessageAckFromChat
            )
        )
    }
    
    override var description: String {
        "<\(Swift.type(of: self)) \(message.loggingDescription)>"
    }

    let message: AbstractMessage
    private var messageData: Data?

    var nonces = TaskReceiverNonce()

    private(set) var messageAlreadySentToQueue =
        DispatchQueue(label: "ch.threema.TaskDefinitionSendAbstractMessage.messageAlreadySentToQueue")
    var messageAlreadySentTo = TaskReceiverNonce()

    private enum CodingKeys: String, CodingKey {
        case message, messageData, messageAlreadySentTo
    }

    private enum CodingError: Error {
        case messageDataMissing
    }

    init(message: AbstractMessage, type: TaskType) {
        if !(
            message is BoxBallotVoteMessage || message is GroupBallotVoteMessage ||
                message is BoxVoIPCallAnswerMessage || message is BoxVoIPCallHangupMessage ||
                message is BoxVoIPCallIceCandidatesMessage || message is BoxVoIPCallOfferMessage ||
                message is BoxVoIPCallRingingMessage ||
                message is ContactDeletePhotoMessage || message is ContactRequestPhotoMessage ||
                message is ContactSetPhotoMessage ||
                message is DeliveryReceiptMessage || message is GroupDeliveryReceiptMessage ||
                message is TypingIndicatorMessage ||
                message is GroupCallStartMessage ||
                message is GroupCreateMessage || message is GroupRenameMessage || message is GroupLeaveMessage ||
                message is GroupSetPhotoMessage || message is GroupDeletePhotoMessage ||
                message is GroupRequestSyncMessage ||
                message is ForwardSecurityEnvelopeMessage
        ) {
            DDLogWarn(
                "Only abstract messages for non-persisted messages should be send using this task (\(message.loggingDescription))"
            )
            assertionFailure()
        }
        
        self.message = message
        super.init(type: type)
    }

    @objc convenience init(message: AbstractMessage) {
        self.init(message: message, type: .persistent)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.messageData = try container.decode(Data.self, forKey: .messageData)
        guard let messageData else {
            throw CodingError.messageDataMissing
        }

        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: messageData)
        guard let decodedMessage = try unarchiver.decodeTopLevelObject(
            of: AbstractMessage.self,
            forKey: CodingKeys.message.rawValue
        ) else {
            throw CodingError.messageDataMissing
        }
        self.message = decodedMessage

        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)

        messageAlreadySentToQueue.sync {
            do {
                self.messageAlreadySentTo = try container.decode(TaskReceiverNonce.self, forKey: .messageAlreadySentTo)
            }
            catch {
                self.messageAlreadySentTo = TaskReceiverNonce()
            }
        }
    }

    override func encode(to encoder: Encoder) throws {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        archiver.encode(message, forKey: CodingKeys.message.rawValue)
        archiver.finishEncoding()

        messageData = archiver.encodedData

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(messageData, forKey: .messageData)
        messageAlreadySentToQueue.sync {
            do {
                try container.encode(messageAlreadySentTo, forKey: .messageAlreadySentTo)
            }
            catch {
                // no-op
            }
        }

        let superEncoder = container.superEncoder()
        try super.encode(to: superEncoder)
    }
}
