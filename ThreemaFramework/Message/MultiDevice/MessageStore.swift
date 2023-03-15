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
    
    @available(*, deprecated, message: "Just for incoming (deprecated) audio message, blob origin is always public!")
    func save(
        audioMessage: BoxAudioMessage,
        conversationIdentity: String,
        createdAt: UInt64,
        timestamp: Date
    ) throws {
        messageProcessorDelegate.incomingMessageStarted(audioMessage)

        let (conversation, _) = try conversationSender(forMessage: audioMessage, isOutgoing: false)

        guard let msg = frameworkInjector.backgroundEntityManager.getOrCreateMessage(
            for: audioMessage,
            sender: nil,
            conversation: conversation,
            thumbnail: nil
        ) as? AudioMessageEntity else {
            throw MediatorReflectedProcessorError
                .messageNotProcessed(message: "Could not find/create audio message in DB")
        }
        
        frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
            msg.date = timestamp
            msg.isOwn = NSNumber(booleanLiteral: false)
        }

        messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: conversationIdentity)
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

            let (conversation, _) = try conversationSender(forMessage: fileMessage, isOutgoing: isOutgoing)

            FileMessageDecoder.decodeMessage(
                fromBox: fileMessage,
                sender: nil,
                conversation: conversation,
                isReflectedMessage: true,
                timeoutDownloadThumbnail: Int32(timeoutDownloadThumbnail),
                entityManager: self.frameworkInjector.backgroundEntityManager,
                onCompletion: { msg in
                    self.frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
                        msg?.id = fileMessage.messageID
                        msg?.date = timestamp
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

        let (conversation, _) = try conversationSender(forMessage: textMessage, isOutgoing: isOutgoing)

        guard let msg = frameworkInjector.backgroundEntityManager.getOrCreateMessage(
            for: textMessage,
            sender: nil,
            conversation: conversation,
            thumbnail: nil
        ) as? TextMessage else {
            throw MediatorReflectedProcessorError.messageNotProcessed(message: "Could not find/create text message")
        }

        frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
            msg.date = timestamp
            msg.isOwn = NSNumber(booleanLiteral: isOutgoing)
        }

        if !isOutgoing {
            messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: conversationIdentity)
            messageProcessorDelegate.incomingMessageFinished(textMessage, isPendingGroup: false)
        }
    }

    func save(contactDeletePhotoMessage amsg: ContactDeletePhotoMessage) {
        frameworkInjector.contactStore.deleteProfilePicture(amsg.fromIdentity, shouldReflect: false)
        frameworkInjector.contactStore.removeProfilePictureRequest(amsg.fromIdentity)
        changedContact(with: amsg.fromIdentity)
    }

    func save(contactSetPhotoMessage: ContactSetPhotoMessage) -> Promise<Void> {
        syncLoadBlob(
            blobID: contactSetPhotoMessage.blobID,
            encryptionKey: contactSetPhotoMessage.encryptionKey,
            origin: .local
        )
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
        var messageReadConversations = Set<Conversation>()

        for id in deliveryReceiptMessage.receiptMessageIDs {
            if let messageID = id as? Data {
                var error: Error?
                frameworkInjector.backgroundEntityManager.performBlock {
                    if let conversation = self.frameworkInjector.backgroundEntityManager.conversation(
                        forMessage: deliveryReceiptMessage
                    ),
                        let msg = self.frameworkInjector.backgroundEntityManager.entityFetcher.message(
                            with: messageID,
                            conversation: conversation
                        ) {
                        if deliveryReceiptMessage.receiptType == DELIVERYRECEIPT_MSGRECEIVED {
                            self.frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
                                msg.delivered = true
                                msg.deliveryDate = deliveryReceiptMessage.date
                            }
                        }
                        else if deliveryReceiptMessage.receiptType == DELIVERYRECEIPT_MSGREAD {
                            self.frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
                                msg.read = true
                                msg.readDate = deliveryReceiptMessage.date

                                messageReadConversations.insert(msg.conversation)
                            }
                        }
                        else if deliveryReceiptMessage.receiptType == DELIVERYRECEIPT_MSGUSERACK {
                            self.frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
                                msg.userack = true
                                msg.userackDate = deliveryReceiptMessage.date
                            }
                        }
                        else if deliveryReceiptMessage.receiptType == DELIVERYRECEIPT_MSGUSERDECLINE {
                            self.frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
                                msg.userack = false
                                msg.userackDate = deliveryReceiptMessage.date
                            }
                        }
                        else {
                            DDLogWarn(
                                "Unknown delivery receipt type \(deliveryReceiptMessage.receiptType) with message ID \(messageID.hexString)"
                            )
                        }
                        self.messageProcessorDelegate.changedManagedObjectID(msg.objectID)
                    }
                    else {
                        error = MediatorReflectedProcessorError
                            .messageNotProcessed(message: deliveryReceiptMessage.loggingDescription)
                    }
                }
                if let error {
                    throw error
                }
            }
        }

        if !messageReadConversations.isEmpty {
            messageProcessorDelegate.readMessage(inConversations: messageReadConversations)
        }
    }
    
    @available(
        *,
        deprecated,
        message: "Just for incoming (deprecated) audio group message, blob origin is always public!"
    )
    func save(
        groupAudioMessage: GroupAudioMessage,
        senderIdentity: String,
        createdAt: UInt64,
        timestamp: Date
    ) throws {
        messageProcessorDelegate.incomingMessageStarted(groupAudioMessage)

        let (conversation, sender) = try conversationSender(forMessage: groupAudioMessage, isOutgoing: false)

        guard let sender else {
            throw MediatorReflectedProcessorError.senderNotFound(identity: senderIdentity)
        }

        guard let msg = frameworkInjector.backgroundEntityManager.getOrCreateMessage(
            for: groupAudioMessage,
            sender: sender,
            conversation: conversation,
            thumbnail: nil
        ) as? AudioMessageEntity else {
            throw MediatorReflectedProcessorError
                .messageNotProcessed(message: "Could not find/create group audio message in DB")
        }

        frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
            msg.date = timestamp
            msg.isOwn = NSNumber(booleanLiteral: false)
        }

        messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: senderIdentity)
        messageProcessorDelegate.incomingMessageFinished(groupAudioMessage, isPendingGroup: false)
    }

    func save(groupCreateMessage amsg: GroupCreateMessage) -> Promise<Void> {
        // Validate members, all members must be known contacts, otherwise device is not in sync
        var internalError: Error?
        frameworkInjector.entityManager.performBlockAndWait {
            for identity in (amsg.groupMembers as! [String])
                .filter({ $0 != self.frameworkInjector.myIdentityStore.identity }) {
                guard self.frameworkInjector.entityManager.entityFetcher.contact(for: identity) != nil else {
                    DDLogWarn("Unknown group member, device not in sync anymore")
                    internalError = MediatorReflectedProcessorError.contactNotFound(identity: identity)
                    return
                }
            }
        }
        if let internalError = internalError {
            return Promise(error: internalError)
        }

        return frameworkInjector.backgroundGroupManager.createOrUpdateDB(
            groupID: amsg.groupID,
            creator: amsg.groupCreator,
            members: Set<String>(amsg.groupMembers.map { $0 as! String }),
            systemMessageDate: amsg.date,
            sourceCaller: .sync
        )
        .then { group -> Promise<Void> in
            guard group != nil else {
                throw MediatorReflectedProcessorError.groupCreateFailed(
                    groupID: "\(amsg.groupID?.hexString ?? "-")",
                    groupCreatorIdentity: "\(amsg.groupCreator ?? "-")"
                )
            }
            self.changedConversationAndGroupEntity(groupID: amsg.groupID, groupCreatorIdentity: amsg.groupCreator)
            return Promise()
        }
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

            let (conversation, sender) = try conversationSender(forMessage: groupFileMessage, isOutgoing: isOutgoing)

            guard isOutgoing || (!isOutgoing && sender != nil) else {
                throw MediatorReflectedProcessorError.senderNotFound(identity: senderIdentity)
            }

            FileMessageDecoder.decodeGroupMessage(
                fromBox: groupFileMessage,
                sender: sender,
                conversation: conversation,
                isReflectedMessage: true,
                timeoutDownloadThumbnail: Int32(timeoutDownloadThumbnail),
                entityManager: self.frameworkInjector.backgroundEntityManager,
                onCompletion: { msg in
                    self.frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
                        msg?.id = groupFileMessage.messageID
                        msg?.date = timestamp
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

    @available(
        *,
        deprecated,
        message: "Just for incoming (deprecated) image (group) message, blob origin is always public!"
    )
    func save(
        imageMessage: AbstractMessage,
        senderIdentity: String,
        createdAt: UInt64,
        timestamp: Date,
        maxBytesToDecrypt: Int
    ) throws -> Promise<Void> {
        assert(imageMessage is BoxImageMessage || imageMessage is GroupImageMessage)
        assert(senderIdentity == imageMessage.fromIdentity)

        guard !(imageMessage is BoxImageMessage && imageMessage is GroupImageMessage) else {
            throw MediatorReflectedProcessorError
                .messageNotProcessed(message: "Wrong message type, must be BoxImageMessage or GroupImageMessage")
        }

        let (conversation, sender) = try conversationSender(forMessage: imageMessage, isOutgoing: false)

        guard let sender else {
            throw MediatorReflectedProcessorError.contactNotFound(identity: senderIdentity)
        }

        return Promise { seal in
            messageProcessorDelegate.incomingMessageStarted(imageMessage)

            guard let msg = frameworkInjector.backgroundEntityManager.getOrCreateMessage(
                for: imageMessage,
                sender: nil,
                conversation: conversation,
                thumbnail: nil
            ) as? ImageMessageEntity else {
                seal
                    .reject(
                        MediatorReflectedProcessorError
                            .messageNotProcessed(message: "Could not find/create (group) image message in DB")
                    )
                return
            }

            var senderPublicKey: Data!
            var messageID: Data!
            var conversationObjectID: NSManagedObjectID!
            var blobID: Data!
            var blobOrigin: BlobOrigin!
            var encryptionKey: Data!
            var nonce: Data!

            frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
                msg.date = timestamp
                msg.isOwn = NSNumber(booleanLiteral: false)

                senderPublicKey = sender.publicKey
                messageID = msg.id
                conversationObjectID = conversation.objectID
                blobID = msg.blobGetID()
                blobOrigin = msg.blobGetOrigin()
                encryptionKey = msg.encryptionKey
                nonce = msg.imageNonce
            }

            // Create image message in DB and download and decrypt blob
            self.messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: senderIdentity)

            let downloadQueue = DispatchQueue.global(qos: .default)

            let processor = ImageMessageProcessor(
                blobDownloader: BlobDownloader(blobURL: BlobURL(
                    serverConnector: self.frameworkInjector.serverConnector,
                    userSettings: self.frameworkInjector.userSettings,
                    queue: DispatchQueue.global(qos: .userInitiated)
                ), queue: downloadQueue),
                serverConnector: self.frameworkInjector.serverConnector,
                myIdentityStore: self.frameworkInjector.myIdentityStore,
                userSettings: self.frameworkInjector.userSettings,
                entityManager: self.frameworkInjector.backgroundEntityManager
            )
            processor.downloadImage(
                imageMessageID: messageID,
                in: conversationObjectID,
                imageBlobID: blobID,
                origin: blobOrigin,
                imageBlobEncryptionKey: encryptionKey,
                imageBlobNonce: nonce,
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

        let (conversation, sender) = try conversationSender(forMessage: groupLocationMessage, isOutgoing: isOutgoing)

        guard isOutgoing || (!isOutgoing && sender != nil) else {
            throw MediatorReflectedProcessorError.contactNotFound(identity: senderIdentity)
        }

        guard let msg = frameworkInjector.backgroundEntityManager.getOrCreateMessage(
            for: groupLocationMessage,
            sender: sender,
            conversation: conversation,
            thumbnail: nil
        ) as? LocationMessage else {
            throw MediatorReflectedProcessorError
                .messageNotProcessed(message: "Could not find/create group location message in DB")
        }

        frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
            msg.date = timestamp
            msg.isOwn = NSNumber(booleanLiteral: false)
        }

        // Caution this is async
        setPoiAddress(message: msg)
            .done {
                if !isOutgoing {
                    self.messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: senderIdentity)
                    self.messageProcessorDelegate.incomingMessageFinished(groupLocationMessage, isPendingGroup: false)
                }
            }
            .catch { error in
                DDLogError("Set POI address failed \(error.localizedDescription)")
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

        let (conversation, sender) = try conversationSender(
            forMessage: groupBallotCreateMessage,
            isOutgoing: isOutgoing
        )

        guard isOutgoing || (!isOutgoing && sender != nil) else {
            throw MediatorReflectedProcessorError.senderNotFound(identity: groupBallotCreateMessage.fromIdentity)
        }

        var msg: BallotMessage?
        var err: Error?
        frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
            let decoder = BallotMessageDecoder(self.frameworkInjector.backgroundEntityManager)
            msg = decoder?.decodeCreateBallot(
                fromGroupBox: groupBallotCreateMessage,
                sender: sender,
                conversation: conversation
            )

            guard let msg else {
                err = MediatorReflectedProcessorError
                    .messageNotProcessed(message: "Could not find/create ballot message in DB")
                return
            }

            msg.date = timestamp
            msg.isOwn = NSNumber(booleanLiteral: isOutgoing)
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
        syncLoadBlob(blobID: amsg.blobID, encryptionKey: amsg.encryptionKey, origin: .public)
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

        guard groupDeliveryReceiptMessage.receiptType == GROUPDELIVERYRECEIPT_MSGUSERACK ||
            groupDeliveryReceiptMessage.receiptType == GROUPDELIVERYRECEIPT_MSGUSERDECLINE else {
            DDLogWarn("Unknown group delivery receipt type \(groupDeliveryReceiptMessage.receiptType)")
            return
        }

        let receiptType: GroupDeliveryReceipt.DeliveryReceiptType =
            groupDeliveryReceiptMessage.receiptType == GROUPDELIVERYRECEIPT_MSGUSERACK ? .acknowledged : .declined

        for id in groupDeliveryReceiptMessage.receiptMessageIDs {
            if let messageID = id as? Data {
                var err: Error?

                frameworkInjector.backgroundEntityManager.performBlockAndWait {
                    guard let conversation = self.frameworkInjector.backgroundEntityManager.conversation(
                        forMessage: groupDeliveryReceiptMessage
                    ) else {
                        err = MediatorReflectedProcessorError
                            .conversationNotFound(message: groupDeliveryReceiptMessage.loggingDescription)
                        return
                    }
                    
                    if let msg = self.frameworkInjector.backgroundEntityManager.entityFetcher.message(
                        with: messageID,
                        conversation: conversation
                    ),
                        msg.conversation.groupID == groupDeliveryReceiptMessage.groupID {
                        self.frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
                            let receipt = GroupDeliveryReceipt(
                                identity: groupDeliveryReceiptMessage.fromIdentity,
                                deliveryReceiptType: receiptType,
                                date: groupDeliveryReceiptMessage.date
                            )
                            msg.add(groupDeliveryReceipt: receipt)
                        }
                        self.messageProcessorDelegate.changedManagedObjectID(msg.objectID)
                    }
                    else {
                        err = MediatorReflectedProcessorError
                            .messageNotProcessed(message: groupDeliveryReceiptMessage.loggingDescription)
                    }
                }

                if let err = err {
                    throw err
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

        let (conversation, sender) = try conversationSender(forMessage: groupTextMessage, isOutgoing: isOutgoing)
        frameworkInjector.backgroundEntityManager.performBlockAndWait {
            print("\(conversation.groupID?.hexString ?? "-")")
        }

        guard isOutgoing || (!isOutgoing && sender != nil) else {
            throw MediatorReflectedProcessorError.senderNotFound(identity: groupTextMessage.fromIdentity)
        }

        guard let msg = frameworkInjector.backgroundEntityManager.getOrCreateMessage(
            for: groupTextMessage,
            sender: sender,
            conversation: conversation,
            thumbnail: nil
        ) as? TextMessage else {
            throw MediatorReflectedProcessorError.messageNotProcessed(message: "Could not find/create text message")
        }

        frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
            msg.date = timestamp
            msg.isOwn = NSNumber(booleanLiteral: isOutgoing)
        }

        if !isOutgoing {
            messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: senderIdentity)
            messageProcessorDelegate.incomingMessageFinished(groupTextMessage, isPendingGroup: false)
        }
    }

    @available(
        *,
        deprecated,
        message: "Just for incoming (deprecated) video (group) message, blob origin is always public!"
    )
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
                .messageNotProcessed(message: "Wrong message type, must be BoxVideoMessage or GroupVideoMessage")
        }

        let (conversation, sender) = try conversationSender(forMessage: videoMessage, isOutgoing: false)

        guard let sender else {
            throw MediatorReflectedProcessorError.contactNotFound(identity: senderIdentity)
        }

        return Promise { seal in
            messageProcessorDelegate.incomingMessageStarted(videoMessage)

            // Save message first and after try download thumbnail
            guard let msg = frameworkInjector.backgroundEntityManager.getOrCreateMessage(
                for: videoMessage,
                sender: sender,
                conversation: conversation,
                thumbnail: UIImage(imageLiteralResourceName: "Video")
            ) as? VideoMessageEntity else {
                throw MediatorReflectedProcessorError
                    .messageNotProcessed(message: "Could not find/create (group) video message")
            }

            var thumbnailBlobID: Data!

            if let videoMessage = videoMessage as? BoxVideoMessage {
                thumbnailBlobID = videoMessage.thumbnailBlobID
            }
            else if let videoMessage = videoMessage as? GroupVideoMessage {
                thumbnailBlobID = videoMessage.thumbnailBlobID
            }

            var conversationObjectID: NSManagedObjectID!
            var messageID: Data!
            var blobOrigin: BlobOrigin!

            frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
                msg.date = timestamp
                msg.isOwn = NSNumber(booleanLiteral: false)

                conversationObjectID = conversation.objectID
                messageID = msg.id
                blobOrigin = msg.blobGetOrigin()
            }

            self.messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: senderIdentity)

            // A VideoMessage never has a local blob because all note group cabable devices send everything as FileMessage (-> localOrigin: false)
            // Download, decrypt and save blob of thumbnail
            let downloadQueue = DispatchQueue.global(qos: .default)
            let videoProcessor = VideoMessageProcessor(
                blobDownloader: BlobDownloader(blobURL: BlobURL(
                    serverConnector: self.frameworkInjector.serverConnector,
                    userSettings: self.frameworkInjector.userSettings,
                    queue: DispatchQueue.global(qos: .userInitiated)
                ), queue: downloadQueue),
                serverConnector: self.frameworkInjector.serverConnector,
                entityManager: self.frameworkInjector.backgroundEntityManager
            )
            videoProcessor.downloadVideoThumbnail(
                videoMessageID: messageID,
                in: conversationObjectID,
                origin: blobOrigin,
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

        let (conversation, _) = try conversationSender(forMessage: locationMessage, isOutgoing: isOutgoing)

        guard let msg = frameworkInjector.backgroundEntityManager.getOrCreateMessage(
            for: locationMessage,
            sender: nil,
            conversation: conversation,
            thumbnail: nil
        ) as? LocationMessage else {
            throw MediatorReflectedProcessorError.messageNotProcessed(message: "Could not find/create location message")
        }

        frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
            msg.date = timestamp
            msg.isOwn = NSNumber(booleanLiteral: isOutgoing)
        }

        // Caution this is async
        setPoiAddress(message: msg)
            .done {
                if !isOutgoing {
                    self.messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: conversationIdentity)
                    self.messageProcessorDelegate.incomingMessageFinished(locationMessage, isPendingGroup: false)
                }
            }
            .catch { error in
                DDLogError("Set POI address failed \(error)")
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

        let (conversation, sender) = try conversationSender(forMessage: ballotCreateMessage, isOutgoing: isOutgoing)

        guard isOutgoing || (!isOutgoing && sender != nil) else {
            throw MediatorReflectedProcessorError.senderNotFound(identity: ballotCreateMessage.fromIdentity)
        }

        var msg: BallotMessage!
        var err: Error?
        frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
            let decoder = BallotMessageDecoder(self.frameworkInjector.backgroundEntityManager)
            msg = decoder?.decodeCreateBallot(fromBox: ballotCreateMessage, sender: sender, conversation: conversation)

            guard let msg else {
                err = MediatorReflectedProcessorError
                    .messageNotProcessed(message: "Could not find/create ballot message")
                return
            }

            msg.date = timestamp
            msg.isOwn = NSNumber(booleanLiteral: isOutgoing)
        }
        if let err = err {
            throw err
        }

        if !isOutgoing {
            messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: conversationIdentity)
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
                        DDLogWarn("Reverse geocoding failed: \(error?.localizedDescription ?? "")")

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

    func syncLoadBlob(blobID: Data, encryptionKey: Data, origin: BlobOrigin) -> Promise<Data?> {
        Promise { seal in
            let profilePictureLoader = ContactGroupPhotoLoader()
            profilePictureLoader.start(with: blobID, encryptionKey: encryptionKey, origin: origin) { data in
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

    private func conversationSender(
        forMessage message: AbstractMessage,
        isOutgoing: Bool
    ) throws -> (conversation: Conversation, sender: ContactEntity?) {
        var conversationIdentity: String?
        var result = frameworkInjector.backgroundEntityManager.existingConversationSenderReceiver(for: message)
        if !isOutgoing {
            guard let sender = result.sender else {
                throw MediatorReflectedProcessorError.senderNotFound(identity: message.fromIdentity)
            }
            frameworkInjector.backgroundEntityManager.performBlockAndWait {
                conversationIdentity = sender.identity
            }
        }
        else if !(message is AbstractGroupMessage) {
            guard let receiver = result.receiver else {
                throw MediatorReflectedProcessorError.receiverNotFound(identity: message.toIdentity)
            }
            frameworkInjector.backgroundEntityManager.performBlockAndWait {
                conversationIdentity = receiver.identity
            }
        }

        if let conversationIdentity, result.conversation == nil, !(message is AbstractGroupMessage) {
            frameworkInjector.backgroundEntityManager.performSyncBlockAndSafe {
                result.conversation = self.frameworkInjector.backgroundEntityManager.conversation(
                    for: conversationIdentity,
                    createIfNotExisting: true
                )
            }
        }
        guard let conversation = result.conversation else {
            throw MediatorReflectedProcessorError.conversationNotFound(message: message.loggingDescription)
        }

        return (conversation, result.sender)
    }
}
