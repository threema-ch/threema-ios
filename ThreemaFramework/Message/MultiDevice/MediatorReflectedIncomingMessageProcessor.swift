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

import CocoaLumberjackSwift
import Foundation
import PromiseKit

class MediatorReflectedIncomingMessageProcessor {

    private let frameworkInjector: FrameworkInjectorProtocol
    private let messageStore: MessageStoreProtocol
    private let messageProcessorDelegate: MessageProcessorDelegate
    private let timestamp: Date
    private let maxBytesToDecrypt: Int
    private let timeoutDownloadThumbnail: Int

    init(
        frameworkInjector: FrameworkInjectorProtocol,
        messageStore: MessageStoreProtocol,
        messageProcessorDelegate: MessageProcessorDelegate,
        timestamp: Date,
        maxBytesToDecrypt: Int,
        timeoutDownloadThumbnail: Int
    ) {
        self.frameworkInjector = frameworkInjector
        self.messageStore = messageStore
        self.messageProcessorDelegate = messageProcessorDelegate
        self.timestamp = timestamp
        self.maxBytesToDecrypt = maxBytesToDecrypt
        self.timeoutDownloadThumbnail = timeoutDownloadThumbnail
    }

    /// Process reflected incoming messages. Validate sender of message or group and determines
    /// message processor for saving into DB and download blob data.
    /// - Parameters:
    ///     - incomingMessage: Reflected incoming message from mediator
    ///     - abstractMessage: Incoming abstract message (decoded from `D2d_IncomingMessage.body`)
    func process<T: AbstractMessage>(
        incomingMessage imsg: D2d_IncomingMessage,
        abstractMessage amsg: T
    ) throws -> Promise<Void> {
        switch amsg.self {
        case is BoxAudioMessage:
            return try process(incomingMessage: imsg, audioMessage: amsg as! BoxAudioMessage)
        case is BoxBallotCreateMessage:
            return try process(incomingMessage: imsg, ballotCreateMessage: amsg as! BoxBallotCreateMessage)
        case is BoxBallotVoteMessage:
            return try process(incomingMessage: imsg, ballotVoteMessage: amsg as! BoxBallotVoteMessage)
        case is BoxFileMessage:
            return try process(incomingMessage: imsg, fileMessage: amsg as! BoxFileMessage)
        case is BoxImageMessage:
            return try process(incomingMessage: imsg, imageMessage: amsg as! BoxImageMessage)
        case is BoxLocationMessage:
            return try process(incomingMessage: imsg, locationMessage: amsg as! BoxLocationMessage)
        case is BoxTextMessage:
            return try process(incomingMessage: imsg, textMessage: amsg as! BoxTextMessage)
        case is BoxVideoMessage:
            return try process(incomingMessage: imsg, videoMessage: amsg as! BoxVideoMessage)
        case is ContactDeletePhotoMessage:
            return process(contactDeletePhotoMessage: amsg as! ContactDeletePhotoMessage)
        case is ContactRequestPhotoMessage:
            return process(contactRequestPhotoMessage: amsg as! ContactRequestPhotoMessage)
        case is ContactSetPhotoMessage:
            return process(contactSetPhotoMessage: amsg as! ContactSetPhotoMessage)
        case is DeliveryReceiptMessage:
            return try process(incomingMessage: imsg, deliveryReceiptMessage: amsg as! DeliveryReceiptMessage)
        case is GroupCreateMessage:
            return try process(groupCreateMessage: amsg as! GroupCreateMessage)
        case is GroupDeletePhotoMessage:
            return try process(groupDeletePhotoMessage: amsg as! GroupDeletePhotoMessage)
        case is GroupLeaveMessage:
            return process(groupLeaveMessage: amsg as! GroupLeaveMessage)
        case is GroupRenameMessage:
            return try process(groupRenameMessage: amsg as! GroupRenameMessage)
        case is GroupSetPhotoMessage:
            return try process(groupSetPhotoMessage: amsg as! GroupSetPhotoMessage)
        case is GroupAudioMessage:
            return try process(incomingMessage: imsg, groupAudioMessage: amsg as! GroupAudioMessage)
        case is GroupBallotCreateMessage:
            return try process(incomingMessage: imsg, groupBallotCreateMessage: amsg as! GroupBallotCreateMessage)
        case is GroupBallotVoteMessage:
            return try process(incomingMessage: imsg, groupBallotVoteMessage: amsg as! GroupBallotVoteMessage)
        case is GroupFileMessage:
            return try process(incomingMessage: imsg, groupFileMessage: amsg as! GroupFileMessage)
        case is GroupImageMessage:
            return try process(incomingMessage: imsg, groupImageMessage: amsg as! GroupImageMessage)
        case is GroupLocationMessage:
            return try process(incomingMessage: imsg, groupLocationMessage: amsg as! GroupLocationMessage)
        case is GroupTextMessage:
            return try process(incomingMessage: imsg, groupTextMessage: amsg as! GroupTextMessage)
        case is GroupVideoMessage:
            return try process(incomingMessage: imsg, groupVideoMessage: amsg as! GroupVideoMessage)
        case is BoxVoIPCallOfferMessage:
            return try process(incomingMessage: imsg, voipCallOfferMessage: amsg as! BoxVoIPCallOfferMessage)
        case is BoxVoIPCallAnswerMessage:
            return try process(incomingMessage: imsg, voipCallAnswerMessage: amsg as! BoxVoIPCallAnswerMessage)
        case is BoxVoIPCallIceCandidatesMessage:
            return try process(
                incomingMessage: imsg,
                voipCallIceCandidatesMessage: amsg as! BoxVoIPCallIceCandidatesMessage
            )
        case is BoxVoIPCallHangupMessage:
            return try process(incomingMessage: imsg, voipCallHangupMessage: amsg as! BoxVoIPCallHangupMessage)
        case is BoxVoIPCallRingingMessage:
            return try process(incomingMessage: imsg, voipCallRingingMessage: amsg as! BoxVoIPCallRingingMessage)
        default:
            return Promise { $0.reject(
                MediatorReflectedProcessorError.messageDecodeFailed(message: imsg.loggingDescription)
            ) }
        }
    }

    // MARK: Process reflected incoming 1:1 chat messages

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        audioMessage amsg: BoxAudioMessage
    ) throws -> Promise<Void> {
        try messageStore.save(
            audioMessage: amsg,
            conversationIdentity: try getSenderIdentity(for: imsg),
            createdAt: imsg.createdAt,
            timestamp: timestamp
        )
        return Promise()
    }

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        ballotCreateMessage amsg: BoxBallotCreateMessage
    ) throws -> Promise<Void> {
        // TODO: Because fromIdentity is missing of reflected messages
        amsg.fromIdentity = imsg.senderIdentity

        try messageStore.save(
            ballotCreateMessage: amsg,
            conversationIdentity: try getSenderIdentity(for: imsg),
            createdAt: imsg.createdAt,
            timestamp: timestamp,
            isOutgoing: false
        )
        return Promise()
    }

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        ballotVoteMessage amsg: BoxBallotVoteMessage
    ) throws -> Promise<Void> {
        // TODO: Because fromIdentity is missing of reflected messages
        amsg.fromIdentity = imsg.senderIdentity

        try messageStore.save(ballotVoteMessage: amsg)
        return Promise()
    }

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        fileMessage amsg: BoxFileMessage
    ) throws -> Promise<Void> {
        messageStore.save(
            fileMessage: amsg,
            conversationIdentity: try getSenderIdentity(for: imsg),
            createdAt: imsg.createdAt,
            timestamp: timestamp,
            isOutgoing: false,
            timeoutDownloadThumbnail: timeoutDownloadThumbnail
        )
    }

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        imageMessage amsg: BoxImageMessage
    ) throws -> Promise<Void> {
        try messageStore.save(
            imageMessage: amsg,
            senderIdentity: try getSenderIdentity(for: imsg),
            createdAt: imsg.createdAt,
            timestamp: timestamp,
            maxBytesToDecrypt: maxBytesToDecrypt
        )
    }

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        locationMessage amsg: BoxLocationMessage
    ) throws -> Promise<Void> {
        try messageStore.save(
            locationMessage: amsg,
            conversationIdentity: try getSenderIdentity(for: imsg),
            createdAt: imsg.createdAt,
            timestamp: timestamp,
            isOutgoing: false
        )
        return Promise()
    }

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        textMessage amsg: BoxTextMessage
    ) throws -> Promise<Void> {
        try messageStore.save(
            textMessage: amsg,
            conversationIdentity: try getSenderIdentity(for: imsg),
            createdAt: imsg.createdAt,
            timestamp: timestamp,
            isOutgoing: false
        )
        return Promise()
    }

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        videoMessage amsg: BoxVideoMessage
    ) throws -> Promise<Void> {
        try messageStore.save(
            videoMessage: amsg,
            senderIdentity: try getSenderIdentity(for: imsg),
            createdAt: imsg.createdAt,
            timestamp: timestamp,
            maxBytesToDecrypt: maxBytesToDecrypt
        )
    }

    // MARK: Process reflected incoming contact photo message

    private func process(
        contactDeletePhotoMessage amsg: ContactDeletePhotoMessage
    ) -> Promise<Void> {
        messageStore.save(contactDeletePhotoMessage: amsg)
        return Promise()
    }

    private func process(
        contactRequestPhotoMessage amsg: ContactRequestPhotoMessage
    ) -> Promise<Void> {
        frameworkInjector.contactStore.removeProfilePictureFlag(for: amsg.fromIdentity)
        return Promise()
    }

    private func process(
        contactSetPhotoMessage amsg: ContactSetPhotoMessage
    ) -> Promise<Void> {
        messageStore.save(contactSetPhotoMessage: amsg)
    }

    // MARK: Process reflected incoming delivery receipts

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        deliveryReceiptMessage amsg: DeliveryReceiptMessage
    ) throws -> Promise<Void> {
        try messageStore.save(
            deliveryReceiptMessage: amsg,
            createdAt: imsg.createdAt,
            isOutgoing: false
        )
        return Promise()
    }

    // MARK: Process reflected incoming group control messages

    private func process(
        groupCreateMessage amsg: GroupCreateMessage
    ) throws -> Promise<Void> {
        messageStore.save(groupCreateMessage: amsg)
        return Promise()
    }

    private func process(
        groupDeletePhotoMessage amsg: GroupDeletePhotoMessage
    ) throws -> Promise<Void> {
        try getGroup(for: amsg)
        return messageStore.save(groupDeletePhotoMessage: amsg)
    }

    private func process(
        groupLeaveMessage amsg: GroupLeaveMessage
    ) -> Promise<Void> {
        messageStore.save(groupLeaveMessage: amsg)
        return Promise()
    }

    private func process(
        groupRenameMessage amsg: GroupRenameMessage
    ) throws -> Promise<Void> {
        try getGroup(for: amsg)
        return messageStore.save(groupRenameMessage: amsg)
    }

    private func process(
        groupSetPhotoMessage amsg: GroupSetPhotoMessage
    ) throws -> Promise<Void> {
        try getGroup(for: amsg)
        return messageStore.save(groupSetPhotoMessage: amsg)
    }

    // MARK: Process reflected incoming group message

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        groupAudioMessage amsg: GroupAudioMessage
    ) throws -> Promise<Void> {
        try getGroup(for: amsg)
        try messageStore.save(
            groupAudioMessage: amsg,
            senderIdentity: try getSenderIdentity(for: imsg),
            createdAt: imsg.createdAt,
            timestamp: timestamp
        )
        return Promise()
    }

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        groupBallotCreateMessage amsg: GroupBallotCreateMessage
    ) throws -> Promise<Void> {
        try getGroup(for: amsg)
        try messageStore.save(
            groupBallotCreateMessage: amsg,
            senderIdentity: try getSenderIdentity(for: imsg),
            createdAt: imsg.createdAt,
            timestamp: timestamp,
            isOutgoing: false
        )
        return Promise()
    }

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        groupBallotVoteMessage amsg: GroupBallotVoteMessage
    ) throws -> Promise<Void> {
        // TODO: Because fromIdentity is missing of reflected messages
        amsg.fromIdentity = try getSenderIdentity(for: imsg)

        try getGroup(for: amsg)
        try messageStore.save(groupBallotVoteMessage: amsg)
        return Promise()
    }

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        groupFileMessage amsg: GroupFileMessage
    ) throws -> Promise<Void> {
        try getGroup(for: amsg)
        return messageStore.save(
            groupFileMessage: amsg,
            senderIdentity: try getSenderIdentity(for: imsg),
            createdAt: imsg.createdAt,
            timestamp: timestamp,
            isOutgoing: false,
            timeoutDownloadThumbnail: timeoutDownloadThumbnail
        )
    }

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        groupImageMessage amsg: GroupImageMessage
    ) throws -> Promise<Void> {
        try getGroup(for: amsg)
        return try messageStore.save(
            imageMessage: amsg,
            senderIdentity: try getSenderIdentity(for: imsg),
            createdAt: imsg.createdAt,
            timestamp: timestamp,
            maxBytesToDecrypt: maxBytesToDecrypt
        )
    }

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        groupLocationMessage amsg: GroupLocationMessage
    ) throws -> Promise<Void> {
        try getGroup(for: amsg)
        try messageStore.save(
            groupLocationMessage: amsg,
            senderIdentity: try getSenderIdentity(for: imsg),
            createdAt: imsg.createdAt,
            timestamp: timestamp,
            isOutgoing: false
        )
        return Promise()
    }

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        groupTextMessage amsg: GroupTextMessage
    ) throws -> Promise<Void> {
        try getGroup(for: amsg)
        try messageStore.save(
            groupTextMessage: amsg,
            senderIdentity: try getSenderIdentity(for: imsg),
            messageID: NSData.convertBytes(imsg.messageID),
            createdAt: imsg.createdAt,
            timestamp: timestamp,
            isOutgoing: false
        )
        return Promise()
    }

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        groupVideoMessage amsg: GroupVideoMessage
    ) throws -> Promise<Void> {
        try getGroup(for: amsg)
        return try messageStore.save(
            videoMessage: amsg,
            senderIdentity: try getSenderIdentity(for: imsg),
            createdAt: imsg.createdAt,
            timestamp: timestamp,
            maxBytesToDecrypt: maxBytesToDecrypt
        )
    }

    // MARK: Process reflected incoming VoIPCall messages

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        voipCallOfferMessage amsg: BoxVoIPCallOfferMessage
    ) throws -> Promise<Void> {
        let senderIdentity = try getSenderIdentity(for: imsg)
        guard let msg = VoIPCallMessageDecoder.decodeVoIPCallOffer(from: amsg) else {
            throw MediatorReflectedProcessorError.messageNotProcessed(message: imsg.loggingDescription)
        }
        processVoIPCallMessage(
            abstractMessage: amsg,
            voipMessage: msg,
            identity: senderIdentity,
            isOutgoing: false
        )
        return Promise()
    }

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        voipCallAnswerMessage amsg: BoxVoIPCallAnswerMessage
    ) throws -> Promise<Void> {
        let senderIdentity = try getSenderIdentity(for: imsg)
        guard let msg = VoIPCallMessageDecoder.decodeVoIPCallAnswer(from: amsg) else {
            throw MediatorReflectedProcessorError.messageNotProcessed(message: imsg.loggingDescription)
        }
        processVoIPCallMessage(
            abstractMessage: amsg,
            voipMessage: msg,
            identity: senderIdentity,
            isOutgoing: false
        )
        return Promise()
    }

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        voipCallIceCandidatesMessage amsg: BoxVoIPCallIceCandidatesMessage
    ) throws -> Promise<Void> {
        let senderIdentity = try getSenderIdentity(for: imsg)
        guard let msg = VoIPCallMessageDecoder.decodeVoIPCallIceCandidates(from: amsg) else {
            throw MediatorReflectedProcessorError.messageNotProcessed(message: imsg.loggingDescription)
        }
        processVoIPCallMessage(
            abstractMessage: amsg,
            voipMessage: msg,
            identity: senderIdentity,
            isOutgoing: false
        )
        return Promise()
    }

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        voipCallHangupMessage amsg: BoxVoIPCallHangupMessage
    ) throws -> Promise<Void> {
        let senderIdentity = try getSenderIdentity(for: imsg)
        guard let msg = VoIPCallMessageDecoder.decodeVoIPCallHangup(from: amsg, contactIdentity: senderIdentity) else {
            throw MediatorReflectedProcessorError.messageNotProcessed(message: imsg.loggingDescription)
        }
        processVoIPCallMessage(
            abstractMessage: amsg,
            voipMessage: msg,
            identity: senderIdentity,
            isOutgoing: false
        )
        return Promise()
    }

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        voipCallRingingMessage amsg: BoxVoIPCallRingingMessage
    ) throws -> Promise<Void> {
        let senderIdentity = try getSenderIdentity(for: imsg)
        guard let msg = VoIPCallMessageDecoder.decodeVoIPCallRinging(from: amsg, contactIdentity: senderIdentity) else {
            throw MediatorReflectedProcessorError.messageNotProcessed(message: imsg.loggingDescription)
        }
        processVoIPCallMessage(
            abstractMessage: amsg,
            voipMessage: msg,
            identity: senderIdentity,
            isOutgoing: false
        )
        return Promise()
    }

    private func processVoIPCallMessage(
        abstractMessage amsg: AbstractMessage,
        voipMessage: VoIPCallMessageProtocol,
        identity: String,
        isOutgoing: Bool
    ) {
        if !isOutgoing {
            messageProcessorDelegate.incomingMessageStarted(amsg)
        }

        messageProcessorDelegate.processVoIPCall(voipMessage as! NSObject, identity: identity) { delegate in
            if !isOutgoing {
                delegate.incomingMessageFinished(amsg, isPendingGroup: false)
            }
        }
    }

    // MARK: Misc

    private func getSenderIdentity(for imsg: D2d_IncomingMessage) throws -> String {
        var senderIdentity: String?

        frameworkInjector.backgroundEntityManager.performBlockAndWait {
            if let contact = self.frameworkInjector.backgroundEntityManager.entityFetcher.contact(
                for: imsg.senderIdentity
            ) {
                senderIdentity = contact.identity
            }
        }

        guard let sender = senderIdentity else {
            throw MediatorReflectedProcessorError.contactNotFound(message: imsg.loggingDescription)
        }
        return sender
    }

    @discardableResult
    private func getGroup(for amsg: AbstractGroupMessage) throws -> (groupID: Data, groupCreatorIdentity: String) {
        var groupID: Data?
        var groupCreatorIdentity: String?

        frameworkInjector.backgroundEntityManager.performBlockAndWait {
            if let grp = self.frameworkInjector.backgroundGroupManager.getGroup(
                amsg.groupID,
                creator: amsg.groupCreator
            ) {
                groupID = grp.groupID
                groupCreatorIdentity = grp.groupCreatorIdentity
            }
        }

        guard let id = groupID, let creator = groupCreatorIdentity else {
            throw MediatorReflectedProcessorError.groupNotFound(message: amsg.loggingDescription)
        }
        return (id, creator)
    }
}