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
import PromiseKit

class MediatorReflectedOutgoingMessageSentProcessor {

    private let frameworkInjector: FrameworkInjectorProtocol

    init(frameworkInjector: FrameworkInjectorProtocol) {
        self.frameworkInjector = frameworkInjector
    }

    func process(outgoingMessageSent: D2d_OutgoingMessageSent) -> Promise<Void> {
        Promise { seal in
            frameworkInjector.backgroundEntityManager.performBlockAndWait {
                do {
                    if outgoingMessageSent.receiver.identity != "" {
                        try self.saveMessageSent(
                            messageID: outgoingMessageSent.messageID,
                            receiverIdentity: outgoingMessageSent.receiver.identity
                        )
                    }
                    else {
                        try self.saveMessageSent(
                            messageID: outgoingMessageSent.messageID,
                            receiverGroupID: outgoingMessageSent.receiver.group.groupID,
                            receiverGroupCreator: outgoingMessageSent.receiver.group.creatorIdentity
                        )
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

    private func saveMessageSent(messageID: UInt64, receiverIdentity: String) throws {
        if let id = NSData.convertBytes(messageID),
           let message = frameworkInjector.backgroundEntityManager.entityFetcher.message(with: id) {
            guard let contact = message.conversation.contact, contact.identity == receiverIdentity else {
                throw MediatorReflectedProcessorError.messageNotProcessed(message: "id: \(id.hexString)")
            }

            frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
                message.sent = NSNumber(booleanLiteral: true)
            }
        }
    }

    private func saveMessageSent(messageID: UInt64, receiverGroupID: UInt64, receiverGroupCreator: String) throws {
        if let id = NSData.convertBytes(messageID),
           let message = frameworkInjector.backgroundEntityManager.entityFetcher.message(with: id) {
            guard let group = frameworkInjector.backgroundGroupManager.getGroup(conversation: message.conversation),
                  group.groupID.elementsEqual(NSData.convertBytes(receiverGroupID)),
                  group.groupCreatorIdentity == receiverGroupCreator else {
                throw MediatorReflectedProcessorError.messageNotProcessed(message: "id: \(id.hexString)")
            }

            frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
                message.sent = NSNumber(booleanLiteral: true)
            }
        }
    }
}
