//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2023 Threema GmbH
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
    
    @objc public required init(managedObjectContext: TMAManagedObjectContext) {
        self.objCnx = managedObjectContext
    }
    
    // MARK: - Public methods
    
    /// Delete media files of audio, file, image and video messages.
    ///
    /// - Parameters:
    ///   - olderThan: All message older than that date will be deleted
    ///   - conversation: Conversation
    /// - Returns:
    ///   Count of deleted media files
    public func deleteMedias(olderThan: Date?, for conversationID: NSManagedObjectID?) async -> Int? {
        await existingObjectPerform(for: conversationID) {
            self.deleteMedias(olderThan: olderThan, for: $0)
        }
    }
    
    /// Delete media files of audio, file, image and video messages.
    ///
    /// - Parameters:
    ///   - olderThan: All message older than that date will be deleted
    ///   - conversation: Conversation
    /// - Returns:
    ///   Count of deleted media files
    public func deleteMedias(olderThan: Date?, for conversation: Conversation? = nil) -> Int? {
        var deletedObjects = 0
        var mediaMessageTypes = [
            AudioMessageEntity.self,
            FileMessageEntity.self,
            ImageMessageEntity.self,
            VideoMessageEntity.self,
        ]
        mediaMessageTypes.forEach {
            if let count = deleteMediasOf(
                messageType: $0,
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
        conversation: Conversation? = nil
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
        guard message.isRemoteDeletable else {
            return
        }

        // Just delete media for message types like `AudioMessageEntity`, `FileMessageEntity`, `ImageMessageEntity` and
        // `VideoMessageEntity`
        try deleteMedias(of: [message], messageType: type(of: message))

        if let message = message as? LocationMessage {
            message.latitude = 0
            message.longitude = 0
            message.accuracy = 0
            message.reverseGeocodingResult = ""
            message.poiAddress = nil
            message.poiName = nil
        }
        else if let message = message as? TextMessage {
            message.text = ""
        }
        else if let message = message as? FileMessageEntity {
            deleteThumbnail(for: message)

            message.thumbnail = nil
            message.mimeType = ""
            message.fileName = ""
            message.caption = ""
            message.json = ""
        }
        else if let message = message as? ImageMessageEntity {
            deleteThumbnail(for: message)

            message.thumbnail = nil
        }
        else if let message = message as? VideoMessageEntity {
            deleteThumbnail(for: message)

            message.duration = 0
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
                            let imageData = object as? ImageData,
                            let defaultThumbnail = UIImage(named: "threema.video.fill") {

                        imageData.data = defaultThumbnail.jpegData(compressionQuality: kJPEGCompressionQualityLow)
                        imageData.width = NSNumber(floatLiteral: defaultThumbnail.size.width)
                        imageData.height = NSNumber(floatLiteral: defaultThumbnail.size.height)
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
    public func deleteMessages(olderThan: Date?, for conversation: Conversation? = nil) -> Int? {
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
    ///    - conversation: Conversation
    ///
    /// - Returns:
    ///    Count of deleted messages
    public func deleteMessages(olderThan: Date?, for conversationID: NSManagedObjectID?) async -> Int? {
        await existingObjectPerform(for: conversationID) {
            self.deleteMessages(olderThan: olderThan, for: $0)
        }
    }
    
    /// Delete all kind of messages.
    ///
    /// - Parameters:
    ///    - olderThan: All message older than that date will be deleted
    ///    - conversations: Conversation
    public func deleteMessagesForMessageRetention(olderThan: Date, for conversationsIDs: [NSManagedObjectID]) async {
        await objCnx.perform {
            let conversations = conversationsIDs
                .compactMap { try? self.objCnx.existingObject(with: $0) as? Conversation }
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
                .compactMap { try? self.objCnx.existingObject(with: $0) as? Conversation }
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
    ///    - conversation: Delete all message of this conversation
    ///
    /// - Returns:
    ///    Count of deleted messages
    @objc public func deleteMessages(of conversation: Conversation) -> Int {
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
    
    /// Delete particular DB object.
    ///
    /// - Parameters:
    ///    - object: object to delete
    @objc public func deleteObject(object: NSManagedObject) {
        var shouldUpdateConversationContent = false
        if let conversation = object as? Conversation {
            let count = deleteMessages(of: conversation)
            DDLogDebug("\(count) messages deleted from conversation")
            
            MessageDraftStore.deleteDraft(for: conversation)
        }
        else if let contact = object as? ContactEntity {
            // Remove all conversations and messages for this contact
            if let conversations = contact.conversations {
                for genericConversation in conversations {
                    guard let conversation = genericConversation as? Conversation else {
                        fatalError("Can't delete a conversation of a contact, because it's not a conversation object")
                        continue
                    }
                    deleteObject(object: conversation)
                }
            }
            
            // check all group conversations to delete messages from this contact
            let count = deleteMessages(for: contact)
            DDLogDebug("\(count) group messages deleted from contact")

            if count > 0 {
                shouldUpdateConversationContent = true
            }
        }
        else if let distributionList = object as? DistributionListEntity,
                let conversation = distributionList.conversation {
            deleteObject(object: conversation)
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

    /// Get orphaned external files.
    ///
    /// - Returns: List of orphaned files, count of files in DB
    public func orphanedExternalFiles() -> (orphanedFiles: [String]?, totalFilesCount: Int) {
        
        // Load all external filenames
        if let files = FileUtility
            .dir(pathURL: FileUtility.appDataDirectory?.appendingPathComponent("\(EntityDestroyer.externalDataPath)/")),
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
                    deleteObject(object: fetchedCall)
                }
            }
        }
        catch let error as NSError {
            DDLogError("Could not delete calls cache. \(error), \(error.userInfo)")
        }
    }
    
    // MARK: - Private helper methods
    
    /// Asynchronously performs a block with an existing managed object of type `TMAManagedObject` if available.
    ///
    /// - Parameters:
    ///   - id: The `NSManagedObjectID` of the object to fetch.
    ///   - block: The block to execute with the fetched object. The block receives an optional `TMAManagedObject`.
    /// - Returns: The result of the block of type `R`.
    private func existingObjectPerform<T: TMAManagedObject, Result>(
        for id: NSManagedObjectID?,
        with block: @escaping (T?) -> (Result)
    ) async -> Result {
        await objCnx.perform {
            guard let id, let object = try? self.objCnx.existingObject(with: id) as? T else {
                return block(nil)
            }
            return block(object)
        }
    }
    
    /// Used to Delete the Messages according to the Retention Policy.
    /// Currently all but Open Polls are affected.
    ///
    /// - Parameter fetchRequest: fetchRequest to be used to fetch the messages
    private func messageRetentionDelete(with fetchRequest: NSFetchRequest<NSFetchRequestResult>) {
        do {
            try Task.checkCancellation()

            let messages = try (objCnx.fetch(fetchRequest)) as? [BaseMessage] ?? []
            // Currently we want to keep open Ballots excluded from deletion
            let filtered = messages.compactMap { ($0 as? BallotMessage)?.ballot?.isClosed() ?? true ? $0 : nil }
            
            guard !filtered.isEmpty else {
                return
            }
            
            nullifyConversationLastMessage(for: filtered)
            
            let batch = NSBatchDeleteRequest(objectIDs: filtered.map(\.objectID))
            batch.resultType = .resultTypeObjectIDs
            try Task.checkCancellation()
            
            if let deleteResult = try objCnx.execute(batch) as? NSBatchDeleteResult,
               let deletedIDs = deleteResult.result as? [NSManagedObjectID], !deletedIDs.isEmpty {
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
                )?
                switch message {
                case is AudioMessageEntity:
                    mediaMetaInfo = try? getMediaMetaInfo(messageType: AudioMessageEntity.self)
                case is FileMessageEntity:
                    mediaMetaInfo = try? getMediaMetaInfo(messageType: FileMessageEntity.self)
                case is ImageMessageEntity:
                    mediaMetaInfo = try? getMediaMetaInfo(messageType: ImageMessageEntity.self)
                case is VideoMessageEntity:
                    mediaMetaInfo = try? getMediaMetaInfo(messageType: VideoMessageEntity.self)
                default:
                    mediaMetaInfo = nil
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
                let fileURL = FileUtility.appDataDirectory?
                    .appendingPathComponent("\(EntityDestroyer.externalDataPath)/\(filename)")
                FileUtility.delete(at: fileURL)
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
            let messages = try objCnx.fetch(fetchRequest)
            let deleteFilenames = getExternalFilenames(ofMessages: messages, includeThumbnail: true)

            if let messages = messages as? [BaseMessage] {
                nullifyConversationLastMessage(for: messages)
            }
            
            let batch = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            batch.resultType = NSBatchDeleteRequestResultType.resultTypeObjectIDs
            let deleteResult = try objCnx.execute(batch) as? NSBatchDeleteResult
            if let deletedIDs = deleteResult?.result as? [NSManagedObjectID], !deletedIDs.isEmpty {
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

        do {
            try objCnx.performAndWait {
                let fetchConversations = NSFetchRequest<NSFetchRequestResult>(entityName: "Conversation")
                fetchConversations.predicate = NSPredicate(format: "lastMessage IN %@", messages)

                if let conversations = try fetchConversations.execute() as? [Conversation], !conversations.isEmpty {
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
}
