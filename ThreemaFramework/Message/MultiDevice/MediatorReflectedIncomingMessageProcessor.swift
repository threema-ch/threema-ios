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

class MediatorReflectedIncomingMessageProcessor {

    private let frameworkInjector: FrameworkInjectorProtocol
    private let messageStore: MessageStoreProtocol
    private let messageProcessorDelegate: MessageProcessorDelegate
    private let reflectedAt: Date
    private let maxBytesToDecrypt: Int
    private let timeoutDownloadThumbnail: Int

    init(
        frameworkInjector: FrameworkInjectorProtocol,
        messageStore: MessageStoreProtocol,
        messageProcessorDelegate: MessageProcessorDelegate,
        reflectedAt: Date,
        maxBytesToDecrypt: Int,
        timeoutDownloadThumbnail: Int
    ) {
        self.frameworkInjector = frameworkInjector
        self.messageStore = messageStore
        self.messageProcessorDelegate = messageProcessorDelegate
        self.reflectedAt = reflectedAt
        self.maxBytesToDecrypt = maxBytesToDecrypt
        self.timeoutDownloadThumbnail = timeoutDownloadThumbnail
    }

    /// Process reflected incoming messages. Validate sender of message or group and determines
    /// message processor for saving into DB and download blob data.
    /// - Parameters:
    ///     - incomingMessage: Reflected incoming message from mediator
    ///     - abstractMessage: Incoming abstract message (decoded from `D2d_IncomingMessage.body`)
    func process(
        incomingMessage imsg: D2d_IncomingMessage,
        abstractMessage amsg: some AbstractMessage
    ) throws -> Promise<Void> {
        switch amsg.self {
        case is BoxAudioMessage:
            try process(incomingMessage: imsg, audioMessage: amsg as! BoxAudioMessage)
        case is BoxBallotCreateMessage:
            try process(incomingMessage: imsg, ballotCreateMessage: amsg as! BoxBallotCreateMessage)
        case is BoxBallotVoteMessage:
            try process(incomingMessage: imsg, ballotVoteMessage: amsg as! BoxBallotVoteMessage)
        case is BoxFileMessage:
            try process(incomingMessage: imsg, fileMessage: amsg as! BoxFileMessage)
        case is BoxImageMessage:
            try process(incomingMessage: imsg, imageMessage: amsg as! BoxImageMessage)
        case is BoxLocationMessage:
            try process(incomingMessage: imsg, locationMessage: amsg as! BoxLocationMessage)
        case is BoxTextMessage:
            try process(incomingMessage: imsg, textMessage: amsg as! BoxTextMessage)
        case is BoxVideoMessage:
            try process(incomingMessage: imsg, videoMessage: amsg as! BoxVideoMessage)
        case is ContactDeletePhotoMessage:
            process(contactDeletePhotoMessage: amsg as! ContactDeletePhotoMessage)
        case is ContactRequestPhotoMessage:
            process(contactRequestPhotoMessage: amsg as! ContactRequestPhotoMessage)
        case is ContactSetPhotoMessage:
            process(contactSetPhotoMessage: amsg as! ContactSetPhotoMessage)
        case is DeliveryReceiptMessage:
            try process(incomingMessage: imsg, deliveryReceiptMessage: amsg as! DeliveryReceiptMessage)
        case is DeleteMessage:
            try process(incomingMessage: imsg, deleteMessage: amsg as! DeleteMessage)
        case is DeleteGroupMessage:
            try process(incomingMessage: imsg, deleteGroupMessage: amsg as! DeleteGroupMessage)
        case is EditMessage:
            try process(incomingMessage: imsg, editMessage: amsg as! EditMessage)
        case is EditGroupMessage:
            try process(incomingMessage: imsg, editGroupMessage: amsg as! EditGroupMessage)
        case is GroupCreateMessage:
            try process(groupCreateMessage: amsg as! GroupCreateMessage)
        case is GroupDeletePhotoMessage:
            try process(groupDeletePhotoMessage: amsg as! GroupDeletePhotoMessage)
        case is GroupLeaveMessage:
            process(groupLeaveMessage: amsg as! GroupLeaveMessage)
        case is GroupRenameMessage:
            try process(groupRenameMessage: amsg as! GroupRenameMessage)
        case is GroupSetPhotoMessage:
            try process(groupSetPhotoMessage: amsg as! GroupSetPhotoMessage)
        case is GroupDeliveryReceiptMessage:
            try process(incomingMessage: imsg, groupDeliveryReceiptMessage: amsg as! GroupDeliveryReceiptMessage)
        case is GroupAudioMessage:
            try process(incomingMessage: imsg, groupAudioMessage: amsg as! GroupAudioMessage)
        case is GroupBallotCreateMessage:
            try process(incomingMessage: imsg, groupBallotCreateMessage: amsg as! GroupBallotCreateMessage)
        case is GroupBallotVoteMessage:
            try process(incomingMessage: imsg, groupBallotVoteMessage: amsg as! GroupBallotVoteMessage)
        case is GroupFileMessage:
            try process(incomingMessage: imsg, groupFileMessage: amsg as! GroupFileMessage)
        case is GroupImageMessage:
            try process(incomingMessage: imsg, groupImageMessage: amsg as! GroupImageMessage)
        case is GroupLocationMessage:
            try process(incomingMessage: imsg, groupLocationMessage: amsg as! GroupLocationMessage)
        case is GroupTextMessage:
            try process(incomingMessage: imsg, groupTextMessage: amsg as! GroupTextMessage)
        case is GroupVideoMessage:
            try process(incomingMessage: imsg, groupVideoMessage: amsg as! GroupVideoMessage)
        case is BoxVoIPCallOfferMessage:
            try process(incomingMessage: imsg, voipCallOfferMessage: amsg as! BoxVoIPCallOfferMessage)
        case is BoxVoIPCallAnswerMessage:
            try process(incomingMessage: imsg, voipCallAnswerMessage: amsg as! BoxVoIPCallAnswerMessage)
        case is BoxVoIPCallIceCandidatesMessage:
            try process(
                incomingMessage: imsg,
                voipCallIceCandidatesMessage: amsg as! BoxVoIPCallIceCandidatesMessage
            )
        case is BoxVoIPCallHangupMessage:
            try process(incomingMessage: imsg, voipCallHangupMessage: amsg as! BoxVoIPCallHangupMessage)
        case is BoxVoIPCallRingingMessage:
            try process(incomingMessage: imsg, voipCallRingingMessage: amsg as! BoxVoIPCallRingingMessage)
        case is GroupCallStartMessage:
            try process(incomingMessage: imsg, groupCallStartMessage: amsg as! GroupCallStartMessage)
        case is TypingIndicatorMessage:
            try process(incomingMessage: imsg, typingIndicatorMessage: amsg as! TypingIndicatorMessage)
        default:
            Promise { $0.reject(MediatorReflectedProcessorError.messageWontProcessed(
                message: "Reflected incoming message type \(imsg.loggingDescription) will be not processed"
            ))
            }
        }
    }

    // MARK: Process reflected incoming 1:1 chat messages

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        audioMessage amsg: BoxAudioMessage
    ) throws -> Promise<Void> {
        try messageStore.save(
            audioMessage: amsg,
            conversationIdentity: getSenderIdentity(for: imsg),
            createdAt: getCreatedAt(for: imsg),
            reflectedAt: reflectedAt
        )
        return Promise()
    }

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        ballotCreateMessage amsg: BoxBallotCreateMessage
    ) throws -> Promise<Void> {
        // TODO: Because fromIdentity is missing of reflected messages
        amsg.fromIdentity = imsg.senderIdentity

        return try messageStore.save(
            ballotCreateMessage: amsg,
            conversationIdentity: getSenderIdentity(for: imsg),
            createdAt: getCreatedAt(for: imsg),
            reflectedAt: reflectedAt,
            isOutgoing: false
        )
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
        try messageStore.save(
            fileMessage: amsg,
            conversationIdentity: getSenderIdentity(for: imsg),
            createdAt: getCreatedAt(for: imsg),
            reflectedAt: reflectedAt,
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
            senderIdentity: getSenderIdentity(for: imsg),
            createdAt: getCreatedAt(for: imsg),
            reflectedAt: reflectedAt,
            maxBytesToDecrypt: maxBytesToDecrypt
        )
    }

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        locationMessage amsg: BoxLocationMessage
    ) throws -> Promise<Void> {
        try messageStore.save(
            locationMessage: amsg,
            conversationIdentity: getSenderIdentity(for: imsg),
            createdAt: getCreatedAt(for: imsg),
            reflectedAt: reflectedAt,
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
            conversationIdentity: getSenderIdentity(for: imsg),
            createdAt: getCreatedAt(for: imsg),
            reflectedAt: reflectedAt,
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
            senderIdentity: getSenderIdentity(for: imsg),
            createdAt: getCreatedAt(for: imsg),
            reflectedAt: reflectedAt,
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

    // MARK: Process reflected incoming delivery receipts / typing indicators

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        deliveryReceiptMessage amsg: DeliveryReceiptMessage
    ) throws -> Promise<Void> {
        try messageStore.save(
            deliveryReceiptMessage: amsg,
            createdAt: getCreatedAt(for: imsg),
            isOutgoing: false
        )
        return Promise()
    }
    
    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        typingIndicatorMessage amsg: TypingIndicatorMessage
    ) throws -> Promise<Void> {
        TypingIndicatorManager.sharedInstance().setTypingIndicatorForIdentity(imsg.senderIdentity, typing: amsg.typing)
        return Promise()
    }

    // MARK: Process reflected incoming delete / edit message

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        deleteMessage amsg: DeleteMessage
    ) throws -> Promise<Void> {
        try messageStore.save(
            deleteMessage: amsg,
            createdAt: getCreatedAt(for: imsg),
            isOutgoing: false
        )
        return Promise()
    }

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        deleteGroupMessage amsg: DeleteGroupMessage
    ) throws -> Promise<Void> {
        try messageStore.save(
            deleteGroupMessage: amsg,
            createdAt: getCreatedAt(for: imsg),
            isOutgoing: false
        )
        return Promise()
    }

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        editMessage amsg: EditMessage
    ) throws -> Promise<Void> {
        try messageStore.save(
            editMessage: amsg,
            createdAt: getCreatedAt(for: imsg),
            isOutgoing: false
        )
        return Promise()
    }

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        editGroupMessage amsg: EditGroupMessage
    ) throws -> Promise<Void> {
        try messageStore.save(
            editGroupMessage: amsg,
            createdAt: getCreatedAt(for: imsg),
            isOutgoing: false
        )
        return Promise()
    }

    // MARK: Process reflected incoming group control messages

    private func process(
        groupCreateMessage amsg: GroupCreateMessage
    ) throws -> Promise<Void> {
        try messageStore.save(groupCreateMessage: amsg)
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
    
    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        groupDeliveryReceiptMessage amsg: GroupDeliveryReceiptMessage
    ) throws -> Promise<Void> {
        try messageStore.save(
            groupDeliveryReceiptMessage: amsg,
            createdAt: getCreatedAt(for: imsg),
            isOutgoing: false
        )
        return Promise()
    }

    // MARK: Process reflected incoming group message

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        groupAudioMessage amsg: GroupAudioMessage
    ) throws -> Promise<Void> {
        try getGroup(for: amsg)
        try messageStore.save(
            groupAudioMessage: amsg,
            senderIdentity: getSenderIdentity(for: imsg),
            createdAt: getCreatedAt(for: imsg),
            reflectedAt: reflectedAt
        )
        return Promise()
    }

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        groupBallotCreateMessage amsg: GroupBallotCreateMessage
    ) throws -> Promise<Void> {
        try getGroup(for: amsg)

        return try messageStore.save(
            groupBallotCreateMessage: amsg,
            senderIdentity: getSenderIdentity(for: imsg),
            createdAt: getCreatedAt(for: imsg),
            reflectedAt: reflectedAt,
            isOutgoing: false
        )
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
        return try messageStore.save(
            groupFileMessage: amsg,
            senderIdentity: getSenderIdentity(for: imsg),
            createdAt: getCreatedAt(for: imsg),
            reflectedAt: reflectedAt,
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
            senderIdentity: getSenderIdentity(for: imsg),
            createdAt: getCreatedAt(for: imsg),
            reflectedAt: reflectedAt,
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
            senderIdentity: getSenderIdentity(for: imsg),
            createdAt: getCreatedAt(for: imsg),
            reflectedAt: reflectedAt,
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
            senderIdentity: getSenderIdentity(for: imsg),
            messageID: imsg.messageID.littleEndianData,
            createdAt: getCreatedAt(for: imsg),
            reflectedAt: reflectedAt,
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
            senderIdentity: getSenderIdentity(for: imsg),
            createdAt: getCreatedAt(for: imsg),
            reflectedAt: reflectedAt,
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
        return processVoIPCallMessage(
            abstractMessage: amsg,
            voipMessage: msg,
            identity: senderIdentity,
            isOutgoing: false
        )
    }

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        voipCallAnswerMessage amsg: BoxVoIPCallAnswerMessage
    ) throws -> Promise<Void> {
        let senderIdentity = try getSenderIdentity(for: imsg)
        guard let msg = VoIPCallMessageDecoder.decodeVoIPCallAnswer(from: amsg) else {
            throw MediatorReflectedProcessorError.messageNotProcessed(message: imsg.loggingDescription)
        }
        return processVoIPCallMessage(
            abstractMessage: amsg,
            voipMessage: msg,
            identity: senderIdentity,
            isOutgoing: false
        )
    }

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        voipCallIceCandidatesMessage amsg: BoxVoIPCallIceCandidatesMessage
    ) throws -> Promise<Void> {
        let senderIdentity = try getSenderIdentity(for: imsg)
        guard let msg = VoIPCallMessageDecoder.decodeVoIPCallIceCandidates(from: amsg) else {
            throw MediatorReflectedProcessorError.messageNotProcessed(message: imsg.loggingDescription)
        }
        return processVoIPCallMessage(
            abstractMessage: amsg,
            voipMessage: msg,
            identity: senderIdentity,
            isOutgoing: false
        )
    }

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        voipCallHangupMessage amsg: BoxVoIPCallHangupMessage
    ) throws -> Promise<Void> {
        let senderIdentity = try getSenderIdentity(for: imsg)
        guard let msg = VoIPCallMessageDecoder.decodeVoIPCallHangup(from: amsg, contactIdentity: senderIdentity) else {
            throw MediatorReflectedProcessorError.messageNotProcessed(message: imsg.loggingDescription)
        }
        return processVoIPCallMessage(
            abstractMessage: amsg,
            voipMessage: msg,
            identity: senderIdentity,
            isOutgoing: false
        )
    }

    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        voipCallRingingMessage amsg: BoxVoIPCallRingingMessage
    ) throws -> Promise<Void> {
        let senderIdentity = try getSenderIdentity(for: imsg)
        guard let msg = VoIPCallMessageDecoder.decodeVoIPCallRinging(from: amsg, contactIdentity: senderIdentity) else {
            throw MediatorReflectedProcessorError.messageNotProcessed(message: imsg.loggingDescription)
        }
        return processVoIPCallMessage(
            abstractMessage: amsg,
            voipMessage: msg,
            identity: senderIdentity,
            isOutgoing: false
        )
    }

    private func processVoIPCallMessage(
        abstractMessage amsg: AbstractMessage,
        voipMessage: VoIPCallMessageProtocol,
        identity: String,
        isOutgoing: Bool
    ) -> Promise<Void> {
        Promise { seal in
            if !isOutgoing {
                messageProcessorDelegate.incomingMessageStarted(amsg)
            }

            messageProcessorDelegate.processVoIPCall(voipMessage as! NSObject, identity: identity) { delegate in
                if !isOutgoing {
                    delegate.incomingMessageFinished(amsg)
                }

                if AppGroup.getCurrentType() == AppGroupTypeNotificationExtension,
                   !(voipMessage is VoIPCallOfferMessage),
                   !(voipMessage is VoIPCallHangupMessage) {
                    seal.reject(MediatorReflectedProcessorError.doNotAckIncomingVoIPMessage)
                    return
                }

                seal.fulfill_()
            } onError: { error in
                seal.reject(error)
            }
        }
    }
    
    // MARK: Process Incoming Group Call Messages
    
    private func process(
        incomingMessage imsg: D2d_IncomingMessage,
        groupCallStartMessage amsg: GroupCallStartMessage
    ) throws -> Promise<Void> {
        guard BusinessInjector().settingsStore.enableThreemaGroupCalls else {
            throw MediatorReflectedProcessorError
                .messageWontProcessed(message: "[GroupCall] GroupCalls are not enabled. Skip.")
        }
        
        messageProcessorDelegate.incomingMessageStarted(amsg)
        
        try getGroup(for: amsg)
        return try messageStore.save(
            groupCallStartMessage: amsg,
            senderIdentity: getSenderIdentity(for: imsg),
            createdAt: getCreatedAt(for: imsg),
            reflectedAt: reflectedAt,
            isOutgoing: false
        )
    }

    // MARK: Misc

    private func getSenderIdentity(for imsg: D2d_IncomingMessage) throws -> String {
        try frameworkInjector.entityManager.performAndWait {
            guard let senderIdentity = self.frameworkInjector.entityManager.entityFetcher.contact(
                for: imsg.senderIdentity
            )?.identity else {
                throw MediatorReflectedProcessorError.contactNotFound(identity: imsg.senderIdentity)
            }

            return senderIdentity
        }
    }

    @discardableResult
    private func getGroup(for amsg: AbstractGroupMessage) throws -> (groupID: Data, groupCreatorIdentity: String) {
        try frameworkInjector.entityManager.performAndWait {
            guard let group = self.frameworkInjector.groupManager.getGroup(
                amsg.groupID,
                creator: amsg.groupCreator
            ) else {
                throw MediatorReflectedProcessorError.groupNotFound(message: amsg.loggingDescription)
            }

            return (group.groupID, group.groupCreatorIdentity)
        }
    }

    private func getCreatedAt(for imsg: D2d_IncomingMessage) -> Date {
        imsg.createdAt.date ?? .now
    }
}
