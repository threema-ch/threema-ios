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

/// Wraps the BlobManager to make it usable in Obj-C code, should only be used when new chat view is active
@objc public class BlobManagerObjcWrapper: NSObject {
    
    /// Creates a message for a given URLSenderItem and syncs the blobs of it
    /// - Parameters:
    ///   - item: URLSenderItem
    ///   - conversation: Conversation where message is sent
    ///   - correlationID: Optional String
    ///   - webRequestID: Optional String
    @objc public func createMessageAndSyncBlobs(
        for item: URLSenderItem,
        in conversation: Conversation?,
        correlationID: String?,
        webRequestID: String?
    ) {
        Task {
            do {
                guard let objectID = conversation?.objectID else {
                    NotificationPresenterWrapper.shared.present(type: .sendingError)
                    DDLogError("ObjectID of conversation to create blob message for was nil.")
                    return
                }
                
                try await BlobManager.shared.createMessageAndSyncBlobs(
                    for: item,
                    in: objectID,
                    correlationID: correlationID,
                    webRequestID: webRequestID
                )
            }
            catch {
                DDLogError("Could not create message and sync blobs due to: \(error)")
            }
        }
    }
    
    /// Start up- or download of blobs in passed object
    /// - Parameter messageID: NSManagedObjectID of message to be synced
    @objc public func syncBlobs(for messageID: NSManagedObjectID?, onCompletion: @escaping () -> Void) {
        Task {
     
            guard let messageID else {
                DDLogError("ObjectID of conversation to create blob message for was nil.")
                return
            }
            
            await BlobManager.shared.syncBlobs(for: messageID)
            Task { @MainActor in
                onCompletion()
            }
        }
    }
    
    /// Start up- or download of blobs in passed object, use to start automatic downloads
    /// - Parameter messageID: NSManagedObjectID of message to be synced
    @objc public func autoSyncBlobs(for messageID: NSManagedObjectID?) {
        Task {
     
            guard let messageID else {
                DDLogError("ObjectID of conversation to create blob message for was nil.")
                return
            }
            
            await BlobManager.shared.autoSyncBlobs(for: messageID)
        }
    }
 
    /// Checks the non isolated state tracker if there are any active blob syncs. Might not return the correct value since it is not handled in actor isolation.
    /// - Returns: `True` if there are probably some active syncs.
    @objc public func hasActiveSyncs() -> Bool {
        BlobManager.shared.hasActiveSyncs()
    }
}
