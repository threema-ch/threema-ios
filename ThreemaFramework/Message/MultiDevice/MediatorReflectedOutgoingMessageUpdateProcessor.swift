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

class MediatorReflectedOutgoingMessageUpdateProcessor {

    private let frameworkInjector: FrameworkInjectorProtocol

    init(frameworkInjector: FrameworkInjectorProtocol) {
        self.frameworkInjector = frameworkInjector
    }

    func process(outgoingMessageUpdate: D2d_OutgoingMessageUpdate) -> Promise<Void> {
        Promise { seal in
            frameworkInjector.backgroundEntityManager.performBlockAndWait {
                do {
                    for item in outgoingMessageUpdate.updates {
                        switch item.update {
                        case .sent:
                            if item.conversation.contact != "" {
                                try self.saveMessageSent(
                                    messageID: item.messageID,
                                    receiverIdentity: item.conversation.contact
                                )
                            }
                            else {
                                try self.saveMessageSent(
                                    messageID: item.messageID,
                                    receiverGroupID: item.conversation.group.groupID,
                                    receiverGroupCreator: item.conversation.group.creatorIdentity
                                )
                            }
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

    private func saveMessageSent(messageID: UInt64, receiverIdentity: String) throws {
        if let id = NSData.convertBytes(messageID),
           let message = frameworkInjector.backgroundEntityManager.entityFetcher.message(with: id) {
            guard let contact = message.conversation?.contact, contact.identity == receiverIdentity else {
                throw MediatorReflectedProcessorError.messageNotProcessed(message: "id: \(id.hexString)")
            }

            frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
                message.sent = NSNumber(booleanLiteral: true)
                message.remoteSentDate = .now
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
                message.remoteSentDate = .now
            }
        }
    }
}
