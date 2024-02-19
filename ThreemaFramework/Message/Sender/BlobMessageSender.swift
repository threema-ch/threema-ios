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
import ThreemaEssentials

final class BlobMessageSender {
    
    let taskManager: TaskManagerProtocol
    let businessInjector: BusinessInjectorProtocol
    
    // MARK: - Lifecycle
    
    init(
        businessInjector: BusinessInjectorProtocol = BusinessInjector(),
        taskManager: TaskManagerProtocol = TaskManager()
    ) {
        self.businessInjector = businessInjector
        self.taskManager = taskManager
    }
    
    // MARK: - Public Functions
    
    func sendBlobMessage(
        with objectID: NSManagedObjectID,
        to receivers: MessageSenderReceivers = .all
    ) async throws {
                
        // Concurrency Loading
        let (messageID, receiverIdentity, group) = businessInjector.entityManager.performAndWait {
            var messageID: Data?
            var receiverIdentity: ThreemaIdentity?
            var group: Group?

            if let message = self.businessInjector.entityManager.entityFetcher
                .existingObject(with: objectID) as? FileMessage {
                messageID = message.id

                group = self.businessInjector.groupManager.getGroup(conversation: message.conversation)
                if group == nil {
                    receiverIdentity = message.conversation.contact?.threemaIdentity
                }
            }

            return (messageID, receiverIdentity, group)
        }
        
        guard let messageID else {
            DDLogError("[BlobMessageSender]: Unable to load message as FileMessage for object ID: \(objectID)")
            throw MessageSenderError.sendingFailed
        }
        
        guard isMessageReadyToSend(with: objectID) else {
            DDLogError(
                "[BlobMessageSender]: State of BlobData for file message with object ID: \(objectID) does not allow sending"
            )
            throw MessageSenderError.sendingFailed
        }

        if let group {
            let receiverIdentities: [ThreemaIdentity]
            switch receivers {
            case .all:
                receiverIdentities = group.members.map(\.identity)
            case let .groupMembers(identities):
                receiverIdentities = identities
            }
            
            let taskDefinition = TaskDefinitionSendBaseMessage(
                messageID: messageID,
                group: group,
                receivers: receiverIdentities,
                sendContactProfilePicture: false
            )
            
            taskManager.add(taskDefinition: taskDefinition)
        }
        else if let receiverIdentity {
            let taskDefinition = TaskDefinitionSendBaseMessage(
                messageID: messageID,
                receiverIdentity: receiverIdentity.string,
                sendContactProfilePicture: false
            )
            
            taskManager.add(taskDefinition: taskDefinition)
        }
        else {
            DDLogError(
                "[BlobMessageSender] Unable to create task for blob message (objectID \(objectID)): Group and receiver identity are nil."
            )
            throw MessageSenderError.sendingFailed
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
