//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2020 Threema GmbH
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

@objc public class EntityDestroyer: NSObject {
    
    private let objCnx: NSManagedObjectContext
    private let logger: ValidationLogger
    
    @objc public required init(managedObjectContext: NSManagedObjectContext) {
        self.objCnx = managedObjectContext
        self.logger = ValidationLogger.shared()
    }
    
    /**
     Delete media files of audio, file, image and video messages.
     
     - Parameters:
        - olderThan: All message older than that date will be deleted
     
     - Returns:
        Count of deleted media files
     */
    public func deleteMedias(olderThan: Date?) -> Int? {
        var deletedObjects: Int = 0
        if let count = self.deleteMediasOf(messageType: AudioMessage.self, olderThan: olderThan) {
            deletedObjects += count
        }
        if let count = self.deleteMediasOf(messageType: FileMessage.self, olderThan: olderThan) {
            deletedObjects += count
        }
        if let count = self.deleteMediasOf(messageType: ImageMessage.self, olderThan: olderThan) {
            deletedObjects += count
        }
        if let count = self.deleteMediasOf(messageType: VideoMessage.self, olderThan: olderThan) {
            deletedObjects += count
        }
        
        return deletedObjects
    }
    
    func deleteMediasOf<T :BaseMessage>(messageType: T.Type, olderThan: Date?) -> Int? {
        guard messageType is AudioMessage.Type || messageType is FileMessage.Type || messageType is ImageMessage.Type || messageType is VideoMessage.Type else {
            return nil
        }
        
        do {
            let mediaMetaInfo = try getMediaMetaInfo(messageType: messageType)

            if let olderThan = olderThan {
                mediaMetaInfo.fetchMessages.predicate = NSPredicate(format: "%K != nil AND date < %@", mediaMetaInfo.relationship, olderThan as NSDate)
            }
            else {
                mediaMetaInfo.fetchMessages.predicate = NSPredicate(format: "%K != nil", mediaMetaInfo.relationship)
            }
            
            let messages = try self.objCnx.fetch(mediaMetaInfo.fetchMessages)
            
            var deleteMediaIDs: [NSManagedObjectID] = []
            var updateMessageIDs: [NSManagedObjectID] = []

            for message in messages {
                if let message = message as? T {
                    deleteMediaIDs.append(contentsOf: message.objectIDs(forRelationshipNamed: mediaMetaInfo.relationship))
                    updateMessageIDs.append(message.objectID)
                }
            }
            
            let deleteFilenames = self.getExternalFilenames(ofMessages: messages, includeThumbnail: false)

            if deleteMediaIDs.count > 0 {
                var changes = [AnyHashable : [NSManagedObjectID]]()

                // Delete medias
                let deleteMediaBatch = NSBatchDeleteRequest(objectIDs: deleteMediaIDs)
                deleteMediaBatch.resultType = .resultTypeObjectIDs
                let deleteMediaResult = try self.objCnx.execute(deleteMediaBatch) as? NSBatchDeleteResult
                if let deletedIDs = deleteMediaResult?.result as? [NSManagedObjectID] {
                    changes[NSDeletedObjectsKey] = deletedIDs
                }

                // Update blobIDs to nil (to prevent downloading blob again)
                if updateMessageIDs.count > 0 {
                    var updatedIDs: [NSManagedObjectID] = []
                    
                    for updateID in updateMessageIDs {
                        if let updateMessage = try self.objCnx.existingObject(with: updateID) as? T {
                            if updateMessage.value(forKey: mediaMetaInfo.blobIDField) != nil {
                                self.objCnx.performAndWait {
                                    updateMessage.setValue(nil, forKey: mediaMetaInfo.blobIDField)
                                    do {
                                        try self.objCnx.save()
                                        
                                        updatedIDs.append(updateID)
                                    }
                                    catch let error as NSError {
                                        self.logger.logString("Cloud not update message. \(error), \(error.userInfo)")
                                    }
                                }
                            }
                        }
                    }
                    changes[NSUpdatedObjectsKey] = updatedIDs
                }
                
                if changes.count > 0 {
                    let dbManager = DatabaseManager()
                    dbManager.refreshDirtyObjectIDs(changes, into:self.objCnx)
                }
                
                self.deleteExternalFiles(list: deleteFilenames)
            }
            
            return messages.count
        }
        catch let error as NSError {
            self.logger.logString("Could not delete medias. \(error), \(error.userInfo)")
        }
        
        return 0;
    }

    /**
     Delete all kind of messages.
     
     - Parameters:
        - olderThan: All message older than that date will be deleted
     
     - Returns:
        Count of deleted messages
    */
    public func deleteMessages(olderThan: Date?) -> Int? {
        do {
            let fetchMessages = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
            
            if let olderThan = olderThan {
                fetchMessages.predicate = NSPredicate(format: "date < %@", olderThan as NSDate)
            }

            let messages = try self.objCnx.fetch(fetchMessages)
            let deleteFilenames = self.getExternalFilenames(ofMessages: messages, includeThumbnail: true)
            
            let batch = NSBatchDeleteRequest(fetchRequest: fetchMessages)
            batch.resultType = NSBatchDeleteRequestResultType.resultTypeObjectIDs
            let deleteResult = try self.objCnx.execute(batch) as? NSBatchDeleteResult
            if let deletedIDs = deleteResult?.result as? [NSManagedObjectID] {
                let dbManager = DatabaseManager()
                dbManager.refreshDirtyObjectIDs([NSDeletedObjectsKey: deletedIDs], into:self.objCnx)
                
                self.deleteExternalFiles(list: deleteFilenames)
                
                return deletedIDs.count
            }

            return nil
        }
        catch let error as NSError {
            self.logger.logString("Could not delete messages. \(error), \(error.userInfo)")
        }
        
        return nil
    }

    /**
     Delete all kind of messages within conversation.
     
     - Parameters:
        - ofConversation: Delete all message of this conversation
     
     - Returns:
        Count of deleted messages
    */
    @objc public func deleteMessages(ofCoversation: Conversation) -> Int {
        do {
            let fetchMessages = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
            fetchMessages.predicate = NSPredicate(format: "conversation = %@", ofCoversation)
            
            let messages = try self.objCnx.fetch(fetchMessages)
            let deleteFilenames = self.getExternalFilenames(ofMessages: messages, includeThumbnail: true)
            
            let batch = NSBatchDeleteRequest(fetchRequest: fetchMessages)
            batch.resultType = NSBatchDeleteRequestResultType.resultTypeObjectIDs
            let deleteResult = try self.objCnx.execute(batch) as? NSBatchDeleteResult
            if let deletedIDs = deleteResult?.result as? [NSManagedObjectID] {
                let dbManager = DatabaseManager()
                dbManager.refreshDirtyObjectIDs([NSDeletedObjectsKey: deletedIDs], into:self.objCnx)
                
                self.deleteExternalFiles(list: deleteFilenames)
                
                return deletedIDs.count
            }
            
            return 0

        }
        catch let error as NSError {
            self.logger.logString("Could not delete messages. \(error), \(error.userInfo)")
        }

        return 0
    }
    
    /**
     Delete particular DB object.
     
     - Parameters:
        - object: object to delete
    */
    @objc public func deleteObject(object: NSManagedObject) {
        if let conversation = object as? Conversation {
            let count = deleteMessages(ofCoversation: conversation)
            print("\(count) messages deleted from conversation")
        }

        let deleteFilenames = self.getExternalFilenames(ofMessages: [object], includeThumbnail: true)
        self.objCnx.delete(object)
        self.deleteExternalFiles(list: deleteFilenames)
    }
    
    private func getMediaMetaInfo<T: Any>(messageType: T.Type) throws -> (fetchMessages: NSFetchRequest<NSManagedObject>, relationship: String, blobIDField: String) {
        
        var fetchMessages: NSFetchRequest<NSManagedObject>
        var relationship: String
        var blobIDField: String

        if messageType is AudioMessage.Type {
            fetchMessages = NSFetchRequest<NSManagedObject>(entityName: "AudioMessage")
            relationship = "audio"
            blobIDField = "audioBlobId"
        }
        else if messageType is FileMessage.Type {
            fetchMessages = NSFetchRequest<NSManagedObject>(entityName: "FileMessage")
            relationship = "data"
            blobIDField = "blobId"
        }
        else if messageType is ImageMessage.Type {
            fetchMessages = NSFetchRequest<NSManagedObject>(entityName: "ImageMessage")
            relationship = "image"
            blobIDField = "imageBlobId"
        }
        else if messageType is VideoMessage.Type {
            fetchMessages = NSFetchRequest<NSManagedObject>(entityName: "VideoMessage")
            relationship = "video"
            blobIDField = "videoBlobId"
        }
        else {
            fatalError("message type not defined")
        }
        
        return (fetchMessages, relationship, blobIDField)
    }
    
    /**
     List names of external files.
     
     - Parameters:
        - ofMessages: Check messages to external data files
        - includeThumbnail: Check messages to external thumbnail files
     
     - Returns: Names of external files
    */
    private func getExternalFilenames(ofMessages: [Any], includeThumbnail: Bool) -> [String] {
        var externalFilenames: [String] = []
        for message in ofMessages {
            if let externalStorageInfo = message as? ExternalStorageInfo {
                
                // Refreshing media objects, otherwise external filenames can not be evaluated for new messages
                let mediaMetaInfo: (fetchMessages: NSFetchRequest<NSManagedObject>, relationship: String, blobIDField: String)?
                switch message {
                case is AudioMessage:
                    mediaMetaInfo = try? getMediaMetaInfo(messageType: AudioMessage.self)
                case is FileMessage:
                    mediaMetaInfo = try? getMediaMetaInfo(messageType: FileMessage.self)
                case is ImageMessage:
                    mediaMetaInfo = try? getMediaMetaInfo(messageType: ImageMessage.self)
                case is VideoMessage:
                    mediaMetaInfo = try? getMediaMetaInfo(messageType: VideoMessage.self)
                default:
                    mediaMetaInfo = nil
                }

                if let relationship = mediaMetaInfo?.relationship,
                    let message = message as? NSManagedObject {
                    
                    var mediaIDs = [NSManagedObjectID]()
                    mediaIDs.append(contentsOf: message.objectIDs(forRelationshipNamed: relationship))

                    for mediaId in mediaIDs {
                        if let mediaObj = try? objCnx.existingObject(with: mediaId) {
                            objCnx.refresh(mediaObj, mergeChanges: true)
                        }
                    }
                }

                // Get external file name
                if let filename = externalStorageInfo.getFilename() {
                    externalFilenames.append(filename)
                }
                if includeThumbnail,
                    let thumbnailname = externalStorageInfo.getThumbnailname?() {
                    
                    externalFilenames.append(thumbnailname)
                }
            }
        }
        return externalFilenames;
    }

    /**
     Delete external files.
     
     - Parameters:
        - list: List of filenames to delete
    */
    private func deleteExternalFiles(list: [String]) {
        if list.count > 0 {
            for filename in list {
                let fileUrl = FileUtility.appDataDirectory?.appendingPathComponent(".ThreemaData_SUPPORT/_EXTERNAL_DATA/\(filename)")
                FileUtility.delete(fileUrl: fileUrl)
            }
        }
    }
}
