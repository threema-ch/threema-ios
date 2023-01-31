//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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
import PromiseKit

class MediatorReflectedIncomingMessageUpdateProcessor {

    private let frameworkInjector: FrameworkInjectorProtocol
    private let messageProcessorDelegate: MessageProcessorDelegate

    init(frameworkInjector: FrameworkInjectorProtocol, messageProcessorDelegate: MessageProcessorDelegate) {
        self.frameworkInjector = frameworkInjector
        self.messageProcessorDelegate = messageProcessorDelegate
    }

    func process(incomingMessageUpdate: D2d_IncomingMessageUpdate) -> Promise<Void> {
        Promise { seal in
            frameworkInjector.backgroundEntityManager.performBlockAndWait {
                do {
                    for item in incomingMessageUpdate.updates {
                        switch item.update {
                        case .read:
                            var senderIdentity: String?
                            var senderGroupIdentity: GroupIdentity?
                            if !item.conversation.contact.isEmpty {
                                senderIdentity = item.conversation.contact
                            }
                            else if item.conversation.group.groupID > 0 {
                                senderGroupIdentity = GroupIdentity(
                                    id: NSData.convertBytes(item.conversation.group.groupID),
                                    creator: item.conversation.group.creatorIdentity
                                )
                            }

                            try self.saveMessageRead(
                                messageID: item.messageID,
                                senderIdentity: senderIdentity,
                                senderGroupIdentity: senderGroupIdentity,
                                readDate: Date(milliseconds: item.read.at)
                            )
                        case .none:
                            break
                        }
                    }
                    seal.fulfill_()
                }
                catch {
                    seal.reject(error)
                }
            }
        }
    }

    // MARK: Private functions

    private func saveMessageRead(
        messageID: UInt64,
        senderIdentity: String?,
        senderGroupIdentity: GroupIdentity?,
        readDate: Date
    ) throws {
        var internalError: Error?
        var readMessageConversations = Set<Conversation>()

        frameworkInjector.backgroundEntityManager.performBlockAndWait {
            if let id = NSData.convertBytes(messageID),
               let message = self.frameworkInjector.backgroundEntityManager.entityFetcher.message(with: id) {

                // Validate message sender
                if let senderIdentity = senderIdentity {
                    guard let contact = message.conversation?.contact, contact.identity == senderIdentity else {
                        internalError = MediatorReflectedProcessorError
                            .messageNotProcessed(
                                message: "Incoming message (ID: \(id.hexString)) update failed, sender contact mismatch"
                            )
                        return
                    }
                }
                else if let senderGroupIdentity = senderGroupIdentity {
                    guard let groupID = message.conversation?.groupID, groupID == senderGroupIdentity.id else {
                        internalError = MediatorReflectedProcessorError
                            .messageNotProcessed(
                                message: "Incoming message (ID: \(id.hexString)) update failed, sender group mismatch"
                            )
                        return
                    }
                }
                else {
                    internalError = MediatorReflectedProcessorError
                        .messageNotProcessed(message: "Incoming message (ID: \(id.hexString)) update failed")
                    return
                }

                // Is not a message from myself update as read and refresh unread badge
                if !message.isOwnMessage {
                    self.frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
                        message.read = true
                        message.readDate = readDate
                    }
                    readMessageConversations.insert(message.conversation)
                }
            }
        }

        if !readMessageConversations.isEmpty {
            messageProcessorDelegate.readMessage(inConversations: readMessageConversations)
        }

        if let internalError = internalError {
            throw internalError
        }
    }
}
