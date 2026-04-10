//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2025 Threema GmbH
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
import CoreData
import Foundation
import ThreemaEssentials
import ThreemaProtocols

public class EntityManager: NSObject {
    
    public let dbContext: DatabaseContext
    static let getOrCreateContactQueue = DispatchQueue(label: "ch.threema.EntityManager.getOrCreateContactQueue")
    public let getOrCreateMessageQueue = DispatchQueue(label: "ch.threema.EntityManager.getOrCreateMessageQueue")

    @objc public let entityCreator: EntityCreator
    @objc public let entityFetcher: EntityFetcher
    @objc public let entityDestroyer: EntityDestroyer
    
    let isRemoteSecretEnabled: Bool
    
    // MARK: - Lifecycle

    @objc init(databaseContext: DatabaseContext, isRemoteSecretEnabled: Bool) {
        self.dbContext = databaseContext
        self.entityCreator = EntityCreator(managedObjectContext: dbContext.current)
        self.entityFetcher = EntityFetcher(
            managedObjectContext: dbContext.current
        )
        self.entityDestroyer = EntityDestroyer(
            managedObjectContext: dbContext.current
        )
        
        self.isRemoteSecretEnabled = isRemoteSecretEnabled
        
        super.init()
    }
    
    // MARK: - General actions

    public var hasBackgroundChildContext: Bool {
        dbContext.current !== dbContext.main
    }

    public func isEqualWithCurrentContext(managedObjectContext: NSManagedObjectContext) -> Bool {
        dbContext.current === managedObjectContext
    }

    @available(*, deprecated, renamed: "performSave(_:)")
    @objc public func performAsyncBlockAndSafe(_ block: (() -> Void)?) {
        // perform always runs on the correct queue for `current`
        dbContext.current.perform {
            block?()
            try? self.internalSave()
        }
    }
    
    @available(*, deprecated, renamed: "performAndWaitSave(_:)")
    @objc public func performSyncBlockAndSafe(_ block: (() -> Void)?) {
        dbContext.current.performAndWait {
            block?()
            try? internalSave()
        }
    }
    
    @available(*, deprecated, renamed: "perform(_:)")
    @objc public func performBlock(_ block: (() -> Void)?) {
        dbContext.current.perform {
            block?()
        }
    }

    @available(*, deprecated, renamed: "performAndWait(_:)")
    @objc public func performBlockAndWait(_ block: (() -> Void)?) {
        dbContext.current.performAndWait {
            block?()
        }
    }
    
    @objc public func performAndWaitSave(_ block: @escaping () -> Void) {
        dbContext.current.performAndWait {
            block()
            try? internalSave()
        }
    }

    public func performAndWaitSave<T>(_ block: @escaping () throws -> T) rethrows -> T {
        try dbContext.current.performAndWait {
            let returnValue = try block()
            try self.internalSave()
            return returnValue
        }
    }

    public func performSave<T>(_ block: @escaping () throws -> T) async rethrows -> T {
        try await dbContext.current.perform(schedule: .immediate) {
            let returnValue = try block()
            try self.internalSave()
            return returnValue
        }
    }

    public func performAndWait<T>(_ block: @escaping () throws -> T) rethrows -> T {
        try dbContext.current.performAndWait {
            try block()
        }
    }

    public func perform<T>(_ block: @escaping () throws -> T) async rethrows -> T {
        try await dbContext.current.perform(schedule: .immediate) {
            try block()
        }
    }

    public func rollback() {
        dbContext.current.rollback()
    }
    
    public func fullRollback() {
        dbContext.current.rollback()
        dbContext.main.rollback()
    }
    
    // MARK: - Managed Object Context functions

    public var isMainDBContext: Bool {
        dbContext.main === dbContext.current
    }

    /// Convert URL serialized managed object ID to `NSManagedObjectID`
    /// - Parameter url: URL to convert
    /// - Returns: `NSManagedObjectID` if it was found in the persistent store
    public func managedObjectID(forURIRepresentation url: URL) -> NSManagedObjectID? {
        dbContext.current.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url)
    }

    // Refresh all NSManagedObject on current context.
    public func refreshAllObjects() {
        let stalenessInterval: TimeInterval = dbContext.current.stalenessInterval
        dbContext.current.stalenessInterval = 0.0
        dbContext.current.refreshAllObjects()
        dbContext.current.stalenessInterval = stalenessInterval
    }
    
    /// Refresh NSManagedObject on current context.
    ///
    /// - Parameter object: NSManagedObject
    /// - Parameter mergeChanges: Bool
    public func refresh(_ object: NSManagedObject?, mergeChanges: Bool) {
        guard let object else {
            return
        }
        
        performAndWait {
            let stalenessInterval: TimeInterval = self.dbContext.current.stalenessInterval
            self.dbContext.current.stalenessInterval = 0.0
            self.dbContext.current.refresh(object, mergeChanges: mergeChanges)
            self.dbContext.current.stalenessInterval = stalenessInterval
        }
    }
}

// MARK: - Data access & creation helpers, convenience functions

extension EntityManager {

    /// Check and repair database integrity at the moment just the relationship of `Conversation.lastMessage`.
    public func repairDatabaseIntegrity() {
        performAndWaitSave {
            guard let conversations = self.entityFetcher.conversationEntities() else {
                return
            }

            for conversation in conversations {
                guard let lastMessage = conversation.lastMessage else {
                    continue
                }

                if self.entityFetcher.message(with: lastMessage.id, in: conversation) == nil {
                    conversation.lastMessage = nil
                }
            }
        }
    }

    /// Remove contact entities
    /// Assumption: the contacts have no messages and no conversations
    public func cleanupUnusedContacts(_ contacts: [ContactEntity]) {
        performAndWaitSave {
            for contact in contacts {
                self.dbContext.current.delete(contact)
            }
        }
    }

    /// Check (on main thread and main DB context) is message nonce already in DB.
    ///
    /// This is useful during incoming message processing to check
    /// if a message is already processed to prevent race conditions
    /// between App and Notification Extension.
    ///
    /// - Parameter hashedNonce: Hashed Message Nonce to check
    /// - Returns: True nonce found in DB
    public func isMessageNonceAlreadyInDB(_ hashedNonce: Data) -> Bool {
        var isProcessed = false

        let isNonceAlreadyInDB: (Data) -> Void = { _ in
            let entityFetcherOnMain = EntityFetcher(
                managedObjectContext: self.dbContext.main
            )

            self.dbContext.main.performAndWait {
                isProcessed = entityFetcherOnMain.isNonceEntityAlreadyInDB(hashedNonce)
            }
        }

        if Thread.isMainThread {
            isNonceAlreadyInDB(hashedNonce)
        }
        else {
            DispatchQueue.main.sync {
                isNonceAlreadyInDB(hashedNonce)
            }
        }
        return isProcessed
    }

    /// Set sent and sent date of outgoing message.
    ///
    /// - Parameters:
    /// - messageID: ID of message that was sent
    /// - conversation: Conversation of the message
    /// - sentAt: Sent date is reflected at or now if message was not reflected
    /// - isLocal: True means message was NOT sent to the chat server
    public func markMessageAsSent(
        _ messageID: Data,
        in conversation: ConversationEntity,
        sentAt: Date = .now,
        isLocal: Bool = false
    ) {
        performAndWaitSave {
            if let dbMsg = self.entityFetcher.message(with: messageID, in: conversation, isOwn: true),
               let sent = Bool(exactly: dbMsg.sent), !sent {
                dbMsg.sent = true
                dbMsg.sendFailed = false

                // Only set remote sent date if it was actually sent to the chat server
                if !isLocal {
                    dbMsg.remoteSentDate = sentAt
                }
            }
        }
    }

    /// Set forward security mode of own message and save.
    ///
    /// - Parameters:
    /// - messageID: Message to set FS mode on
    /// - conversation: Conversation of the message
    /// - forwardSecurityMode: new mode
    public func setForwardSecurityMode(
        _ messageID: Data,
        in conversation: ConversationEntity,
        forwardSecurityMode: BaseMessageEntity.ForwardSecurityMode
    ) {
        performAndWaitSave {
            guard let dbMsg = self.entityFetcher.message(with: messageID, in: conversation, isOwn: true) else {
                // This might also be called for messages not stored in CD. Thus we don't log anything here.
                return
            }

            dbMsg.forwardSecurityMode = forwardSecurityMode.rawValue as NSNumber
        }
    }

    /// Remove contacts form rejected-by list of passed message
    ///
    /// This is normally only needed for group messages
    ///
    /// - Parameters:
    ///   - contactIDs: Threema ID strings of IDs to remove
    ///   - messageID: Message ID of message to remove receivers from
    ///   - conversation: Conversation the message is in
    public func removeContacts(
        with contactIDs: Set<String>,
        fromRejectedListOfMessageWith messageID: Data,
        in conversation: ConversationEntity
    ) {
        performAndWaitSave {
            guard let dbMsg = self.entityFetcher.message(with: messageID, in: conversation, isOwn: true) else {
                DDLogWarn("No own message to be found for \(messageID)")
                return
            }

            // Only remove all possible contacts if there are any rejected
            guard !(dbMsg.rejectedBy?.isEmpty ?? true) else {
                return
            }

            for contactID in contactIDs {
                // For example if your own ID happens to be in contactIDs the contact cannot be loaded
                guard let contact = self.entityFetcher.contactEntity(for: contactID) else {
                    continue
                }

                dbMsg.removeFromRejectedBy(contact)
            }
        }
    }
}

// MARK: - Private Functions

extension EntityManager {
    private func internalSave() throws {
        guard dbContext.current.hasChanges else {
            return
        }
        
        // Fixes Crash when swipe-deleting Conversation on iOS15b8
        #if DEBUG
            DDLogVerbose("inserted objects: \(dbContext.current.insertedObjects)")
            DDLogVerbose("updated objects: \(dbContext.current.updatedObjects)")
            // For deleted objects log only objectID, otherwise it crash when logging for a none optional field on
            // encrypted DB
            DDLogVerbose("deleted objects: \(dbContext.current.deletedObjects.map(\.objectID))")
        #endif
        
        // Workaround for temporary managed object IDs
        //
        // After creating a managed object it appears in the context it is created on with a temporary object ID
        // (indicated by the "t" at the beginning of the UUID of a printed object ID). This object ID stays temporary
        // until the object is saved to a persistent store. Thus when a child contexts is saved all new managed objects
        // appear with their temporary object ID in the parent context.
        // A fetched results controller (FRC) on a context picks this up and sends an update (e.g. the one used in the
        // new chat view) with the temporary object IDs if you use diffable DS. However, there is no snapshot update
        // when the temporary object ID is switched out for a permanent one unless you update and save the object one
        // more time. Depending on the implementation this leads to a crash due to an unknown (temporary) object ID in
        // the DS.
        //
        // Workaround: We prefetch the permanent object IDs of all inserted objects before every save. Note: Testing
        // showed that we have to do this also if there is no parent context to work as expected.
        //
        // This should be addressed on a lower level with IOS-2354. Probably by replacing child contexts by multiple
        // contexts accessing the same permanent store directly.
        //
        // Sources:
        // - https://developer.apple.com/forums/thread/692357?answerID=691521022#691521022
        // - https://stackoverflow.com/q/11336120
        do {
            try dbContext.current.obtainPermanentIDs(for: Array(dbContext.current.insertedObjects))
        }
        catch {
            DDLogWarn("Unable to obtain permanent ids: \(error)")
        }
        
        var success = false
        do {
            try dbContext.current.save()
            
            success = true
        }
        catch {
            DDLogError("Error saving current context: \(error)")

            if ProcessInfoHelper.isRunningForTests {
                throw error
            }

            NotificationCenter.default.post(
                name: DatabaseContext.errorWhileProcessingManagedObject,
                object: nil,
                userInfo: [DatabaseContext.errorKey: error]
            )
        }
        
        if success, dbContext.current.parent != nil {
            // Save parent context (changes were pushed by save in child context)
            do {
                try dbContext.main.performAndWait {
                    try self.dbContext.main.save()
                }
            }
            catch {
                DDLogError("Error saving main context: \(error)")

                if ProcessInfoHelper.isRunningForTests {
                    throw error
                }

                NotificationCenter.default.post(
                    name: DatabaseContext.errorWhileProcessingManagedObject,
                    object: nil,
                    userInfo: [DatabaseContext.errorKey: error]
                )
            }
        }
    }
}
