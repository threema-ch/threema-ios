//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

public class BlobMessageSender {
    
    /// Global blob message sender
    ///
    /// Use this if you're not testing the sender
    public static let shared = BlobMessageSender()
    
    let taskManager: TaskManager
    let businessInjector: BusinessInjector
    let groupManager: GroupManagerProtocol
    
    // MARK: - Lifecycle
    
    init(
        businessInjector: BusinessInjector = BusinessInjector(),
        taskManager: TaskManager = TaskManager()
    ) {
        self.businessInjector = businessInjector
        self.taskManager = taskManager
        self.groupManager = businessInjector.groupManager
    }
    
    // MARK: - Public Functions
    
    public func sendBlobMessage(with objectID: NSManagedObjectID) async throws {
                
        // Concurrency Loading
        var fileMessage: FileMessage?
        var conversation: Conversation!
        var group: Group?
        
        businessInjector.entityManager.performBlockAndWait {
            fileMessage = self.businessInjector.entityManager.entityFetcher
                .existingObject(with: objectID) as? FileMessage
            
            if let message = fileMessage {
                conversation = message.conversation
                group = self.businessInjector.groupManager.getGroup(conversation: conversation)
            }
        }
        
        guard let fileMessage else {
            DDLogError("[BlobMessageSender]: Unable to load message as FileMessage for object ID: \(objectID)")
            throw BlobManagerError.sendingFailed
        }
        
        guard isMessageReadyToSend(with: objectID) else {
            DDLogError(
                "[BlobMessageSender]: State of BlobData for file message with object ID: \(objectID) does not allow sending"
            )
            throw BlobManagerError.sendingFailed
        }

        businessInjector.entityManager.performBlockAndWait {
    
            let taskDefinition = TaskDefinitionSendBaseMessage(
                message: fileMessage,
                group: group,
                sendContactProfilePicture: true
            )
            self.taskManager.add(taskDefinition: taskDefinition)
        }
    }
    
    // MARK: - Private Functions

    private func isMessageReadyToSend(with objectID: NSManagedObjectID) -> Bool {
        // Due to the business injector entity manager having outdated info about the object belonging to the ID passed
        // in here, we create a new one.
        let entityManager = EntityManager(withChildContextForBackgroundProcess: true)
        var isReady = false
        
        entityManager.performBlockAndWait {
            guard let fileMessage = entityManager.entityFetcher.existingObject(with: objectID) as? FileMessage else {
                return
            }
            
            guard fileMessage.blobIdentifier != nil,
                  fileMessage.blobProgress == nil else {
                return
            }
            
            if fileMessage.blobThumbnail != nil,
               fileMessage.blobThumbnailIdentifier == nil {
                return
            }
            
            // If we have a a blobID, and possibly a thumbnail and its ID, this means that the upload has succeeded
            // and just the sending of the message must have failed, so we reset the error and mark it as ready
            if fileMessage.blobError {
                entityManager.performSyncBlockAndSafe {
                    fileMessage.blobError = false
                }
            }
            
            isReady = true
        }
        
        return isReady
    }
}
