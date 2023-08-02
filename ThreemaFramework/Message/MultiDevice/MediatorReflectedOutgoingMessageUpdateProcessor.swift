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
import ThreemaProtocols

class MediatorReflectedOutgoingMessageUpdateProcessor {

    private let frameworkInjector: FrameworkInjectorProtocol

    init(frameworkInjector: FrameworkInjectorProtocol) {
        self.frameworkInjector = frameworkInjector
    }

    func process(outgoingMessageUpdate: D2d_OutgoingMessageUpdate, reflectedAt: Date) -> Promise<Void> {
        Promise { seal in
            frameworkInjector.backgroundEntityManager.performAndWait {
                do {
                    for item in outgoingMessageUpdate.updates {
                        switch item.update {
                        case .sent:
                            if item.conversation.contact != "" {
                                try self.saveMessageSent(
                                    messageID: item.messageID,
                                    receiverIdentity: item.conversation.contact,
                                    reflectedAt: reflectedAt
                                )
                            }
                            else {
                                try self.saveMessageSent(
                                    messageID: item.messageID,
                                    receiverGroupID: item.conversation.group.groupID,
                                    receiverGroupCreator: item.conversation.group.creatorIdentity,
                                    reflectedAt: reflectedAt
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

    private func saveMessageSent(messageID: UInt64, receiverIdentity: String, reflectedAt: Date) throws {
        let id = messageID.littleEndianData
        guard let message = frameworkInjector.backgroundEntityManager.entityFetcher.ownMessage(with: id) else {
            DDLogError("Own message ID \(messageID.littleEndianData.hexString) to set as sent not found")
            return
        }

        guard let contact = message.conversation?.contact, contact.identity == receiverIdentity else {
            throw MediatorReflectedProcessorError.messageNotProcessed(message: "id: \(id.hexString)")
        }

        frameworkInjector.backgroundEntityManager.performAndWaitSave {
            message.sent = NSNumber(booleanLiteral: true)
            message.remoteSentDate = reflectedAt
        }
    }

    private func saveMessageSent(
        messageID: UInt64,
        receiverGroupID: UInt64,
        receiverGroupCreator: String,
        reflectedAt: Date
    ) throws {
        let id = messageID.littleEndianData
        guard let message = frameworkInjector.backgroundEntityManager.entityFetcher.ownMessage(with: id) else {
            DDLogError("Own message ID \(messageID.littleEndianData.hexString) to set as sent not found")
            return
        }

        guard let group = frameworkInjector.backgroundGroupManager.getGroup(conversation: message.conversation),
              group.groupID.elementsEqual(receiverGroupID.littleEndianData),
              group.groupCreatorIdentity == receiverGroupCreator else {
            throw MediatorReflectedProcessorError.messageNotProcessed(message: "id: \(id.hexString)")
        }

        frameworkInjector.backgroundEntityManager.performAndWaitSave {
            message.sent = NSNumber(booleanLiteral: true)
            message.remoteSentDate = reflectedAt
        }
    }
}
