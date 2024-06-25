//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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
import ThreemaProtocols
@testable import ThreemaFramework

class MessageStoreMock: MessageStoreProtocol {

    struct SaveGroupTextMessageParam {
        let groupTextMessage: GroupTextMessage
        let senderIdentity: String
        let messageID: Data
        let createdAt: Date
        let reflectedAt: Date
        let isOutgoing: Bool
    }

    var saveGroupTextMessageCalls = [SaveGroupTextMessageParam]()

    struct SaveTextMessageParam {
        let textMessage: BoxTextMessage
        let conversationIdentity: String
        let createdAt: Date
        let reflectedAt: Date
        let isOutgoing: Bool
    }

    var saveTextMessageCalls = [SaveTextMessageParam]()

    func save(
        audioMessage: BoxAudioMessage,
        conversationIdentity: String,
        createdAt: Date,
        reflectedAt: Date
    ) throws {
        // no-op
    }

    func save(
        fileMessage: BoxFileMessage,
        conversationIdentity: String,
        createdAt: Date,
        reflectedAt: Date,
        isOutgoing: Bool,
        timeoutDownloadThumbnail: Int
    ) -> Promise<Void> {
        Promise()
    }

    func save(
        textMessage: BoxTextMessage,
        conversationIdentity: String,
        createdAt: Date,
        reflectedAt: Date,
        isOutgoing: Bool
    ) throws {
        saveTextMessageCalls.append(
            SaveTextMessageParam(
                textMessage: textMessage,
                conversationIdentity: conversationIdentity,
                createdAt: createdAt,
                reflectedAt: reflectedAt,
                isOutgoing: isOutgoing
            )
        )
    }

    func save(contactDeletePhotoMessage amsg: ContactDeletePhotoMessage) {
        // no-op
    }

    func save(contactSetPhotoMessage: ContactSetPhotoMessage) -> Promise<Void> {
        Promise()
    }

    func save(deliveryReceiptMessage: DeliveryReceiptMessage, createdAt: Date, isOutgoing: Bool) throws {
        // no-op
    }

    func save(deleteMessage: ThreemaFramework.DeleteMessage, createdAt: Date, isOutgoing: Bool) throws {
        // no-op
    }

    func save(deleteGroupMessage: ThreemaFramework.DeleteGroupMessage, createdAt: Date, isOutgoing: Bool) throws {
        // no-op
    }

    func save(editMessage: ThreemaFramework.EditMessage, createdAt: Date, isOutgoing: Bool) throws {
        // no-op
    }

    func save(editGroupMessage: ThreemaFramework.EditGroupMessage, createdAt: Date, isOutgoing: Bool) throws {
        // no-op
    }

    func save(
        groupAudioMessage: GroupAudioMessage,
        senderIdentity: String,
        createdAt: Date,
        reflectedAt: Date
    ) throws {
        // no-op
    }

    func save(groupCreateMessage amsg: GroupCreateMessage) -> Promise<Void> {
        Promise()
    }

    func save(groupDeletePhotoMessage amsg: GroupDeletePhotoMessage) -> Promise<Void> {
        Promise()
    }

    func save(groupLeaveMessage amsg: GroupLeaveMessage) {
        // no-op
    }

    func save(groupRenameMessage amsg: GroupRenameMessage) -> Promise<Void> {
        Promise()
    }

    func save(groupDeliveryReceiptMessage: GroupDeliveryReceiptMessage, createdAt: Date, isOutgoing: Bool) throws {
        // no-op
    }

    func save(
        groupFileMessage: GroupFileMessage,
        senderIdentity: String,
        createdAt: Date,
        reflectedAt: Date,
        isOutgoing: Bool,
        timeoutDownloadThumbnail: Int
    ) -> Promise<Void> {
        Promise()
    }

    func save(
        imageMessage: AbstractMessage,
        senderIdentity: String,
        createdAt: Date,
        reflectedAt: Date,
        maxBytesToDecrypt: Int
    ) throws -> Promise<Void> {
        Promise()
    }

    func save(
        groupLocationMessage: GroupLocationMessage,
        senderIdentity: String,
        createdAt: Date,
        reflectedAt: Date,
        isOutgoing: Bool
    ) throws {
        // no-op
    }

    func save(
        groupBallotCreateMessage: GroupBallotCreateMessage,
        senderIdentity: String,
        createdAt: Date,
        reflectedAt: Date,
        isOutgoing: Bool
    ) throws -> Promise<Void> {
        Promise()
    }

    func save(groupBallotVoteMessage: GroupBallotVoteMessage) throws {
        // no-op
    }

    func save(groupSetPhotoMessage amsg: GroupSetPhotoMessage) -> Promise<Void> {
        Promise()
    }

    func save(
        groupTextMessage: GroupTextMessage,
        senderIdentity: String,
        messageID: Data,
        createdAt: Date,
        reflectedAt: Date,
        isOutgoing: Bool
    ) throws {
        saveGroupTextMessageCalls.append(
            SaveGroupTextMessageParam(
                groupTextMessage: groupTextMessage,
                senderIdentity: senderIdentity,
                messageID: messageID,
                createdAt: createdAt,
                reflectedAt: reflectedAt,
                isOutgoing: isOutgoing
            )
        )
    }

    func save(
        videoMessage: AbstractMessage,
        senderIdentity: String,
        createdAt: Date,
        reflectedAt: Date,
        maxBytesToDecrypt: Int
    ) throws -> Promise<Void> {
        Promise()
    }

    func save(
        locationMessage: BoxLocationMessage,
        conversationIdentity: String,
        createdAt: Date,
        reflectedAt: Date,
        isOutgoing: Bool
    ) throws {
        // no-op
    }

    func save(
        ballotCreateMessage: BoxBallotCreateMessage,
        conversationIdentity: String,
        createdAt: Date,
        reflectedAt: Date,
        isOutgoing: Bool
    ) throws -> Promise<Void> {
        Promise()
    }

    func save(ballotVoteMessage: BoxBallotVoteMessage) throws {
        // no-op
    }

    func save(
        groupCallStartMessage: GroupCallStartMessage,
        senderIdentity: String,
        createdAt: Date,
        reflectedAt: Date,
        isOutgoing: Bool
    ) throws -> Promise<Void> {
        Promise()
    }
}
