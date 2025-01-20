//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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

protocol MessageStoreProtocol {

    func save(
        audioMessage: BoxAudioMessage,
        conversationIdentity: String,
        createdAt: Date,
        reflectedAt: Date
    ) throws

    func save(
        fileMessage: BoxFileMessage,
        conversationIdentity: String,
        createdAt: Date,
        reflectedAt: Date,
        isOutgoing: Bool,
        timeoutDownloadThumbnail: Int
    ) -> Promise<Void>

    func save(
        textMessage: BoxTextMessage,
        conversationIdentity: String,
        createdAt: Date,
        reflectedAt: Date,
        isOutgoing: Bool
    ) throws

    func save(contactDeletePhotoMessage amsg: ContactDeletePhotoMessage)
    
    func save(contactSetPhotoMessage: ContactSetPhotoMessage) -> Promise<Void>

    func save(
        deliveryReceiptMessage: DeliveryReceiptMessage,
        createdAt: Date,
        isOutgoing: Bool
    ) throws

    func save(
        deleteMessage: DeleteMessage,
        createdAt: Date,
        isOutgoing: Bool
    ) throws

    func save(
        deleteGroupMessage: DeleteGroupMessage,
        createdAt: Date,
        isOutgoing: Bool
    ) throws

    func save(
        editMessage: EditMessage,
        createdAt: Date,
        isOutgoing: Bool
    ) throws

    func save(
        editGroupMessage: EditGroupMessage,
        createdAt: Date,
        isOutgoing: Bool
    ) throws

    func save(
        groupAudioMessage: GroupAudioMessage,
        senderIdentity: String,
        createdAt: Date,
        reflectedAt: Date
    ) throws

    func save(groupCreateMessage amsg: GroupCreateMessage) throws -> Promise<Void>

    func save(groupDeletePhotoMessage amsg: GroupDeletePhotoMessage) -> Promise<Void>

    func save(groupLeaveMessage amsg: GroupLeaveMessage)

    func save(groupRenameMessage amsg: GroupRenameMessage) -> Promise<Void>

    func save(
        groupFileMessage: GroupFileMessage,
        senderIdentity: String,
        createdAt: Date,
        reflectedAt: Date,
        isOutgoing: Bool,
        timeoutDownloadThumbnail: Int
    ) -> Promise<Void>

    func save(
        imageMessage: AbstractMessage,
        senderIdentity: String,
        createdAt: Date,
        reflectedAt: Date,
        maxBytesToDecrypt: Int
    ) throws -> Promise<Void>

    func save(
        groupLocationMessage: GroupLocationMessage,
        senderIdentity: String,
        createdAt: Date,
        reflectedAt: Date,
        isOutgoing: Bool
    ) throws

    func save(
        groupBallotCreateMessage: GroupBallotCreateMessage,
        senderIdentity: String,
        createdAt: Date,
        reflectedAt: Date,
        isOutgoing: Bool
    ) throws -> Promise<Void>

    func save(groupBallotVoteMessage: GroupBallotVoteMessage) throws

    func save(groupSetPhotoMessage amsg: GroupSetPhotoMessage) -> Promise<Void>
    
    func save(
        groupDeliveryReceiptMessage: GroupDeliveryReceiptMessage,
        createdAt: Date,
        isOutgoing: Bool
    ) throws

    func save(
        groupTextMessage: GroupTextMessage,
        senderIdentity: String,
        messageID: Data,
        createdAt: Date,
        reflectedAt: Date,
        isOutgoing: Bool
    ) throws

    func save(
        videoMessage: AbstractMessage,
        senderIdentity: String,
        createdAt: Date,
        reflectedAt: Date,
        maxBytesToDecrypt: Int
    ) throws -> Promise<Void>

    func save(
        locationMessage: BoxLocationMessage,
        conversationIdentity: String,
        createdAt: Date,
        reflectedAt: Date,
        isOutgoing: Bool
    ) throws

    func save(
        ballotCreateMessage: BoxBallotCreateMessage,
        conversationIdentity: String,
        createdAt: Date,
        reflectedAt: Date,
        isOutgoing: Bool
    ) throws -> Promise<Void>

    func save(ballotVoteMessage: BoxBallotVoteMessage) throws
    
    func save(
        groupCallStartMessage: GroupCallStartMessage,
        senderIdentity: String,
        createdAt: Date,
        reflectedAt: Date,
        isOutgoing: Bool
    ) throws -> Promise<Void>
    
    func save(
        reactionMessage: ReactionMessage,
        conversationIdentity: String,
        createdAt: Date,
        isOutgoing: Bool
    ) throws
    
    func save(
        groupReactionMessage: GroupReactionMessage,
        senderIdentity: String,
        createdAt: Date,
        isOutgoing: Bool
    ) throws
}
