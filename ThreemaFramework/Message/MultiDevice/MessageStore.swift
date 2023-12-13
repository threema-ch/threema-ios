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
import ThreemaEssentials
import ThreemaProtocols

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
        createdAt: Date,
        reflectedAt: Date
    ) throws {
        messageProcessorDelegate.incomingMessageStarted(audioMessage)

        let (conversation, _) = try conversationSender(forMessage: audioMessage, isOutgoing: false)

        guard let msg = try frameworkInjector.backgroundEntityManager.getOrCreateMessage(
            for: audioMessage,
            sender: nil,
            conversation: conversation,
            thumbnail: nil
        ) as? AudioMessageEntity else {
            throw MediatorReflectedProcessorError
                .messageNotProcessed(message: "Could not find/create audio message in DB")
        }
        
        frameworkInjector.backgroundEntityManager.performAndWaitSave {
            msg.date = createdAt
            msg.remoteSentDate = createdAt
        }

        messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: conversationIdentity)
        messageProcessorDelegate.incomingMessageFinished(audioMessage, isPendingGroup: false)
    }

    func save(
        fileMessage: BoxFileMessage,
        conversationIdentity: String,
        createdAt: Date,
        reflectedAt: Date,
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
                    self.frameworkInjector.backgroundEntityManager.performAndWaitSave {
                        msg?.id = fileMessage.messageID
                        msg?.date = createdAt
                        msg?.remoteSentDate = isOutgoing ? reflectedAt : createdAt
                    }

                    if !isOutgoing {
                        if let msg {
                            self.messageProcessorDelegate.incomingMessageChanged(
                                msg,
                                fromIdentity: conversationIdentity
                            )
                        }

                        self.messageProcessorDelegate.incomingMessageFinished(fileMessage, isPendingGroup: false)
                    }
                    else {
                        self.messageProcessorDelegate.changedManagedObjectID(conversation.objectID)
                        if let msg {
                            self.messageProcessorDelegate.changedManagedObjectID(msg.objectID)
                        }
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
        createdAt: Date,
        reflectedAt: Date,
        isOutgoing: Bool
    ) throws {
        if !isOutgoing {
            messageProcessorDelegate.incomingMessageStarted(textMessage)
        }

        let (conversation, _) = try conversationSender(forMessage: textMessage, isOutgoing: isOutgoing)

        guard let msg = try frameworkInjector.backgroundEntityManager.getOrCreateMessage(
            for: textMessage,
            sender: nil,
            conversation: conversation,
            thumbnail: nil
        ) as? TextMessage else {
            throw MediatorReflectedProcessorError.messageNotProcessed(message: "Could not find/create text message")
        }

        frameworkInjector.backgroundEntityManager.performAndWaitSave {
            msg.date = createdAt
            msg.remoteSentDate = isOutgoing ? reflectedAt : createdAt
        }

        if !isOutgoing {
            messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: conversationIdentity)
            messageProcessorDelegate.incomingMessageFinished(textMessage, isPendingGroup: false)
        }
        else {
            messageProcessorDelegate.changedManagedObjectID(conversation.objectID)
            messageProcessorDelegate.changedManagedObjectID(msg.objectID)
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
            guard let data else {
                return Promise()
            }

            self.frameworkInjector.backgroundEntityManager.performAndWait {
                let contact = self.frameworkInjector.backgroundEntityManager.entityFetcher
                    .contact(for: contactSetPhotoMessage.fromIdentity)
                self.frameworkInjector.contactStore.updateProfilePicture(
                    contact?.identity,
                    imageData: data,
                    shouldReflect: false,
                    blobID: nil,
                    encryptionKey: nil,
                    didFailWithError: nil
                )
            }

            self.changedContact(with: contactSetPhotoMessage.fromIdentity)
            return Promise()
        }
    }

    func save(
        deliveryReceiptMessage: DeliveryReceiptMessage,
        createdAt: Date,
        isOutgoing: Bool
    ) throws {
        var messageReadConversations = Set<Conversation>()

        for id in deliveryReceiptMessage.receiptMessageIDs {
            if let messageID = id as? Data {
                try frameworkInjector.backgroundEntityManager.performAndWait {
                    if let conversation = self.frameworkInjector.backgroundEntityManager.conversation(
                        forMessage: deliveryReceiptMessage
                    ),
                        let msg = self.frameworkInjector.backgroundEntityManager.entityFetcher.message(
                            with: messageID,
                            conversation: conversation
                        ) {

                        if deliveryReceiptMessage.receiptType == .received {
                            DDLogNotice("Message ID \(msg.id.hexString) has been received by recipient")
                            self.frameworkInjector.backgroundEntityManager.performAndWaitSave {
                                msg.delivered = true
                                msg.deliveryDate = createdAt
                            }
                        }
                        else if deliveryReceiptMessage.receiptType == .read {
                            DDLogNotice("Message ID \(msg.id.hexString) has been read by recipient")
                            self.frameworkInjector.backgroundEntityManager.performAndWaitSave {
                                msg.read = true
                                msg.readDate = createdAt
                                
                                DDLogVerbose("Message marked as read: \(msg.id.hexString)")

                                messageReadConversations.insert(msg.conversation)
                            }

                            // If it is a read receipt of a reflected incoming message, then remove all notifications of
                            // this message
                            if isOutgoing {
                                if let key = PendingUserNotificationKey.key(
                                    identity: deliveryReceiptMessage.toIdentity,
                                    messageID: messageID
                                ) {
                                    self.frameworkInjector.userNotificationCenterManager.remove(
                                        key: key,
                                        exceptStage: nil,
                                        justPending: false
                                    )
                                }
                            }
                        }
                        else if deliveryReceiptMessage.receiptType == .ack {
                            DDLogNotice("Message ID \(msg.id.hexString) has been user acknowledged by recipient")
                            self.frameworkInjector.backgroundEntityManager.performAndWaitSave {
                                msg.userack = true
                                msg.userackDate = createdAt
                            }
                        }
                        else if deliveryReceiptMessage.receiptType == .decline {
                            DDLogNotice("Message ID \(msg.id.hexString) has been user declined by recipient")
                            self.frameworkInjector.backgroundEntityManager.performAndWaitSave {
                                msg.userack = false
                                msg.userackDate = createdAt
                            }
                        }
                        else {
                            DDLogWarn(
                                "Unknown delivery receipt type \(deliveryReceiptMessage.receiptType) with message ID \(messageID.hexString)"
                            )
                        }
                        self.messageProcessorDelegate.changedManagedObjectID(conversation.objectID)
                        self.messageProcessorDelegate.changedManagedObjectID(msg.objectID)
                    }
                    else {
                        throw MediatorReflectedProcessorError.messageNotProcessed(
                            message: "Unable to store delivery receipt (\(deliveryReceiptMessage.receiptType)) for message \(messageID.hexString) because conversation or message was not found"
                        )
                    }
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
        createdAt: Date,
        reflectedAt: Date
    ) throws {
        messageProcessorDelegate.incomingMessageStarted(groupAudioMessage)

        let (conversation, sender) = try conversationSender(forMessage: groupAudioMessage, isOutgoing: false)

        guard let sender else {
            throw MediatorReflectedProcessorError.senderNotFound(identity: senderIdentity)
        }

        guard let msg = try frameworkInjector.backgroundEntityManager.getOrCreateMessage(
            for: groupAudioMessage,
            sender: sender,
            conversation: conversation,
            thumbnail: nil
        ) as? AudioMessageEntity else {
            throw MediatorReflectedProcessorError
                .messageNotProcessed(message: "Could not find/create group audio message in DB")
        }

        frameworkInjector.backgroundEntityManager.performAndWaitSave {
            msg.date = createdAt
            msg.remoteSentDate = createdAt
        }

        messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: senderIdentity)
        messageProcessorDelegate.incomingMessageFinished(groupAudioMessage, isPendingGroup: false)
    }

    func save(groupCreateMessage amsg: GroupCreateMessage) throws -> Promise<Void> {
        // Validate members, all members must be known contacts, otherwise device is not in sync
        try frameworkInjector.entityManager.performAndWait {
            for identity in (amsg.groupMembers as! [String])
                .filter({ $0 != self.frameworkInjector.myIdentityStore.identity }) {
                guard self.frameworkInjector.entityManager.entityFetcher.contact(for: identity) != nil else {
                    DDLogWarn("Unknown group member \(identity), device not in sync anymore")
                    throw MediatorReflectedProcessorError.contactNotFound(identity: identity)
                }
            }
        }

        let groupIdentity = GroupIdentity(id: amsg.groupID, creator: ThreemaIdentity(amsg.groupCreator))

        return frameworkInjector.backgroundGroupManager.createOrUpdateDB(
            for: groupIdentity,
            members: Set<String>(amsg.groupMembers.map { $0 as! String }),
            systemMessageDate: amsg.date,
            sourceCaller: .sync
        )
        .then { group -> Promise<Void> in
            guard group != nil else {
                throw MediatorReflectedProcessorError.groupCreateFailed(groupIdentity: groupIdentity)
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
        createdAt: Date,
        reflectedAt: Date,
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
                    self.frameworkInjector.backgroundEntityManager.performAndWaitSave {
                        msg?.id = groupFileMessage.messageID
                        msg?.date = createdAt
                        if !isOutgoing {
                            msg?.deliveryDate = reflectedAt
                            msg?.remoteSentDate = createdAt
                        }
                        else {
                            msg?.remoteSentDate = reflectedAt
                        }
                    }

                    if !isOutgoing {
                        if let msg {
                            self.messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: senderIdentity)
                        }

                        self.messageProcessorDelegate.incomingMessageFinished(
                            groupFileMessage,
                            isPendingGroup: false
                        )
                    }
                    else {
                        self.messageProcessorDelegate.changedManagedObjectID(conversation.objectID)
                        if let msg {
                            self.messageProcessorDelegate.changedManagedObjectID(msg.objectID)
                        }
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
        createdAt: Date,
        reflectedAt: Date,
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

            guard let msg = try frameworkInjector.backgroundEntityManager.getOrCreateMessage(
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

            frameworkInjector.backgroundEntityManager.performAndWaitSave {
                msg.date = createdAt
                msg.remoteSentDate = createdAt

                senderPublicKey = sender.publicKey
                messageID = msg.id
                conversationObjectID = conversation.objectID
                blobID = msg.blobIdentifier
                blobOrigin = msg.blobOrigin
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
        createdAt: Date,
        reflectedAt: Date,
        isOutgoing: Bool
    ) throws {
        if !isOutgoing {
            messageProcessorDelegate.incomingMessageStarted(groupLocationMessage)
        }

        let (conversation, sender) = try conversationSender(forMessage: groupLocationMessage, isOutgoing: isOutgoing)

        guard isOutgoing || (!isOutgoing && sender != nil) else {
            throw MediatorReflectedProcessorError.contactNotFound(identity: senderIdentity)
        }

        guard let msg = try frameworkInjector.backgroundEntityManager.getOrCreateMessage(
            for: groupLocationMessage,
            sender: sender,
            conversation: conversation,
            thumbnail: nil
        ) as? LocationMessage else {
            throw MediatorReflectedProcessorError
                .messageNotProcessed(message: "Could not find/create group location message in DB")
        }

        frameworkInjector.backgroundEntityManager.performAndWaitSave {
            msg.date = createdAt
            if !isOutgoing {
                msg.deliveryDate = reflectedAt
                msg.remoteSentDate = createdAt
            }
            else {
                msg.remoteSentDate = reflectedAt
            }
        }

        // Caution this is async
        setPoiAddress(message: msg)
            .done {
                if !isOutgoing {
                    self.messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: senderIdentity)
                    self.messageProcessorDelegate.incomingMessageFinished(groupLocationMessage, isPendingGroup: false)
                }
                else {
                    self.messageProcessorDelegate.changedManagedObjectID(conversation.objectID)
                    self.messageProcessorDelegate.changedManagedObjectID(msg.objectID)
                }
            }
            .catch { error in
                DDLogError("Set POI address failed \(error.localizedDescription)")
            }
    }

    func save(
        groupBallotCreateMessage: GroupBallotCreateMessage,
        senderIdentity: String,
        createdAt: Date,
        reflectedAt: Date,
        isOutgoing: Bool
    ) throws -> Promise<Void> {
        Promise { seal in
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

            let decoder = BallotMessageDecoder(self.frameworkInjector.backgroundEntityManager)
            decoder?.decodeCreateBallot(
                fromGroupBox: groupBallotCreateMessage,
                sender: sender,
                conversation: conversation, onCompletion: { msg in
                    Task {
                        await self.frameworkInjector.backgroundEntityManager.performSave {
                            msg.isOwn = NSNumber(booleanLiteral: isOutgoing)
                            msg.date = createdAt
                            if !isOutgoing {
                                msg.deliveryDate = reflectedAt
                                msg.remoteSentDate = createdAt
                            }
                            else {
                                msg.remoteSentDate = reflectedAt
                            }
                        }

                        if !isOutgoing {
                            self.messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: senderIdentity)
                            self.messageProcessorDelegate.incomingMessageFinished(
                                groupBallotCreateMessage,
                                isPendingGroup: false
                            )
                        }
                        else {
                            self.messageProcessorDelegate.changedManagedObjectID(conversation.objectID)
                            self.messageProcessorDelegate.changedManagedObjectID(msg.objectID)
                        }

                        seal.fulfill_()
                    }
                },
                onError: { error in
                    seal.reject(error)
                }
            )
        }
    }

    func save(groupBallotVoteMessage: GroupBallotVoteMessage) throws {
        try frameworkInjector.backgroundEntityManager.performAndWaitSave {
            if let decoder = BallotMessageDecoder(self.frameworkInjector.backgroundEntityManager),
               !decoder.decodeVote(fromGroupBox: groupBallotVoteMessage) {
                throw MediatorReflectedProcessorError
                    .messageDecodeFailed(message: groupBallotVoteMessage.loggingDescription)
            }
        }

        changedBallot(with: groupBallotVoteMessage.ballotID)
    }

    func save(groupSetPhotoMessage amsg: GroupSetPhotoMessage) -> Promise<Void> {
        syncLoadBlob(blobID: amsg.blobID, encryptionKey: amsg.encryptionKey, origin: .public)
            .then { (data: Data?) -> Promise<Void> in
                guard let data else {
                    return Promise()
                }

                return Promise { seal in
                    _ = self.frameworkInjector.backgroundEntityManager.performAndWait {
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
        createdAt: Date,
        isOutgoing: Bool
    ) throws {

        guard groupDeliveryReceiptMessage.receiptType == ReceiptType.ack.rawValue ||
            groupDeliveryReceiptMessage.receiptType == ReceiptType.decline.rawValue else {
            DDLogWarn("Unknown group delivery receipt type \(groupDeliveryReceiptMessage.receiptType)")
            return
        }

        let receiptType: GroupDeliveryReceipt.DeliveryReceiptType =
            groupDeliveryReceiptMessage.receiptType == ReceiptType.ack.rawValue ? .acknowledged : .declined

        for id in groupDeliveryReceiptMessage.receiptMessageIDs {
            if let messageID = id as? Data {
                try frameworkInjector.backgroundEntityManager.performAndWait {
                    guard let conversation = self.frameworkInjector.backgroundEntityManager.conversation(
                        forMessage: groupDeliveryReceiptMessage
                    ) else {
                        throw MediatorReflectedProcessorError
                            .conversationNotFound(message: groupDeliveryReceiptMessage.loggingDescription)
                    }
                    
                    if let msg = self.frameworkInjector.backgroundEntityManager.entityFetcher.message(
                        with: messageID,
                        conversation: conversation
                    ),
                        msg.conversation.groupID == groupDeliveryReceiptMessage.groupID {
                        self.frameworkInjector.backgroundEntityManager.performAndWaitSave {
                            let receipt = GroupDeliveryReceipt(
                                identity: groupDeliveryReceiptMessage.fromIdentity,
                                deliveryReceiptType: receiptType,
                                date: createdAt
                            )
                            msg.add(groupDeliveryReceipt: receipt)
                        }
                        self.messageProcessorDelegate.changedManagedObjectID(conversation.objectID)
                        self.messageProcessorDelegate.changedManagedObjectID(msg.objectID)
                    }
                    else {
                        throw MediatorReflectedProcessorError
                            .messageNotProcessed(message: groupDeliveryReceiptMessage.loggingDescription)
                    }
                }
            }
        }
    }

    func save(
        groupTextMessage: GroupTextMessage,
        senderIdentity: String,
        messageID: Data,
        createdAt: Date,
        reflectedAt: Date,
        isOutgoing: Bool
    ) throws {
        if !isOutgoing {
            messageProcessorDelegate.incomingMessageStarted(groupTextMessage)
        }

        let (conversation, sender) = try conversationSender(forMessage: groupTextMessage, isOutgoing: isOutgoing)

        guard isOutgoing || (!isOutgoing && sender != nil) else {
            throw MediatorReflectedProcessorError.senderNotFound(identity: groupTextMessage.fromIdentity)
        }

        guard let msg = try frameworkInjector.backgroundEntityManager.getOrCreateMessage(
            for: groupTextMessage,
            sender: sender,
            conversation: conversation,
            thumbnail: nil
        ) as? TextMessage else {
            throw MediatorReflectedProcessorError.messageNotProcessed(message: "Could not find/create text message")
        }

        frameworkInjector.backgroundEntityManager.performAndWaitSave {
            msg.date = createdAt
            if !isOutgoing {
                msg.delivered = true
                msg.deliveryDate = reflectedAt
                msg.remoteSentDate = createdAt
            }
            else {
                msg.remoteSentDate = reflectedAt
            }
        }

        if !isOutgoing {
            messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: senderIdentity)
            messageProcessorDelegate.incomingMessageFinished(groupTextMessage, isPendingGroup: false)
        }
        else {
            messageProcessorDelegate.changedManagedObjectID(conversation.objectID)
            messageProcessorDelegate.changedManagedObjectID(msg.objectID)
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
        createdAt: Date,
        reflectedAt: Date,
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
            guard let msg = try frameworkInjector.backgroundEntityManager.getOrCreateMessage(
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

            frameworkInjector.backgroundEntityManager.performAndWaitSave {
                msg.date = createdAt
                msg.remoteSentDate = createdAt

                conversationObjectID = conversation.objectID
                messageID = msg.id
                blobOrigin = msg.blobOrigin
            }

            self.messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: senderIdentity)

            // A VideoMessage never has a local blob because all note group capable devices send everything as
            // FileMessage (-> localOrigin: false)
            // Download, decrypt and save blob of thumbnail
            let downloadQueue = DispatchQueue.global(qos: .default)
            let videoProcessor = VideoMessageProcessor(
                blobDownloader: BlobDownloader(blobURL: BlobURL(
                    serverConnector: self.frameworkInjector.serverConnector,
                    userSettings: self.frameworkInjector.userSettings,
                    queue: DispatchQueue.global(qos: .userInitiated)
                ), queue: downloadQueue),
                userSettings: self.frameworkInjector.userSettings,
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
        createdAt: Date,
        reflectedAt: Date,
        isOutgoing: Bool
    ) throws {
        if !isOutgoing {
            messageProcessorDelegate.incomingMessageStarted(locationMessage)
        }

        let (conversation, _) = try conversationSender(forMessage: locationMessage, isOutgoing: isOutgoing)

        guard let msg = try frameworkInjector.backgroundEntityManager.getOrCreateMessage(
            for: locationMessage,
            sender: nil,
            conversation: conversation,
            thumbnail: nil
        ) as? LocationMessage else {
            throw MediatorReflectedProcessorError.messageNotProcessed(message: "Could not find/create location message")
        }

        frameworkInjector.backgroundEntityManager.performAndWaitSave {
            msg.date = createdAt
            msg.remoteSentDate = isOutgoing ? reflectedAt : createdAt
            msg.delivered = true
        }

        // Caution this is async
        setPoiAddress(message: msg)
            .done {
                if !isOutgoing {
                    self.messageProcessorDelegate.incomingMessageChanged(msg, fromIdentity: conversationIdentity)
                    self.messageProcessorDelegate.incomingMessageFinished(locationMessage, isPendingGroup: false)
                }
                else {
                    self.messageProcessorDelegate.changedManagedObjectID(conversation.objectID)
                    self.messageProcessorDelegate.changedManagedObjectID(msg.objectID)
                }
            }
            .catch { error in
                DDLogError("Set POI address failed \(error)")
            }
    }

    func save(
        ballotCreateMessage: BoxBallotCreateMessage,
        conversationIdentity: String,
        createdAt: Date,
        reflectedAt: Date,
        isOutgoing: Bool
    ) throws -> Promise<Void> {
        Promise { seal in
            if !isOutgoing {
                messageProcessorDelegate.incomingMessageStarted(ballotCreateMessage)
            }

            let (conversation, sender) = try conversationSender(forMessage: ballotCreateMessage, isOutgoing: isOutgoing)

            guard isOutgoing || (!isOutgoing && sender != nil) else {
                throw MediatorReflectedProcessorError.senderNotFound(identity: ballotCreateMessage.fromIdentity)
            }

            let decoder = BallotMessageDecoder(self.frameworkInjector.backgroundEntityManager)
            decoder?.decodeCreateBallot(
                fromBox: ballotCreateMessage,
                sender: sender,
                conversation: conversation,
                onCompletion: { msg in
                    Task {
                        await self.frameworkInjector.backgroundEntityManager.performSave {
                            msg.isOwn = NSNumber(booleanLiteral: isOutgoing)
                            msg.date = createdAt
                            msg.remoteSentDate = isOutgoing ? reflectedAt : createdAt

                            if !isOutgoing {
                                self.messageProcessorDelegate.incomingMessageChanged(
                                    msg,
                                    fromIdentity: conversationIdentity
                                )
                                self.messageProcessorDelegate.incomingMessageFinished(
                                    ballotCreateMessage,
                                    isPendingGroup: false
                                )
                            }
                            else {
                                self.messageProcessorDelegate.changedManagedObjectID(conversation.objectID)
                                self.messageProcessorDelegate.changedManagedObjectID(msg.objectID)
                            }
                        }

                        seal.fulfill_()
                    }
                },
                onError: { error in
                    seal.reject(error)
                }
            )
        }
    }

    func save(ballotVoteMessage: BoxBallotVoteMessage) throws {
        try frameworkInjector.backgroundEntityManager.performAndWaitSave {
            if let decoder = BallotMessageDecoder(self.frameworkInjector.backgroundEntityManager),
               !decoder.decodeVote(fromBox: ballotVoteMessage) {
                throw MediatorReflectedProcessorError
                    .messageDecodeFailed(message: ballotVoteMessage.loggingDescription)
            }
        }

        changedBallot(with: ballotVoteMessage.ballotID)
    }
    
    func save(
        groupCallStartMessage: GroupCallStartMessage,
        decodedCallStartMessage: CspE2e_GroupCallStart,
        senderIdentity: String,
        createdAt: Date,
        reflectedAt: Date,
        isOutgoing: Bool
    ) throws -> Promise<Void> {
        Promise { seal in
            Task {
                await self.frameworkInjector.entityManager.performSave {
                    
                    guard let conversation = self.frameworkInjector.backgroundEntityManager.entityFetcher.conversation(
                        for: groupCallStartMessage.groupID,
                        creator: groupCallStartMessage.groupCreator
                    ) else {
                        seal
                            .reject(
                                MediatorReflectedProcessorError
                                    .messageNotProcessed(message: groupCallStartMessage.loggingDescription)
                            )
                        return
                    }
                    
                    let fromIdentity = groupCallStartMessage.fromIdentity == self.frameworkInjector.myIdentityStore
                        .identity ? nil : groupCallStartMessage.fromIdentity
                    
                    GlobalGroupCallsManagerSingleton.shared.handleMessage(
                        rawMessage: decodedCallStartMessage,
                        from: fromIdentity!,
                        in: conversation,
                        receiveDate: groupCallStartMessage.date,
                        onCompletion: {
                            if !isOutgoing {
                                self.messageProcessorDelegate.incomingMessageFinished(
                                    groupCallStartMessage,
                                    isPendingGroup: false
                                )
                            }
                            self.messageProcessorDelegate.changedManagedObjectID(conversation.objectID)

                            seal.fulfill_()
                        }
                    )
                }
            }
        }
    }

    // MARK: Misc

    /// Get poi-address, if is necessary.
    /// - Parameter message:: Location message to save address
    private func setPoiAddress(message: LocationMessage?) -> Promise<Void> {
        Promise { seal in
            self.frameworkInjector.backgroundEntityManager.performAndWait {
                if let message,
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
                            self.frameworkInjector.backgroundEntityManager.performAndWaitSave {
                                message.poiAddress = geoLabel
                            }
                            seal.fulfill_()
                        }
                    ) { error in
                        DDLogWarn("Reverse geocoding failed: \(error)")

                        self.frameworkInjector.backgroundEntityManager.performAndWaitSave {
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

    private func syncLoadBlob(blobID: Data, encryptionKey: Data, origin: BlobOrigin) -> Promise<Data?> {
        Promise { seal in
            let downloadQueue = DispatchQueue.global(qos: .default)

            let blobDownloader = BlobDownloader(
                blobURL: BlobURL(
                    serverConnector: self.frameworkInjector.serverConnector,
                    userSettings: self.frameworkInjector.userSettings,
                    queue: downloadQueue
                ),
                queue: downloadQueue
            )
            blobDownloader.download(blobID: blobID, origin: origin) { data, error in
                if let error = error as? NSError {
                    if error.code == 404 {
                        seal.fulfill(nil)
                    }
                    else {
                        seal.reject(MediatorReflectedProcessorError.downloadFailed(message: error.localizedDescription))
                    }
                    return
                }

                // Decrypt blob data
                guard let imageData = NaClCrypto.shared()
                    .symmetricDecryptData(data, withKey: encryptionKey, nonce: ThreemaProtocol.nonce01) else {
                    seal.reject(MediatorReflectedProcessorError.downloadFailed(message: "Decrypt blob data failed"))
                    return
                }

                blobDownloader.markDownloadDone(for: blobID, origin: .local)

                seal.fulfill(imageData)
            }
        }
    }

    private func changedBallot(with ballotID: Data) {
        frameworkInjector.entityManager.performAndWait {
            if let ballot = self.frameworkInjector.entityManager.entityFetcher.ballot(for: ballotID) {
                self.messageProcessorDelegate.changedManagedObjectID(ballot.objectID)
            }
        }
    }

    private func changedContact(with identity: String) {
        frameworkInjector.entityManager.performAndWait {
            if let contact = self.frameworkInjector.entityManager.entityFetcher.contact(for: identity) {
                self.messageProcessorDelegate.changedManagedObjectID(contact.objectID)
            }
        }
    }

    private func changedConversationAndGroupEntity(groupID: Data, groupCreatorIdentity: String) {
        frameworkInjector.entityManager.performAndWait {
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
            frameworkInjector.backgroundEntityManager.performAndWait {
                conversationIdentity = sender.identity
            }
        }
        else if !(message is AbstractGroupMessage) {
            guard let receiver = result.receiver else {
                throw MediatorReflectedProcessorError.receiverNotFound(identity: message.toIdentity)
            }
            frameworkInjector.backgroundEntityManager.performAndWait {
                conversationIdentity = receiver.identity
            }
        }

        if let conversationIdentity, result.conversation == nil, !(message is AbstractGroupMessage) {
            frameworkInjector.backgroundEntityManager.performAndWaitSave {
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
