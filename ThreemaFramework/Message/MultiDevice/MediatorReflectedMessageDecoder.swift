//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

class MediatorReflectedMessageDecoder {

    private let frameworkInjector: FrameworkInjectorProtocol

    required init(frameworkBusinessInjector: FrameworkInjectorProtocol) {
        self.frameworkInjector = frameworkBusinessInjector
    }

    /// Extract and decode abstract message from meditor message `D2d_IncomingMessage.body`.
    ///
    /// Note this rules of reflected incoming messages and its abstract message:
    /// Sender (`AbstractMessage.fromIdentity`) is equals to sender of mediator message.
    /// Receiver (`AbstractMessage.toIdentity`) for incoming message is always me.
    /// Group creator of a group control message is equals to sender of mediator message.
    /// I am always group creator of `GroupRequestSyncMessage` message.
    ///
    /// - Parameters:
    ///     - incomingMessage: Reflected incoming message
    ///     - receivedAfterInitialQueueSend: Message received just after establishing connection
    /// - Returns: Decoded incoming abstract message
    /// - Throws: MediatorReflectedProcessorError.messageDecodeFailed
    func decode<T: AbstractMessage>(
        incomingMessage imsg: D2d_IncomingMessage,
        receivedAfterInitialQueueSend: Bool
    ) throws -> T {
        guard let amsg = MessageDecoder.decode(
            try MediatorMessageProtocol.getAbstractMessageType(for: imsg.type),
            body: imsg.body
        ) as? T else {
            throw MediatorReflectedProcessorError.messageDecodeFailed(message: imsg.loggingDescription)
        }
        amsg.messageID = NSData.convertBytes(imsg.messageID)
        amsg.fromIdentity = imsg.senderIdentity
        amsg.toIdentity = frameworkInjector.myIdentityStore.identity
        amsg.receivedAfterInitialQueueSend = receivedAfterInitialQueueSend

        if amsg.flagGroupMessage() {
            if amsg is GroupCreateMessage
                || amsg is GroupRenameMessage
                || amsg is GroupSetPhotoMessage
                || amsg is GroupDeletePhotoMessage {
                (amsg as! AbstractGroupMessage).groupCreator = imsg.senderIdentity
            }
            else if amsg is GroupRequestSyncMessage {
                (amsg as! AbstractGroupMessage).groupCreator = frameworkInjector.myIdentityStore.identity
            }
        }

        return amsg
    }

    /// Extract and decode abstract message from meditor message `D2d_OutgoingMessage.body`.
    ///
    /// Note this rules of reflected outgoing messages and its abstract message:
    /// Sender (`AbstractMessage.fromIdentity`) is always me.
    /// Receiver (`AbstractMessage.toIdentity`) is equals to receiver of mediator message.
    /// Group creator of a group control message is always me.
    /// Receiver of mediator message is group creator of `GroupRequestSyncMessage` message.
    ///
    /// - Parameter incomingMessage: Reflected incoming message
    /// - Returns: Decoded incoming abstract message
    /// - Throws: MediatorReflectedProcessorError.messageDecodeFailed
    func decode<T: AbstractMessage>(outgoingMessage omsg: D2d_OutgoingMessage) throws -> T {
        guard let amsg = MessageDecoder.decode(
            try MediatorMessageProtocol.getAbstractMessageType(for: omsg.type),
            body: omsg.body
        ) as? T else {
            throw MediatorReflectedProcessorError.messageDecodeFailed(message: omsg.loggingDescription)
        }
        amsg.messageID = NSData.convertBytes(omsg.messageID)
        amsg.fromIdentity = frameworkInjector.myIdentityStore.identity
        amsg.toIdentity = omsg.conversation.contact

        if amsg.flagGroupMessage() {
            if amsg is GroupCreateMessage
                || amsg is GroupRenameMessage
                || amsg is GroupSetPhotoMessage
                || amsg is GroupDeletePhotoMessage {
                (amsg as! AbstractGroupMessage).groupCreator = frameworkInjector.myIdentityStore.identity
            }
            else if amsg is GroupRequestSyncMessage {
                (amsg as! AbstractGroupMessage).groupCreator = omsg.conversation.contact
            }
        }

        return amsg
    }
}
