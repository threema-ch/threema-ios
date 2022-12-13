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

class MessageStore: MessageStoreProtocol {

    private let frameworkInjector: FrameworkInjectorProtocol
    private let messageProcessorDelegate: MessageProcessorDelegate

    init(
        frameworkInjector: FrameworkInjectorProtocol,
        messageProcessorDelegate: MessageProcessorDelegate
    ) {
        self.frameworkInjector = frameworkInjector
        self.messageProcessorDelegate = messageProcessorDelegate
    }
    
    func save(
        audioMessage: BoxAudioMessage,
        conversationIdentity: String,
        createdAt: UInt64,
        timestamp: Date
    ) throws {
        messageProcessorDelegate.incomingMessageStarted(audioMessage)

        var msg: AudioMessageEntity?
        var err: Error?
        frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
            guard let conversation = self.frameworkInjector.backgroundEntityManager.conversation(
                for: conversationIdentity,
                createIfNotExisting: true
            ) else {
                err = MediatorReflectedProcessorError.conversationNotFound(message: audioMessage.loggingDescription)
                return
            }

            msg = self.frameworkInjector.backgroundEntityManager.entityCreator.audioMessageEntity(fromBox: audioMessage)
            msg?.conversation = conversation

            msg?.date = timestamp
            msg?.isOwn = NSNumber(booleanLiteral: false)

            conversation.lastMessage = msg
            conversation.lastUpdate = Date.now
        }
        if let err = err {
            throw err
        }

        if let msg = msg {
            messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: conversationIdentity)
        }

        messageProcessorDelegate.incomingMessageFinished(audioMessage, isPendingGroup: false)
    }

    func save(
        fileMessage: BoxFileMessage,
        conversationIdentity: String,
        createdAt: UInt64,
        timestamp: Date,
        isOutgoing: Bool,
        timeoutDownloadThumbnail: Int
    ) -> Promise<Void> {
        Promise { seal in
            if !isOutgoing {
                messageProcessorDelegate.incomingMessageStarted(fileMessage)
            }

            frameworkInjector.backgroundEntityManager.performBlockAndWait {
                guard let conversation = self.frameworkInjector.backgroundEntityManager.conversation(
                    for: conversationIdentity,
                    createIfNotExisting: true
                ) else {
                    seal
                        .reject(
                            MediatorReflectedProcessorError
                                .conversationNotFound(message: fileMessage.loggingDescription)
                        )
                    return
                }

                FileMessageDecoder.decodeMessage(
                    fromBox: fileMessage,
                    forConversation: conversation,
                    timeoutDownloadThumbnail: Int32(timeoutDownloadThumbnail),
                    entityManager: self.frameworkInjector.backgroundEntityManager,
                    onCompletion: { msg in
                        self.frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
                            msg?.id = fileMessage.messageID
                            msg?.date = timestamp
                            msg?.isOwn = NSNumber(booleanLiteral: isOutgoing)

                            // Origin of blob for reflected file message is always local
                            (msg as? FileMessageEntity)?.origin = NSNumber(booleanLiteral: true)

                            conversation.lastMessage = msg
                            conversation.lastUpdate = Date.now
                        }

                        if !isOutgoing {
                            if let msg = msg {
                                self.messageProcessorDelegate.incomingMessageChanged(
                                    msg,
                                    fromIdentity: conversationIdentity
                                )
                            }

                            self.messageProcessorDelegate.incomingMessageFinished(fileMessage, isPendingGroup: false)
                        }

                        seal.fulfill_()
                    }
                ) { error in
                    seal.reject(
                        MediatorReflectedProcessorError.messageNotProcessed(
                            message: "Could not process file message: \(error?.localizedDescription ?? "")"
                        )
                    )
                }
            }
        }
    }

    func save(
        textMessage: BoxTextMessage,
        conversationIdentity: String,
        createdAt: UInt64,
        timestamp: Date,
        isOutgoing: Bool
    ) throws {
        if !isOutgoing {
            messageProcessorDelegate.incomingMessageStarted(textMessage)
        }

        var msg: TextMessage?
        var err: Error?
        frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
            guard let conversation = self.frameworkInjector.backgroundEntityManager.conversation(
                for: conversationIdentity,
                createIfNotExisting: true
            ) else {
                err = MediatorReflectedProcessorError.conversationNotFound(message: textMessage.loggingDescription)
                return
            }

            msg = self.frameworkInjector.backgroundEntityManager.entityCreator.textMessage(fromBox: textMessage)
            msg?.conversation = conversation

            msg?.date = timestamp
            msg?.isOwn = NSNumber(booleanLiteral: isOutgoing)

            conversation.lastMessage = msg
            conversation.lastUpdate = Date.now
        }
        if let err = err {
            throw err
        }

        if !isOutgoing {
            if let msg = msg {
                messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: conversationIdentity)
            }

            messageProcessorDelegate.incomingMessageFinished(textMessage, isPendingGroup: false)
        }
    }

    func save(contactDeletePhotoMessage amsg: ContactDeletePhotoMessage) {
        frameworkInjector.contactStore.deleteProfilePicture(amsg.fromIdentity, shouldReflect: false)
        frameworkInjector.contactStore.removeProfilePictureRequest(amsg.fromIdentity)
        changedContact(with: amsg.fromIdentity)
    }

    func save(contactSetPhotoMessage: ContactSetPhotoMessage) -> Promise<Void> {
        syncLoadBlob(blobID: contactSetPhotoMessage.blobID, encryptionKey: contactSetPhotoMessage.encryptionKey)
            .then { (data: Data?) -> Promise<Void> in
                guard let data = data else {
                    throw MediatorReflectedProcessorError.downloadFailed(message: "Blob download failed, no data.")
                }

                self.frameworkInjector.backgroundEntityManager.performBlockAndWait {
                    let contact = self.frameworkInjector.backgroundEntityManager.entityFetcher
                        .contact(for: contactSetPhotoMessage.fromIdentity)
                    self.frameworkInjector.contactStore.updateProfilePicture(
                        contact?.identity,
                        imageData: data,
                        shouldReflect: false,
                        didFailWithError: nil
                    )
                }

                self.changedContact(with: contactSetPhotoMessage.fromIdentity)
                return Promise()
            }
    }

    func save(
        deliveryReceiptMessage: DeliveryReceiptMessage,
        createdAt: UInt64,
        isOutgoing: Bool
    ) throws {
        for id in deliveryReceiptMessage.receiptMessageIDs {
            if let messageID = id as? Data {
                if let msg = frameworkInjector.backgroundEntityManager.entityFetcher.message(with: messageID) {
                    if deliveryReceiptMessage.receiptType == DELIVERYRECEIPT_MSGRECEIVED {
                        frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
                            msg.delivered = true
                            msg.deliveryDate = deliveryReceiptMessage.date
                        }
                    }
                    else if deliveryReceiptMessage.receiptType == DELIVERYRECEIPT_MSGREAD {
                        if isOutgoing {
                            messageProcessorDelegate.outgoingMessageFinished(deliveryReceiptMessage)
                        }
                        else {
                            frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
                                msg.read = true
                                msg.readDate = deliveryReceiptMessage.date
                            }
                        }
                    }
                    messageProcessorDelegate.changedManagedObjectID(msg.objectID)
                }
                else {
                    throw MediatorReflectedProcessorError
                        .messageNotProcessed(message: deliveryReceiptMessage.loggingDescription)
                }
            }
        }
    }

    func save(
        groupAudioMessage: GroupAudioMessage,
        senderIdentity: String,
        createdAt: UInt64,
        timestamp: Date
    ) throws {
        messageProcessorDelegate.incomingMessageStarted(groupAudioMessage)

        var msg: AudioMessageEntity?
        var err: Error?
        frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
            guard let conversation = self.frameworkInjector.backgroundEntityManager.entityFetcher
                .conversation(for: groupAudioMessage) else {
                err = MediatorReflectedProcessorError
                    .conversationNotFound(message: groupAudioMessage.loggingDescription)
                return
            }
            guard let sender = self.frameworkInjector.backgroundEntityManager.entityFetcher
                .contact(for: senderIdentity) else {
                err = MediatorReflectedProcessorError.contactNotFound(message: groupAudioMessage.loggingDescription)
                return
            }

            msg = self.frameworkInjector.backgroundEntityManager.entityCreator
                .audioMessageEntity(fromGroupBox: groupAudioMessage)
            msg?.conversation = conversation
            msg?.sender = sender

            msg?.date = timestamp
            msg?.isOwn = NSNumber(booleanLiteral: false)

            conversation.lastMessage = msg
            conversation.lastUpdate = Date.now
        }
        if let err = err {
            throw err
        }

        if let msg = msg {
            messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: senderIdentity)
        }

        messageProcessorDelegate.incomingMessageFinished(groupAudioMessage, isPendingGroup: false)
    }

    func save(groupCreateMessage amsg: GroupCreateMessage) {
        frameworkInjector.backgroundEntityManager.performBlockAndWait {
            self.frameworkInjector.backgroundGroupManager.createOrUpdateDB(
                groupID: amsg.groupID,
                creator: amsg.groupCreator,
                members: Set<String>(amsg.groupMembers.map { $0 as! String }),
                systemMessageDate: nil
            )
        }
        changedConversationAndGroupEntity(groupID: amsg.groupID, groupCreatorIdentity: amsg.groupCreator)
    }

    func save(groupDeletePhotoMessage amsg: GroupDeletePhotoMessage) -> Promise<Void> {
        frameworkInjector.backgroundGroupManager.deletePhoto(
            groupID: amsg.groupID,
            creator: amsg.groupCreator,
            sentDate: amsg.date,
            send: false
        )
        .then { () -> Promise<Void> in
            self.changedConversationAndGroupEntity(groupID: amsg.groupID, groupCreatorIdentity: amsg.groupCreator)
            return Promise()
        }
    }

    func save(groupLeaveMessage amsg: GroupLeaveMessage) {
        frameworkInjector.backgroundGroupManager.leaveDB(
            groupID: amsg.groupID,
            creator: amsg.groupCreator,
            member: amsg.fromIdentity,
            systemMessageDate: amsg.date
        )
        changedConversationAndGroupEntity(groupID: amsg.groupID, groupCreatorIdentity: amsg.groupCreator)
    }

    func save(groupRenameMessage amsg: GroupRenameMessage) -> Promise<Void> {
        frameworkInjector.backgroundGroupManager.setName(
            groupID: amsg.groupID,
            creator: amsg.groupCreator,
            name: amsg.name,
            systemMessageDate: amsg.date,
            send: false
        )
        .then { () -> Promise<Void> in
            self.changedConversationAndGroupEntity(groupID: amsg.groupID, groupCreatorIdentity: amsg.groupCreator)
            return Promise()
        }
    }

    func save(
        groupFileMessage: GroupFileMessage,
        senderIdentity: String,
        createdAt: UInt64,
        timestamp: Date,
        isOutgoing: Bool,
        timeoutDownloadThumbnail: Int
    ) -> Promise<Void> {
        Promise { seal in
            if !isOutgoing {
                messageProcessorDelegate.incomingMessageStarted(groupFileMessage)
            }

            frameworkInjector.backgroundEntityManager.performBlockAndWait {
                guard let conversation = self.frameworkInjector.backgroundEntityManager.entityFetcher
                    .conversation(for: groupFileMessage) else {
                    seal
                        .reject(
                            MediatorReflectedProcessorError
                                .conversationNotFound(message: groupFileMessage.loggingDescription)
                        )
                    return
                }

                var sender: Contact?
                if !isOutgoing {
                    sender = self.frameworkInjector.backgroundEntityManager.entityFetcher.contact(for: senderIdentity)
                    if sender == nil {
                        seal
                            .reject(
                                MediatorReflectedProcessorError
                                    .contactNotFound(message: groupFileMessage.loggingDescription)
                            )
                        return
                    }
                }

                FileMessageDecoder.decodeGroupMessage(
                    fromBox: groupFileMessage,
                    forConversation: conversation,
                    timeoutDownloadThumbnail: Int32(timeoutDownloadThumbnail),
                    entityManager: self.frameworkInjector.backgroundEntityManager,
                    onCompletion: { msg in
                        self.frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
                            msg?.id = groupFileMessage.messageID
                            msg?.sender = sender

                            msg?.date = timestamp
                            msg?.isOwn = NSNumber(booleanLiteral: isOutgoing)

                            // Origin of blob for reflected file message is always local
                            (msg as? FileMessageEntity)?.origin = NSNumber(booleanLiteral: true)

                            conversation.lastMessage = msg
                            conversation.lastUpdate = Date.now
                        }

                        if !isOutgoing {
                            if let msg = msg {
                                self.messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: senderIdentity)
                            }

                            self.messageProcessorDelegate.incomingMessageFinished(
                                groupFileMessage,
                                isPendingGroup: false
                            )
                        }

                        seal.fulfill_()
                    }
                ) { error in
                    seal.reject(
                        MediatorReflectedProcessorError.messageNotProcessed(
                            message: "Could not process group file message: \(error?.localizedDescription ?? "")"
                        )
                    )
                }
            }
        }
    }

    func save(
        imageMessage: AbstractMessage,
        senderIdentity: String,
        createdAt: UInt64,
        timestamp: Date,
        maxBytesToDecrypt: Int
    ) throws -> Promise<Void> {
        assert(imageMessage is BoxImageMessage || imageMessage is GroupImageMessage)

        guard !(imageMessage is BoxImageMessage && imageMessage is GroupImageMessage) else {
            throw MediatorReflectedProcessorError
                .messageNotProcessed(message: "Wrong message type, nust be BoxImageMessage or GroupImageMessage")
        }

        return Promise { seal in
            messageProcessorDelegate.incomingMessageStarted(imageMessage)

            // Create image message in DB and download and decrypt blob
            frameworkInjector.backgroundEntityManager.performBlockAndWait {
                var msg: ImageMessageEntity!
                var senderPublicKey: Data?

                // Check is message already created
                self.frameworkInjector.backgroundEntityManager.entityFetcher.message(with: imageMessage.messageID)
                if msg == nil {
                    var conversation: Conversation!
                    if imageMessage is BoxImageMessage {
                        conversation = self.frameworkInjector.backgroundEntityManager.conversation(
                            for: senderIdentity,
                            createIfNotExisting: true
                        )
                    }
                    else if let imageMessage = imageMessage as? GroupVideoMessage {
                        conversation = self.frameworkInjector.backgroundEntityManager.entityFetcher
                            .conversation(for: imageMessage)
                    }
                    guard conversation != nil else {
                        seal
                            .reject(
                                MediatorReflectedProcessorError
                                    .conversationNotFound(message: imageMessage.loggingDescription)
                            )
                        return
                    }

                    // TOCHECK: Is there always a sender?
                    guard let sender = self.frameworkInjector.backgroundEntityManager.entityFetcher
                        .contact(for: senderIdentity) else {
                        seal
                            .reject(
                                MediatorReflectedProcessorError
                                    .contactNotFound(message: imageMessage.loggingDescription)
                            )
                        return
                    }
                    senderPublicKey = sender.publicKey

                    self.frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
                        if let imageMessage = imageMessage as? BoxImageMessage {
                            msg = self.frameworkInjector.backgroundEntityManager.entityCreator
                                .imageMessageEntity(fromBox: imageMessage)
                        }
                        else if let imageMessage = imageMessage as? GroupImageMessage {
                            msg = self.frameworkInjector.backgroundEntityManager.entityCreator
                                .imageMessageEntity(fromGroupBox: imageMessage)
                            msg?.sender = sender
                        }
                        msg?.conversation = conversation

                        msg?.date = timestamp
                        msg?.isOwn = NSNumber(booleanLiteral: false)

                        conversation.lastMessage = msg
                        conversation.lastUpdate = Date.now
                    }
                }

                if let msg = msg {
                    self.messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: senderIdentity)

                    // An ImageMessage never has a local blob because all note group cabable devices send everything as FileMessage
                    let downloadQueue = DispatchQueue.global(qos: .default)

                    let processor = ImageMessageProcessor(
                        blobDownloader: BlobDownloader(blobURL: BlobURL(
                            serverConnector: ServerConnector.shared(),
                            userSettings: self.frameworkInjector.userSettings,
                            localOrigin: false,
                            queue: DispatchQueue.global(qos: .userInitiated)
                        ), queue: downloadQueue),
                        myIdentityStore: self.frameworkInjector.myIdentityStore,
                        userSettings: self.frameworkInjector.userSettings,
                        entityManager: self.frameworkInjector.backgroundEntityManager
                    )
                    processor.downloadImage(
                        imageMessageID: msg.id,
                        imageBlobID: msg.imageBlobID,
                        imageBlobEncryptionKey: msg.blobGetEncryptionKey(),
                        imageBlobNonce: msg.imageNonce,
                        senderPublicKey: senderPublicKey,
                        maxBytesToDecrypt: maxBytesToDecrypt
                    )
                    .done {
                        self.messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: senderIdentity)
                        seal.fulfill_()
                    }
                    .ensure {
                        self.messageProcessorDelegate.incomingMessageFinished(
                            imageMessage,
                            isPendingGroup: false
                        )
                    }
                    .catch { error in
                        seal.reject(error)
                    }
                }
                else {
                    seal
                        .reject(
                            MediatorReflectedProcessorError
                                .messageNotProcessed(message: "Could not create image message.")
                        )
                }
            }
        }
    }

    func save(
        groupLocationMessage: GroupLocationMessage,
        senderIdentity: String,
        createdAt: UInt64,
        timestamp: Date,
        isOutgoing: Bool
    ) throws {
        if !isOutgoing {
            messageProcessorDelegate.incomingMessageStarted(groupLocationMessage)
        }

        var msg: LocationMessage?
        var err: Error?
        frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
            guard let conversation = self.frameworkInjector.backgroundEntityManager.entityFetcher
                .conversation(for: groupLocationMessage) else {
                err = MediatorReflectedProcessorError
                    .conversationNotFound(message: groupLocationMessage.loggingDescription)
                return
            }

            var sender: Contact?
            if !isOutgoing {
                sender = self.frameworkInjector.backgroundEntityManager.entityFetcher.contact(for: senderIdentity)
                if sender == nil {
                    err = MediatorReflectedProcessorError
                        .contactNotFound(message: groupLocationMessage.loggingDescription)
                    return
                }
            }

            msg = self.frameworkInjector.backgroundEntityManager.entityCreator
                .locationMessage(fromGroupBox: groupLocationMessage)
            msg?.conversation = conversation
            msg?.sender = sender

            msg?.date = timestamp
            msg?.isOwn = NSNumber(booleanLiteral: isOutgoing)

            conversation.lastMessage = msg
            conversation.lastUpdate = Date.now
        }
        if let err = err {
            throw err
        }

        // Caution this is async
        setPoiAddress(message: msg)
            .done {
                if !isOutgoing {
                    if let msg = msg {
                        self.messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: senderIdentity)
                    }

                    self.messageProcessorDelegate.incomingMessageFinished(groupLocationMessage, isPendingGroup: false)
                }
            }
            .catch { error in
                DDLogError(String(format: "Set POI address failed %@", error.localizedDescription))
            }
    }

    func save(
        groupBallotCreateMessage: GroupBallotCreateMessage,
        senderIdentity: String,
        createdAt: UInt64,
        timestamp: Date,
        isOutgoing: Bool
    ) throws {
        if !isOutgoing {
            messageProcessorDelegate.incomingMessageStarted(groupBallotCreateMessage)
        }

        var msg: BallotMessage?
        var err: Error?
        frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
            guard let conversation = self.frameworkInjector.backgroundEntityManager.entityFetcher
                .conversation(for: groupBallotCreateMessage) else {
                err = MediatorReflectedProcessorError
                    .conversationNotFound(message: groupBallotCreateMessage.loggingDescription)
                return
            }

            var sender: Contact?
            if !isOutgoing {
                sender = self.frameworkInjector.backgroundEntityManager.entityFetcher.contact(for: senderIdentity)
                if sender == nil {
                    err = MediatorReflectedProcessorError
                        .contactNotFound(message: groupBallotCreateMessage.loggingDescription)
                    return
                }
            }

            let decoder = BallotMessageDecoder(self.frameworkInjector.backgroundEntityManager)
            msg = decoder?.decodeCreateBallot(fromGroupBox: groupBallotCreateMessage, for: conversation)
            msg?.conversation = conversation
            msg?.sender = sender

            msg?.date = timestamp
            msg?.isOwn = NSNumber(booleanLiteral: isOutgoing)

            conversation.lastMessage = msg
            conversation.lastUpdate = Date.now
        }
        if let err = err {
            throw err
        }

        if !isOutgoing {
            if let msg = msg {
                messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: senderIdentity)
            }

            messageProcessorDelegate.incomingMessageFinished(groupBallotCreateMessage, isPendingGroup: false)
        }
    }

    func save(groupBallotVoteMessage: GroupBallotVoteMessage) throws {
        var err: Error?
        frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
            if let decoder = BallotMessageDecoder(self.frameworkInjector.backgroundEntityManager),
               !decoder.decodeVote(fromGroupBox: groupBallotVoteMessage) {
                err = MediatorReflectedProcessorError
                    .messageDecodeFailed(message: groupBallotVoteMessage.loggingDescription)
            }
        }
        if let err = err {
            throw err
        }

        changedBallot(with: groupBallotVoteMessage.ballotID)
    }

    func save(groupSetPhotoMessage amsg: GroupSetPhotoMessage) -> Promise<Void> {
        syncLoadBlob(blobID: amsg.blobID, encryptionKey: amsg.encryptionKey)
            .then { (data: Data?) -> Promise<Void> in
                guard let data = data else {
                    throw MediatorReflectedProcessorError.downloadFailed(message: "Blob download failed, no data.")
                }

                return Promise { seal in
                    self.frameworkInjector.backgroundEntityManager.performBlockAndWait {
                        self.frameworkInjector.backgroundGroupManager.setPhoto(
                            groupID: amsg.groupID,
                            creator: amsg.groupCreator,
                            imageData: data,
                            sentDate: amsg.date,
                            send: false
                        )
                        .done {
                            seal.fulfill_()
                        }
                        .catch { error in
                            seal.reject(error)
                        }
                    }
                }
            }
    }
    
    func save(
        groupDeliveryReceiptMessage: GroupDeliveryReceiptMessage,
        createdAt: UInt64,
        isOutgoing: Bool
    ) throws {
        for id in groupDeliveryReceiptMessage.receiptMessageIDs {
            if let messageID = id as? Data {
                if let msg = frameworkInjector.backgroundEntityManager.entityFetcher.message(with: messageID),
                   msg.conversation.groupID == groupDeliveryReceiptMessage.groupID {
                    if groupDeliveryReceiptMessage.receiptType == GroupDeliveryReceipt.DeliveryReceiptType
                        .userAcknowledgment.rawValue {
                        if isOutgoing {
                            messageProcessorDelegate.outgoingMessageFinished(groupDeliveryReceiptMessage)
                        }
                        else {
                            frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
                                let receipt = GroupDeliveryReceipt(
                                    identity: groupDeliveryReceiptMessage.fromIdentity,
                                    deliveryReceiptType: .userAcknowledgment,
                                    date: groupDeliveryReceiptMessage.date
                                )
                                msg.add(groupDeliveryReceipt: receipt)
                            }
                        }
                    }
                    
                    if groupDeliveryReceiptMessage.receiptType == GroupDeliveryReceipt.DeliveryReceiptType.userDeclined
                        .rawValue {
                        if isOutgoing {
                            messageProcessorDelegate.outgoingMessageFinished(groupDeliveryReceiptMessage)
                        }
                        else {
                            frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
                                let receipt = GroupDeliveryReceipt(
                                    identity: groupDeliveryReceiptMessage.fromIdentity,
                                    deliveryReceiptType: .userDeclined,
                                    date: groupDeliveryReceiptMessage.date
                                )
                                msg.add(groupDeliveryReceipt: receipt)
                            }
                        }
                    }

                    messageProcessorDelegate.changedManagedObjectID(msg.objectID)
                }
                else {
                    throw MediatorReflectedProcessorError
                        .messageNotProcessed(message: groupDeliveryReceiptMessage.loggingDescription)
                }
            }
        }
    }

    func save(
        groupTextMessage: GroupTextMessage,
        senderIdentity: String,
        messageID: Data,
        createdAt: UInt64,
        timestamp: Date,
        isOutgoing: Bool
    ) throws {
        if !isOutgoing {
            messageProcessorDelegate.incomingMessageStarted(groupTextMessage)
        }

        var msg: TextMessage?
        var err: Error?
        frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
            guard let conversation = self.frameworkInjector.backgroundEntityManager.entityFetcher
                .conversation(for: groupTextMessage) else {
                err = MediatorReflectedProcessorError.conversationNotFound(message: groupTextMessage.loggingDescription)
                return
            }
            var sender: Contact?
            if !isOutgoing {
                sender = self.frameworkInjector.backgroundEntityManager.entityFetcher.contact(for: senderIdentity)
                if sender == nil {
                    err = MediatorReflectedProcessorError.contactNotFound(message: groupTextMessage.loggingDescription)
                    return
                }
            }

            msg = self.frameworkInjector.backgroundEntityManager.entityCreator
                .textMessage(fromGroupBox: groupTextMessage)
            msg?.conversation = conversation
            msg?.sender = sender

            msg?.date = timestamp
            msg?.isOwn = NSNumber(booleanLiteral: isOutgoing)

            conversation.lastMessage = msg
            conversation.lastUpdate = Date.now
        }
        if let err = err {
            throw err
        }

        if !isOutgoing {
            if let msg = msg {
                messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: senderIdentity)
            }

            messageProcessorDelegate.incomingMessageFinished(groupTextMessage, isPendingGroup: false)
        }
    }

    func save(
        videoMessage: AbstractMessage,
        senderIdentity: String,
        createdAt: UInt64,
        timestamp: Date,
        maxBytesToDecrypt: Int
    ) throws -> Promise<Void> {
        assert(videoMessage is BoxVideoMessage || videoMessage is GroupVideoMessage)

        guard !(videoMessage is BoxVideoMessage && videoMessage is GroupVideoMessage) else {
            throw MediatorReflectedProcessorError
                .messageNotProcessed(message: "Wrong message type, nust be BoxVideoMessage or GroupVideoMessage")
        }

        return Promise { seal in
            messageProcessorDelegate.incomingMessageStarted(videoMessage)

            frameworkInjector.backgroundEntityManager.performBlockAndWait {
                // Save message first and after try download thumbnail
                var thumbnailBlobID: Data!
                var msg: VideoMessageEntity!

                // Check is message already created
                msg = self.frameworkInjector.backgroundEntityManager.entityFetcher
                    .message(with: videoMessage.messageID) as? VideoMessageEntity
                if msg == nil {
                    var conversation: Conversation!
                    if videoMessage is BoxVideoMessage {
                        conversation = self.frameworkInjector.backgroundEntityManager.conversation(
                            for: senderIdentity,
                            createIfNotExisting: true
                        )
                    }
                    else if let videoMessage = videoMessage as? GroupVideoMessage {
                        conversation = self.frameworkInjector.backgroundEntityManager.entityFetcher
                            .conversation(for: videoMessage)
                    }
                    guard conversation != nil else {
                        seal
                            .reject(
                                MediatorReflectedProcessorError
                                    .conversationNotFound(message: videoMessage.loggingDescription)
                            )
                        return
                    }
                    guard let sender = self.frameworkInjector.backgroundEntityManager.entityFetcher
                        .contact(for: senderIdentity) else {
                        seal
                            .reject(
                                MediatorReflectedProcessorError
                                    .contactNotFound(message: videoMessage.loggingDescription)
                            )
                        return
                    }

                    // Create video message in DB
                    self.frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
                        if let videoMessage = videoMessage as? BoxVideoMessage {
                            thumbnailBlobID = videoMessage.thumbnailBlobID
                            msg = self.frameworkInjector.backgroundEntityManager.entityCreator
                                .videoMessageEntity(fromBox: videoMessage)
                        }
                        else if let videoMessage = videoMessage as? GroupVideoMessage {
                            thumbnailBlobID = videoMessage.thumbnailBlobID
                            msg = self.frameworkInjector.backgroundEntityManager.entityCreator
                                .videoMessageEntity(fromGroupBox: videoMessage)
                            msg?.sender = sender
                        }
                        msg?.conversation = conversation

                        let thumbnailImage = UIImage(imageLiteralResourceName: "Video")
                        let thumbnail: ImageData = self.frameworkInjector.backgroundEntityManager.entityCreator
                            .imageData()
                        thumbnail.data = thumbnailImage.jpegData(compressionQuality: 1.0)
                        thumbnail.width = NSNumber(value: Float(thumbnailImage.size.width))
                        thumbnail.height = NSNumber(value: Float(thumbnailImage.size.height))
                        msg?.thumbnail = thumbnail

                        msg?.date = timestamp
                        msg?.isOwn = NSNumber(booleanLiteral: false)

                        conversation.lastMessage = msg
                        conversation.lastUpdate = Date.now
                    }
                }
                else {
                    thumbnailBlobID = videoMessage is BoxVideoMessage ? (videoMessage as! BoxVideoMessage)
                        .thumbnailBlobID
                        : (videoMessage as! GroupVideoMessage).thumbnailBlobID
                }

                if msg != nil {
                    self.messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: senderIdentity)

                    // A VideoMessage never has a local blob because all note group cabable devices send everything as FileMessage (-> localOrigin: false)
                    // Download, decrypt and save blob of thumbnail
                    let downloadQueue = DispatchQueue.global(qos: .default)
                    let videoProcessor = VideoMessageProcessor(
                        blobDownloader: BlobDownloader(blobURL: BlobURL(
                            serverConnector: ServerConnector.shared(),
                            userSettings: self.frameworkInjector.userSettings,
                            localOrigin: false,
                            queue: DispatchQueue.global(qos: .userInitiated)
                        ), queue: downloadQueue), entityManager: self.frameworkInjector.backgroundEntityManager
                    )
                    videoProcessor.downloadVideoThumbnail(
                        videoMessageID: msg.id,
                        thumbnailBlobID: thumbnailBlobID,
                        maxBytesToDecrypt: maxBytesToDecrypt
                    )
                    .done {
                        self.messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: senderIdentity)
                        seal.fulfill_()
                    }
                    .ensure {
                        self.messageProcessorDelegate.incomingMessageFinished(
                            videoMessage,
                            isPendingGroup: false
                        )
                    }
                    .catch { error in
                        seal.reject(error)
                    }
                }
                else {
                    seal
                        .reject(
                            MediatorReflectedProcessorError
                                .messageNotProcessed(message: "Could not create video message")
                        )
                }
            }
        }
    }

    func save(
        locationMessage: BoxLocationMessage,
        conversationIdentity: String,
        createdAt: UInt64,
        timestamp: Date,
        isOutgoing: Bool
    ) throws {
        if !isOutgoing {
            messageProcessorDelegate.incomingMessageStarted(locationMessage)
        }

        var msg: LocationMessage?
        var err: Error?
        frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
            guard let conversation = self.frameworkInjector.backgroundEntityManager.conversation(
                for: conversationIdentity,
                createIfNotExisting: true
            ) else {
                err = MediatorReflectedProcessorError.conversationNotFound(message: locationMessage.loggingDescription)
                return
            }

            msg = self.frameworkInjector.backgroundEntityManager.entityCreator.locationMessage(fromBox: locationMessage)
            msg?.conversation = conversation

            msg?.date = timestamp
            msg?.isOwn = NSNumber(booleanLiteral: isOutgoing)

            conversation.lastMessage = msg
            conversation.lastUpdate = Date.now
        }
        if let err = err {
            throw err
        }

        // Caution this is async
        setPoiAddress(message: msg)
            .done {
                if !isOutgoing {
                    if let msg = msg {
                        self.messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: conversationIdentity)
                    }

                    self.messageProcessorDelegate.incomingMessageFinished(locationMessage, isPendingGroup: false)
                }
            }
            .catch { error in
                DDLogError(String(format: "Set POI address failed %@", error.localizedDescription))
            }
    }

    func save(
        ballotCreateMessage: BoxBallotCreateMessage,
        conversationIdentity: String,
        createdAt: UInt64,
        timestamp: Date,
        isOutgoing: Bool
    ) throws {
        if !isOutgoing {
            messageProcessorDelegate.incomingMessageStarted(ballotCreateMessage)
        }

        var msg: BallotMessage?
        var err: Error?
        frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
            guard let conversation = self.frameworkInjector.backgroundEntityManager.conversation(
                for: conversationIdentity,
                createIfNotExisting: true
            ) else {
                err = MediatorReflectedProcessorError
                    .conversationNotFound(message: ballotCreateMessage.loggingDescription)
                return
            }

            let decoder = BallotMessageDecoder(self.frameworkInjector.backgroundEntityManager)
            msg = decoder?.decodeCreateBallot(fromBox: ballotCreateMessage, for: conversation)
            msg?.conversation = conversation

            msg?.date = timestamp
            msg?.isOwn = NSNumber(booleanLiteral: isOutgoing)

            conversation.lastMessage = msg
            conversation.lastUpdate = Date.now
        }
        if let err = err {
            throw err
        }

        if !isOutgoing {
            if let msg = msg {
                messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: conversationIdentity)
            }

            messageProcessorDelegate.incomingMessageFinished(ballotCreateMessage, isPendingGroup: false)
        }
    }

    func save(ballotVoteMessage: BoxBallotVoteMessage) throws {
        var err: Error?
        frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
            if let decoder = BallotMessageDecoder(self.frameworkInjector.backgroundEntityManager),
               !decoder.decodeVote(fromBox: ballotVoteMessage) {
                err = MediatorReflectedProcessorError
                    .messageDecodeFailed(message: ballotVoteMessage.loggingDescription)
            }
        }
        if let err = err {
            throw err
        }

        changedBallot(with: ballotVoteMessage.ballotID)
    }

    // MARK: Misc

    /// Get poi-address, if is necessary.
    /// - Parameter message:: Location message to save address
    private func setPoiAddress(message: LocationMessage?) -> Promise<Void> {
        Promise { seal in
            self.frameworkInjector.backgroundEntityManager.performBlockAndWait {
                if let message = message,
                   let msg = self.frameworkInjector.backgroundEntityManager.entityFetcher
                   .getManagedObject(by: message.objectID) as? LocationMessage,
                   msg.poiAddress == nil,
                   let latitude = Double(exactly: msg.latitude),
                   let longitude = Double(exactly: msg.longitude),
                   let accuracy = Double(exactly: msg.accuracy) {
                    ThreemaUtilityObjC.reverseGeocodeNearLatitude(
                        latitude,
                        longitude: longitude,
                        accuracy: accuracy,
                        completion: { geoLabel in
                            self.frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
                                message.poiAddress = geoLabel
                            }
                            seal.fulfill_()
                        }
                    ) { error in
                        DDLogWarn(String(format: "Reverse geocoding failed: %@", error?.localizedDescription ?? ""))

                        self.frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
                            message.poiAddress = String(format: "%.5f°, %.5f°", latitude, longitude)
                        }
                        seal.fulfill_()
                    }
                }
                else {
                    seal.fulfill_()
                }
            }
        }
    }

    func syncLoadBlob(blobID: Data, encryptionKey: Data) -> Promise<Data?> {
        Promise { seal in
            let profilePictureLoader = ContactGroupPhotoLoader()
            profilePictureLoader.start(with: blobID, encryptionKey: encryptionKey) { data in
                seal.fulfill(data)
            } error: { error in
                seal.reject(MediatorReflectedProcessorError.downloadFailed(message: error?.localizedDescription ?? ""))
            }
        }
    }

    private func changedBallot(with ballotID: Data) {
        frameworkInjector.entityManager.performBlockAndWait {
            if let ballot = self.frameworkInjector.entityManager.entityFetcher.ballot(for: ballotID) {
                self.messageProcessorDelegate.changedManagedObjectID(ballot.objectID)
            }
        }
    }

    private func changedContact(with identity: String) {
        frameworkInjector.entityManager.performBlockAndWait {
            if let contact = self.frameworkInjector.entityManager.entityFetcher.contact(for: identity) {
                self.messageProcessorDelegate.changedManagedObjectID(contact.objectID)
            }
        }
    }

    private func changedConversationAndGroupEntity(groupID: Data, groupCreatorIdentity: String) {
        frameworkInjector.entityManager.performBlockAndWait {
            if let conversation = self.frameworkInjector.entityManager.entityFetcher.conversation(
                for: groupID,
                creator: groupCreatorIdentity
            ) {
                self.messageProcessorDelegate.changedManagedObjectID(conversation.objectID)

                if let groupEntity = self.frameworkInjector.entityManager.entityFetcher.groupEntity(for: conversation) {
                    self.messageProcessorDelegate.changedManagedObjectID(groupEntity.objectID)
                }
            }
        }
    }
}
