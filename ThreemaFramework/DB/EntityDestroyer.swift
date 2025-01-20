//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2025 Threema GmbH
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

@objc public class EntityDestroyer: NSObject {
    
    /// Relative to app data (group container) path.
    public static let externalDataPath = ".ThreemaData_SUPPORT/_EXTERNAL_DATA"
    public static let externalDataBinPath = "_EXTERNAL_DATA_BIN"

    private let objCnx: TMAManagedObjectContext
    private let myIdentityStore: MyIdentityStoreProtocol

    @objc public required init(
        managedObjectContext: TMAManagedObjectContext,
        myIdentityStore: MyIdentityStoreProtocol
    ) {
        self.objCnx = managedObjectContext
        self.myIdentityStore = myIdentityStore
    }
    
    // MARK: - Public methods
    
    /// Delete media files of audio, file, image and video messages.
    ///
    /// - Parameters:
    ///   - olderThan: All message older than that date will be deleted
    ///   - conversation: ConversationEntity
    /// - Returns:
    ///   Count of deleted media files
    public func deleteMedias(olderThan: Date?, for conversation: ConversationEntity? = nil) -> Int? {
        var deletedObjects = 0
        let mediaMessageTypes = [
            AudioMessageEntity.self,
            FileMessageEntity.self,
            ImageMessageEntity.self,
            VideoMessageEntity.self,
        ]
        for mediaMessageType in mediaMessageTypes {
            if let count = deleteMediasOf(
                messageType: mediaMessageType,
                olderThan: olderThan,
                conversation: conversation
            ) {
                deletedObjects += count
            }
        }
        
        return deletedObjects
    }
    
    func deleteMediasOf(
        messageType: (some BaseMessage).Type,
        olderThan: Date?,
        conversation: ConversationEntity? = nil
    ) -> Int? {
        guard messageType is AudioMessageEntity.Type ||
            messageType is FileMessageEntity.Type ||
            messageType is ImageMessageEntity.Type ||
            messageType is VideoMessageEntity.Type
        else {
            return nil
        }
        
        do {
            let mediaMetaInfo = try getMediaMetaInfo(messageType: messageType)

            if let olderThan {
                if let conversation {
                    mediaMetaInfo.fetchMessages.predicate = NSPredicate(
                        format: "%K != nil AND date < %@ AND conversation == %@",
                        mediaMetaInfo.relationship,
                        olderThan as NSDate,
                        conversation
                    )
                }
                else {
                    mediaMetaInfo.fetchMessages.predicate = NSPredicate(
                        format: "%K != nil AND date < %@",
                        mediaMetaInfo.relationship,
                        olderThan as NSDate
                    )
                }
            }
            else {
                if let conversation {
                    mediaMetaInfo.fetchMessages.predicate = NSPredicate(
                        format: "%K != nil AND conversation == %@",
                        mediaMetaInfo.relationship,
                        conversation
                    )
                }
                else {
                    mediaMetaInfo.fetchMessages.predicate = NSPredicate(format: "%K != nil", mediaMetaInfo.relationship)
                }
            }
            
            guard let messages = try objCnx.fetch(mediaMetaInfo.fetchMessages) as? [BaseMessage] else {
                return 0
            }

            try deleteMedias(of: messages, messageType: messageType)

            return messages.count
        }
        catch let error as NSError {
            DDLogError("Could not delete medias. \(error), \(error.userInfo)")
        }
        
        return 0
    }

    private func deleteMedias<T: BaseMessage>(of messages: [BaseMessage], messageType: T.Type) throws {
        guard messageType is AudioMessageEntity.Type ||
            messageType is FileMessageEntity.Type ||
            messageType is ImageMessageEntity.Type ||
            messageType is VideoMessageEntity.Type
        else {
            return
        }

        var deleteMediaIDs: [NSManagedObjectID] = []
        var updateMessageIDs: [NSManagedObjectID] = []

        let mediaMetaInfo = try getMediaMetaInfo(messageType: messageType)

        for message in messages {
            if let message = message as? T {
                deleteMediaIDs
                    .append(contentsOf: message.objectIDs(forRelationshipNamed: mediaMetaInfo.relationship))
                updateMessageIDs.append(message.objectID)
            }
        }

        let deleteFilenames = getExternalFilenames(ofMessages: messages, includeThumbnail: false)

        if !deleteMediaIDs.isEmpty {
            var changes = [AnyHashable: [NSManagedObjectID]]()

            // Delete media
            var confirmedDeletedIDs: [NSManagedObjectID] = []

            objCnx.propagatesDeletesAtEndOfEvent = true
            for mediaID in deleteMediaIDs {
                objCnx.performAndWait {
                    do {
                        let object = try self.objCnx.existingObject(with: mediaID)

                        if let message = object as? BaseMessage {
                            nullifyConversationLastMessage(for: [message])
                        }

                        self.objCnx.delete(object)

                        try self.objCnx.save()

                        confirmedDeletedIDs.append(mediaID)
                    }
                    catch {
                        DDLogError("Could not delete file. Error: \(error); \(error.localizedDescription)")
                    }
                }
            }

            changes[NSDeletedObjectIDsKey] = confirmedDeletedIDs

            if !updateMessageIDs.isEmpty {
                var updatedIDs: [NSManagedObjectID] = []

                for updateID in updateMessageIDs {
                    if let updateMessage = try objCnx.existingObject(with: updateID) as? T {
                        objCnx.performAndWait {
                            var updated = false

                            // Update data reference to nil (if it failed to to be deleted when the object was
                            // deleted)
                            if updateMessage.value(forKey: mediaMetaInfo.relationship) != nil {
                                updateMessage.setValue(nil, forKey: mediaMetaInfo.relationship)
                                updated = true
                            }

                            // Update blobIDs to nil (to prevent downloading blob again)
                            if updateMessage.value(forKey: mediaMetaInfo.blobIDField) != nil {
                                updateMessage.setValue(nil, forKey: mediaMetaInfo.blobIDField)
                                updated = true
                            }

                            if updated {
                                do {
                                    try self.objCnx.save()

                                    updatedIDs.append(updateID)
                                }
                                catch let error as NSError {
                                    DDLogError("Cloud not update message. \(error), \(error.userInfo)")
                                }
                            }
                        }
                    }
                }
                changes[NSUpdatedObjectsKey] = updatedIDs
            }

            if !changes.isEmpty {
                let dbManager = DatabaseManager()
                dbManager.refreshDirtyObjectIDs(changes, into: objCnx)
            }

            deleteExternalFiles(list: deleteFilenames)
        }
    }

    /// Delete content of given message, message metadata remains.
    /// - Parameter message: Message to its content
    func deleteMessageContent(of message: BaseMessage) throws {
        guard message.typeSupportsRemoteDeletion else {
            return
        }

        // Just delete media for message types like `AudioMessageEntity`, `FileMessageEntity`, `ImageMessageEntity` and
        // `VideoMessageEntity`
        try deleteMedias(of: [message], messageType: type(of: message))
        
        // Remove all reactions
        message.userack = 0
        message.userackDate = nil
        message.groupDeliveryReceipts = nil

        if let message = message as? LocationMessageEntity {
            message.latitude = 0
            message.longitude = 0
            message.accuracy = 0
            message.poiAddress = nil
            message.poiName = nil
        }
        else if let message = message as? TextMessageEntity {
            message.text = ""
        }
        else if let message = message as? FileMessageEntity {
            deleteThumbnail(for: message)
            // swiftformat:disable: acronyms
            message.blobId = nil
            message.blobThumbnailId = nil
            // swiftformat:enable: acronyms
            message.caption = ""
            message.encryptionKey = nil
            message.fileName = ""
            message.fileSize = nil
            message.json = ""
            message.mimeType = ""
            message.origin = nil
            message.progress = nil
            message.type = nil
            message.consumed = nil
            message.thumbnail = nil
        }
        else if let message = message as? ImageMessageEntity {
            deleteThumbnail(for: message)

            message.encryptionKey = nil
            // swiftformat:disable:next acronyms
            message.imageBlobId = nil
            message.imageSize = nil
            message.progress = 0
            // swiftformat:disable:next acronyms
            message.imageBlobId = nil
            message.thumbnail = nil
        }
        else if let message = message as? VideoMessageEntity {
            deleteThumbnail(for: message)
            
            message.duration = 0
            message.encryptionKey = nil
            message.progress = 0
            // swiftformat:disable:next acronyms
            message.videoBlobId = nil
            message.videoSize = nil
            message.duration = 0
        }
        
        if let historyEntries = message.historyEntries {
            for history in historyEntries {
                delete(entity: history)
            }
        }
        
        if let reactions = message.reactions {
            for reaction in reactions {
                delete(entity: reaction)
            }
        }
    }

    private func deleteThumbnail(for message: BaseMessage) {
        guard message is FileMessageEntity || message is ImageMessageEntity || message is VideoMessageEntity else {
            return
        }

        let thumbnailObjectIDs = message.objectIDs(forRelationshipNamed: "thumbnail")
        guard !thumbnailObjectIDs.isEmpty else {
            return
        }

        for objectID in thumbnailObjectIDs {
            objCnx.performAndWait {
                do {
                    let object = try self.objCnx.existingObject(with: objectID)

                    if message is FileMessageEntity || message is ImageMessageEntity {
                        self.objCnx.delete(object)
                    }
                    else if message is VideoMessageEntity,
                            let imageData = object as? ImageDataEntity,
                            let defaultThumbnail = UIImage(named: "threema.video.fill"),
                            let data = defaultThumbnail.jpegData(compressionQuality: kJPEGCompressionQualityLow) {

                        imageData.data = data
                        imageData.width = Int16(defaultThumbnail.size.width)
                        imageData.height = Int16(defaultThumbnail.size.height)
                    }

                    try self.objCnx.save()
                }
                catch {
                    DDLogError("Could not delete thumbnail. Error: \(error); \(error.localizedDescription)")
                }
            }
        }
    }

    /// Delete all kind of messages.
    ///
    /// - Parameters:
    ///    - olderThan: All message older than that date will be deleted
    ///    - conversation: Conversation
    ///
    /// - Returns:
    ///    Count of deleted messages
    public func deleteMessages(olderThan: Date?, for conversation: ConversationEntity? = nil) -> Int? {
        let fetchMessages = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        
        if let conversation {
            if let olderThan {
                fetchMessages.predicate = NSPredicate(
                    format: "date < %@ && conversation == %@",
                    olderThan as NSDate,
                    conversation
                )
            }
            else {
                fetchMessages.predicate = NSPredicate(format: "conversation == %@", conversation)
            }
        }
        else {
            if let olderThan {
                fetchMessages.predicate = NSPredicate(format: "date < %@", olderThan as NSDate)
            }
        }
        
        let deletedMessages = deleteMessages(with: fetchMessages)

        if deletedMessages > 0 {
            NotificationCenter.default.post(
                name: NSNotification.Name(kNotificationBatchDeletedOldMessages),
                object: nil
            )
            return deletedMessages
        }
        return nil
    }

    /// Delete all kind of messages.
    ///
    /// - Parameters:
    ///    - olderThan: All message older than that date will be deleted
    ///    - conversations: Conversation
    public func deleteMessagesForMessageRetention(olderThan: Date, for conversationsIDs: [NSManagedObjectID]) async {
        await objCnx.perform {
            let conversations = conversationsIDs
                .compactMap { try? self.objCnx.existingObject(with: $0) as? ConversationEntity }
            let fetchMessages = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
            fetchMessages.predicate = NSPredicate(
                format: "conversation IN %@ AND date < %@",
                conversations,
                olderThan as NSDate
            )
            self.messageRetentionDelete(with: fetchMessages)
        }
    }
    
    /// Fetch number of messages to be deleted for message retention
    ///
    /// Open ballots are excluded.
    /// - Parameters:
    ///   - olderThan: All message older than that date will be counted
    ///   - conversations: conversations affected by the filter and counting
    /// - Returns: the number of messages filtered. Returns 0 if there are no messages to be deleted and if the fetch
    /// fails
    public func messagesToBeDeleted(olderThan: Date, for conversationsIDs: [NSManagedObjectID]) async -> Int {
        await objCnx.perform {
            let conversations = conversationsIDs
                .compactMap { try? self.objCnx.existingObject(with: $0) as? ConversationEntity }
            guard !conversations.isEmpty else {
                return 0
            }
            
            let fetchMessages = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
            fetchMessages.predicate = NSPredicate(
                format: "conversation IN %@ AND date < %@",
                conversations,
                olderThan as NSDate
            )
            let messages = (try? self.objCnx.fetch(fetchMessages)) as? [BaseMessage] ?? []
            // Currently we want to keep open Ballots excluded from deletion
            let filtered = messages.filter { message in
                guard let ballotMessage = message as? BallotMessage else {
                    return true
                }
                return ballotMessage.ballot?.isClosed() ?? false
            }
            return filtered.count
        }
    }

    /// Delete all kind of messages within conversation.
    ///
    /// - Parameters:
    ///    - conversation: Delete all message of this ConversationEntity
    ///
    /// - Returns:
    ///    Count of deleted messages
    @objc public func deleteMessages(of conversation: ConversationEntity) -> Int {
        let fetchMessages = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        fetchMessages.predicate = NSPredicate(format: "conversation = %@", conversation)
        
        let deletedMessages = deleteMessages(with: fetchMessages)
        if deletedMessages > 0 {
            NotificationCenter.default.post(
                name: NSNotification.Name(kNotificationBatchDeletedAllConversationMessages),
                object: nil,
                userInfo: [kKeyObjectID: conversation.objectID]
            )
        }
        return deletedMessages
    }

    @objc func delete(ballot: Ballot) {
        delete(entity: ballot)
    }
    
    @objc func delete(reaction: MessageReactionEntity) {
        delete(entity: reaction)
    }
    
    @objc func delete(ballotChoice: BallotChoice) {
        delete(entity: ballotChoice)
    }

    @objc public func delete(baseMessage: BaseMessage) {
        delete(entity: baseMessage)
    }

    public func delete(callEntity: CallEntity) {
        delete(entity: callEntity)
    }

    @objc public func delete(conversation: ConversationEntity) {
        delete(entity: conversation)
    }

    #if DEBUG
        @available(*, deprecated, message: "Use this function only for testing!")
        /// - Parameter contactEntity: Core Data object
        @objc public func delete(contactEntity: ContactEntity) {
            delete(entity: contactEntity)
        }
    #endif

    @objc public func delete(distributionListEntity: DistributionListEntity) {
        delete(entity: distributionListEntity)
    }

    func delete(groupCallEntity: GroupCallEntity) {
        delete(entity: groupCallEntity)
    }

    func delete(groupEntity: GroupEntity) {
        delete(entity: groupEntity)
    }

    func delete(imageDataEntity: ImageDataEntity) {
        delete(entity: imageDataEntity)
    }

    func delete(lastGroupSyncRequestEntity: LastGroupSyncRequestEntity) {
        delete(entity: lastGroupSyncRequestEntity)
    }

    func delete(messageHistoryEntryEntity: MessageHistoryEntryEntity) {
        delete(entity: messageHistoryEntryEntity)
    }

    public func delete(webClientSessionEntity: WebClientSessionEntity) {
        delete(entity: webClientSessionEntity)
    }

    /// Delete particular DB object.
    ///
    /// - Parameters:
    ///    - object: object to delete
    private func delete(entity object: NSManagedObject) {
        var shouldUpdateConversationContent = false
        if let conversation = object as? ConversationEntity {
            let count = deleteMessages(of: conversation)
            DDLogDebug("\(count) messages deleted from conversation")
            
            MessageDraftStore.shared.deleteDraft(for: conversation)
        }
        else if let contact = object as? ContactEntity {
            // Remove all conversations and messages for this contact
            if let conversations = contact.conversations {
                for genericConversation in conversations {
                    guard let conversation = genericConversation as? ConversationEntity else {
                        fatalError("Can't delete a conversation of a contact, because it's not a conversation object")
                        continue
                    }
                    delete(entity: conversation)
                }
            }
            
            // check all group conversations to delete messages from this contact
            let count = deleteMessages(for: contact)
            DDLogDebug("\(count) group messages deleted from contact")

            if count > 0 {
                shouldUpdateConversationContent = true
            }
        }
        else if let distributionList = object as? DistributionListEntity {
            delete(entity: distributionList.conversation)
        }
                
        let deleteFilenames = getExternalFilenames(ofMessages: [object], includeThumbnail: true)

        deleteExternalFiles(list: deleteFilenames)

        if let message = object as? BaseMessage {
            nullifyConversationLastMessage(for: [message])
        }
        
        objCnx.delete(object)
        
        if shouldUpdateConversationContent {
            // Update open chats content
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name(kNotificationBatchDeletedOldMessages),
                    object: nil,
                    userInfo: nil
                )
            }
        }
    }

    /// Delete 1:1 conversation of a contact.
    ///
    /// - Parameter contactEntity: Delete 1:1 conversation of this contact
    public func deleteOneToOneConversation(for contactEntity: ContactEntity) {
        if let conversations = contactEntity.conversations as? Set<ConversationEntity> {
            for conversation in conversations.filter({ !$0.isGroup }) {
                delete(conversation: conversation)
            }
        }
    }

    /// Delete `ContactEntity` of own identity.
    ///
    /// - Returns: True own contact was found and deleted
    public func deleteOwnContact() -> Bool {
        guard let identity = myIdentityStore.identity else {
            DDLogError("[AppMigration] Own contact cannot be deleted because no Threema-ID is in the keychain")
            return false
        }
        
        let fetchContacts = NSFetchRequest<NSFetchRequestResult>(entityName: "Contact")
        fetchContacts.predicate = NSPredicate(format: "identity = %@", identity)

        guard let entities = try? objCnx.fetch(fetchContacts) as? [ContactEntity], !entities.isEmpty else {
            return false
        }

        for entity in entities {
            delete(entity: entity)
        }

        return true
    }

    /// Get orphaned external files.
    ///
    /// - Returns: List of orphaned files, count of files in DB
    public func orphanedExternalFiles() -> (orphanedFiles: [String]?, totalFilesCount: Int) {
        
        // Load all external filenames
        if let files = FileUtility
            .shared
            .dir(
                pathURL: FileUtility.shared.appDataDirectory?
                    .appendingPathComponent("\(EntityDestroyer.externalDataPath)/")
            ),
            !files.isEmpty {
            
            // Load all filenames from DB
            var filesInDB = [String]()
            do {
                let fetchRequests: [NSFetchRequest<NSManagedObject>] = [
                    "AudioData",
                    "FileData",
                    "ImageData",
                    "VideoData",
                ]
                .map { NSFetchRequest<NSManagedObject>(entityName: $0) }
                
                for fetchRequest in fetchRequests {
                    try autoreleasepool {
                        let totalItems = try objCnx.count(for: fetchRequest)
                        let increment = 20
                        let sequence = stride(from: 0, to: totalItems, by: increment)
                        for i in sequence {
                            try autoreleasepool {
                                fetchRequest.fetchOffset = i
                                fetchRequest.fetchLimit = increment
                                
                                let items = try objCnx.fetch(fetchRequest)
                                for item in items {
                                    objCnx.refresh(item, mergeChanges: true)
                                    
                                    if let externalStorageInfo = item as? ExternalStorageInfo {
                                        if let filename = externalStorageInfo.getFilename() {
                                            filesInDB.append(filename)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            catch let error as NSError {
                DDLogError("Could not load filenames from DB. \(error), \(error.userInfo)")
            }
            
            // Filter orphaned external files
            let orphanedFiles = files.filter { file -> Bool in
                !filesInDB.contains(file)
            }
            #if DEBUG
                for file in orphanedFiles {
                    DDLogInfo("Orphaned file: \(file)")
                }
            #endif
            
            return (orphanedFiles, filesInDB.count)
        }
        
        return (nil, 0)
    }
    
    public func deleteMissedCallsCacheOlderThanTwoWeeks() {
        guard let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) as? NSDate else {
            fatalError()
        }
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Call")
        fetchRequest.predicate = NSPredicate(format: "date <= %@", twoWeeksAgo)
        
        do {
            let batch = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            batch.resultType = NSBatchDeleteRequestResultType.resultTypeObjectIDs
            let deleteResult = try objCnx.execute(batch) as? NSBatchDeleteResult
            
            if let deletedIDs = deleteResult?.result as? [NSManagedObjectID], !deletedIDs.isEmpty {
                let dbManager = DatabaseManager()
                dbManager.refreshDirtyObjectIDs([NSDeletedObjectsKey: deletedIDs], into: objCnx)
            }
            else {
                // Fallback for when the batch delete request misses the objects stored in the DB
                // This should only happen in unit tests but if it were to ever change and we'd miss it
                // well still be safe in production.
                guard let fetchedCalls = try? fetchRequest.execute() as? [NSManagedObject] else {
                    DDLogError("Could not delete calls cache. Unknown error.")
                    return
                }
                
                for fetchedCall in fetchedCalls {
                    delete(entity: fetchedCall)
                }
            }
        }
        catch let error as NSError {
            DDLogError("Could not delete calls cache. \(error), \(error.userInfo)")
        }
    }
    
    // MARK: - Private helper methods
    
    /// Used to Delete the Messages according to the Retention Policy.
    /// Currently all but Open Polls are affected.
    ///
    /// - Parameter fetchRequest: fetchRequest to be used to fetch the messages
    private func messageRetentionDelete(with fetchRequest: NSFetchRequest<NSFetchRequestResult>) {
        do {
            try Task.checkCancellation()

            let messages = try (objCnx.fetch(fetchRequest)) as? [BaseMessage] ?? []
            
            // Currently we want to keep open ballots and starred messages excluded from deletion
            let filtered = messages.filter { message in
                if let ballotMessage = message as? BallotMessage, let isClosed = ballotMessage.ballot?.isClosed(),
                   !isClosed {
                    return false
                }
                
                if let messageMarkers = message.messageMarkers, messageMarkers.star.boolValue {
                    return false
                }
                
                return true
            }

            guard !filtered.isEmpty else {
                return
            }

            let deleteFilenames = getExternalFilenames(ofMessages: filtered, includeThumbnail: true)

            nullifyConversationLastMessage(for: filtered)

            // With a batch delete will sometimes the external file of a file message not deleted immediately. If the
            // external file is remaining, than the only way to delete this is in Settings - Advanced - Delete Orphaned
            // Files
            let batch = NSBatchDeleteRequest(objectIDs: filtered.map(\.objectID))
            batch.resultType = .resultTypeObjectIDs
            try Task.checkCancellation()
            
            if let deleteResult = try objCnx.execute(batch) as? NSBatchDeleteResult,
               let deletedIDs = deleteResult.result as? [NSManagedObjectID], !deletedIDs.isEmpty {
                refreshDatabaseMainAndDirectContexts(for: deletedIDs)

                deleteExternalFiles(list: deleteFilenames)

                DDLogNotice("[Message Retention]: Deleted \(deletedIDs.count) messages")
            }
            
            NotificationCenter.default.post(
                name: NSNotification.Name(kNotificationBatchDeletedOldMessages),
                object: nil
            )
        }
        catch {
            DDLogError("Could not delete messages: \(error)")
        }
    }
    
    private func getMediaMetaInfo(
        messageType: (some Any)
            .Type
    ) throws -> (fetchMessages: NSFetchRequest<NSManagedObject>, relationship: String, blobIDField: String) {
        
        var fetchMessages: NSFetchRequest<NSManagedObject>
        var relationship: String
        var blobIDField: String

        if messageType is AudioMessageEntity.Type {
            fetchMessages = NSFetchRequest<NSManagedObject>(entityName: "AudioMessage")
            relationship = "audio"
            blobIDField = "audioBlobId"
        }
        else if messageType is FileMessageEntity.Type {
            fetchMessages = NSFetchRequest<NSManagedObject>(entityName: "FileMessage")
            relationship = "data"
            blobIDField = "blobId"
        }
        else if messageType is ImageMessageEntity.Type {
            fetchMessages = NSFetchRequest<NSManagedObject>(entityName: "ImageMessage")
            relationship = "image"
            blobIDField = "imageBlobId"
        }
        else if messageType is VideoMessageEntity.Type {
            fetchMessages = NSFetchRequest<NSManagedObject>(entityName: "VideoMessage")
            relationship = "video"
            blobIDField = "videoBlobId"
        }
        else {
            fatalError("message type not defined")
        }
        
        return (fetchMessages, relationship, blobIDField)
    }
    
    private func getExternalFilenames(ofObjectIDs: [NSManagedObjectID], includeThumbnail: Bool) -> [String] {
        var externalFilenames = [String]()

        do {
            for entityName in ["AudioMessage", "FileMessage", "ImageMessage", "VideoMessage"] {
                let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                fetch.predicate = NSPredicate(format: "self IN %@", ofObjectIDs)

                let messages = try objCnx.fetch(fetch)

                externalFilenames.append(
                    contentsOf: getExternalFilenames(ofMessages: messages, includeThumbnail: includeThumbnail)
                )
            }
        }
        catch {
            DDLogError("Fetching messages to evaluate external files failed: \(error)")
        }

        return externalFilenames
    }

    /// List names of external files.
    ///
    /// - Parameters:
    ///    - ofMessages: Check messages to external data files
    ///    - includeThumbnail: Check messages to external thumbnail files
    ///
    /// - Returns: Names of external files
    private func getExternalFilenames(ofMessages: [Any], includeThumbnail: Bool) -> [String] {
        var externalFilenames: [String] = []
        for message in ofMessages {
            if let blobData = message as? BlobData {
                
                // Refreshing media objects, otherwise external filenames can not be evaluated for new messages
                let mediaMetaInfo: (
                    fetchMessages: NSFetchRequest<NSManagedObject>,
                    relationship: String,
                    blobIDField: String
                    // swiftformat:disable:next wrapMultilineConditionalAssignment
                )? = switch message {
                case is AudioMessageEntity:
                    try? getMediaMetaInfo(messageType: AudioMessageEntity.self)
                case is FileMessageEntity:
                    try? getMediaMetaInfo(messageType: FileMessageEntity.self)
                case is ImageMessageEntity:
                    try? getMediaMetaInfo(messageType: ImageMessageEntity.self)
                case is VideoMessageEntity:
                    try? getMediaMetaInfo(messageType: VideoMessageEntity.self)
                default:
                    nil
                }

                if let relationship = mediaMetaInfo?.relationship,
                   let message = message as? NSManagedObject {
                    
                    var mediaIDs = [NSManagedObjectID]()
                    mediaIDs.append(contentsOf: message.objectIDs(forRelationshipNamed: relationship))

                    for mediaID in mediaIDs {
                        if let mediaObj = try? objCnx.existingObject(with: mediaID) {
                            objCnx.refresh(mediaObj, mergeChanges: true)
                        }
                    }
                }

                // Get external file name
                if let filename = blobData.blobExternalFilename {
                    externalFilenames.append(filename)
                }
                if includeThumbnail,
                   let thumbnailname = blobData.blobThumbnailExternalFilename {
                    
                    externalFilenames.append(thumbnailname)
                }
            }
        }
        return externalFilenames
    }

    /// Delete external files.
    ///
    /// - Parameters:
    ///    - list: List of filenames to delete
    private func deleteExternalFiles(list: [String]) {
        // It seams, since iOS version 15 is this not necessary anymore. Core Data deleting now the external files.
        // If we do that yet Core Data crashs with: "External data reference can't find underlying file."
        // swiftformat:disable:next all
        return;

        if !list.isEmpty {
            for filename in list {
                let fileURL = FileUtility.shared.appDataDirectory?
                    .appendingPathComponent("\(EntityDestroyer.externalDataPath)/\(filename)")
                FileUtility.shared.delete(at: fileURL)
            }
        }
    }
    
    /// Delete all kind of messages of this contact.
    ///
    /// - Parameters:
    ///    - contact: Delete all messages of this contact
    ///
    /// - Returns:
    ///    Count of deleted messages
    private func deleteMessages(for contact: ContactEntity) -> Int {
        let fetchMessages = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
        fetchMessages.predicate = NSPredicate(format: "sender = %@", contact)
        return deleteMessages(with: fetchMessages)
    }
    
    /// Delete all kind of messages of the fetch request.
    ///
    /// - Parameters:
    ///    - fetchRequest: NSFetchRequest<NSFetchRequestResult>
    ///
    /// - Returns:
    ///    Count of deleted messages
    private func deleteMessages(with fetchRequest: NSFetchRequest<NSFetchRequestResult>) -> Int {
        do {
            fetchRequest.resultType = NSFetchRequestResultType.managedObjectIDResultType
            guard let objectIDs = try objCnx.fetch(fetchRequest) as? [NSManagedObjectID], !objectIDs.isEmpty else {
                return 0
            }

            let deleteFilenames = getExternalFilenames(ofObjectIDs: objectIDs, includeThumbnail: true)

            nullifyConversationLastMessage(forObjectIDs: objectIDs)

            // With a batch delete will sometimes the external file of a file message not deleted immediately. If the
            // external file is remaining, than the only way to delete this is in Settings - Advanced - Delete Orphaned
            // Files
            let batch = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            batch.resultType = NSBatchDeleteRequestResultType.resultTypeObjectIDs
            let deleteResult = try objCnx.execute(batch) as? NSBatchDeleteResult
            if let deletedIDs = deleteResult?.result as? [NSManagedObjectID], !deletedIDs.isEmpty {
                refreshDatabaseMainAndDirectContexts(for: deletedIDs)

                deleteExternalFiles(list: deleteFilenames)

                return deletedIDs.count
            }
            
            return 0
        }
        catch let error as NSError {
            DDLogError("Could not delete messages. \(error), \(error.userInfo)")
        }

        return 0
    }

    private func nullifyConversationLastMessage(for messages: [BaseMessage]) {
        guard !messages.isEmpty else {
            return
        }

        nullifyConversationLastMessage(forObjectIDs: messages.map(\.objectID))
    }

    private func nullifyConversationLastMessage(forObjectIDs: [NSManagedObjectID]) {
        guard !forObjectIDs.isEmpty else {
            return
        }

        do {
            try objCnx.performAndWait {
                let fetchConversations = NSFetchRequest<NSFetchRequestResult>(entityName: "Conversation")
                fetchConversations.predicate = NSPredicate(format: "lastMessage IN %@", forObjectIDs)

                if let conversations = try fetchConversations.execute() as? [ConversationEntity],
                   !conversations.isEmpty {
                    for conversation in conversations {
                        conversation.lastMessage = nil
                    }

                    try self.objCnx.save()
                }
            }
        }
        catch {
            DDLogError("Failed to nullify `Conversation.lastMessage`: \(error)")
        }
    }

    /// Merge deleted objects in private (background) context to main and direct database contexts.
    /// - Parameter deletedIDs: Array with object ID of deleted objects
    private func refreshDatabaseMainAndDirectContexts(for deletedIDs: [NSManagedObjectID]) {
        guard !deletedIDs.isEmpty,
              (objCnx as NSManagedObjectContext).concurrencyType != .mainQueueConcurrencyType,
              let databaseContext = DatabaseManager.db().getDatabaseContext() else {
            return
        }

        var contexts = [databaseContext.main]
        if let directContexts = databaseContext.directContexts {
            contexts.append(contentsOf: directContexts)
        }

        // Merge the deletions into the app's managed object context.
        NSManagedObjectContext.mergeChanges(
            fromRemoteContextSave: [NSDeletedObjectsKey: deletedIDs],
            into: contexts
        )
    }
}
