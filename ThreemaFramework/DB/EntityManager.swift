//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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

public class EntityManager: NSObject {
    
    private let dbContext: DatabaseContext
    
    @objc public let entityCreator: EntityCreator
    @objc public let entityFetcher: EntityFetcher
    @objc public let entityDestroyer: EntityDestroyer
    
    // MARK: - Lifecycle
    
    @objc override public convenience init() {
        self.init(myIdentityStore: MyIdentityStore.shared())
    }
    
    /// With DB main context.
    /// - Parameter myIdenityStore: To fetch group conversation and  contact display name
    public required init(myIdentityStore: MyIdentityStoreProtocol) {
        self.dbContext = DatabaseManager.db().getDatabaseContext()
        self.entityCreator = EntityCreator(dbContext.current)
        self.entityFetcher = EntityFetcher(dbContext.current, myIdentityStore: myIdentityStore)
        self.entityDestroyer = EntityDestroyer(managedObjectContext: dbContext.current)
        super.init()
    }

    /// With DB child context.
    /// - Parameter withChildContextForBackgroundProcess: Child context for background or main thread
    @objc public convenience init(withChildContextForBackgroundProcess: Bool) {
        self.init(
            withChildContextForBackgroundProcess: withChildContextForBackgroundProcess,
            myIdentityStore: MyIdentityStore.shared()
        )
    }
    
    /// With DB child context.
    /// - Parameters:
    ///     - withChildContextForBackgroundProcess: Child context for background or main thread
    ///     - myIdentityStore: To fetch group conversation and  contact display name
    public required init(withChildContextForBackgroundProcess: Bool, myIdentityStore: MyIdentityStoreProtocol) {
        self.dbContext = DatabaseManager.db()
            .getDatabaseContext(withChildContextforBackgroundProcess: withChildContextForBackgroundProcess)
        self.entityCreator = EntityCreator(dbContext.current)
        self.entityFetcher = EntityFetcher(dbContext.current, myIdentityStore: myIdentityStore)
        self.entityDestroyer = EntityDestroyer(managedObjectContext: dbContext.current)
        super.init()
    }
    
    @objc public convenience init(databaseContext: DatabaseContext) {
        self.init(databaseContext: databaseContext, myIdentityStore: MyIdentityStore.shared())
    }
    
    public init(databaseContext: DatabaseContext, myIdentityStore: MyIdentityStoreProtocol) {
        self.dbContext = databaseContext
        self.entityCreator = EntityCreator(dbContext.current)
        self.entityFetcher = EntityFetcher(dbContext.current, myIdentityStore: myIdentityStore)
        self.entityDestroyer = EntityDestroyer(managedObjectContext: dbContext.current)
        super.init()
    }
    
    // MARK: - General actions
    
    @objc public func performAsyncBlockAndSafe(_ block: (() -> Void)?) {
        // perform always runs on the correct queue for `current`
        dbContext.current.perform {
            block?()
            self.internalSave()
        }
    }
    
    @objc public func performSyncBlockAndSafe(_ block: (() -> Void)?) {
        dbContext.current.performAndWait {
            block?()
            internalSave()
        }
    }
    
    @objc public func performBlock(_ block: (() -> Void)?) {
        dbContext.current.perform {
            block?()
        }
    }
    
    @objc public func performBlockAndWait(_ block: (() -> Void)?) {
        dbContext.current.performAndWait {
            block?()
        }
    }
    
    @objc public func rollback() {
        dbContext.current.rollback()
    }
    
    // MARK: - Data access & creation helpers
    
    /// Convert URL serialized managed object ID to `NSManagedObjectID`
    /// - Parameter url: URL to convert
    /// - Returns: `NSManagedObjectID` if it was found in the persistent store
    public func managedObjectID(forURIRepresentation url: URL) -> NSManagedObjectID? {
        dbContext.current.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: url)
    }

    /// Check and repair database integrity at the moment just the relationship of `Conversation.lastMessage`.
    @objc public func repairDatabaseIntegrity() {
        performSyncBlockAndSafe {
            guard let conversations = self.entityFetcher.allConversations() as? [Conversation] else {
                return
            }

            for conversation in conversations {
                guard let lastMessage = conversation.lastMessage else {
                    continue
                }

                if let msgID = lastMessage.id {
                    if self.entityFetcher.message(with: msgID, conversation: conversation) == nil {
                        conversation.lastMessage = nil
                    }
                }
                else {
                    conversation.lastMessage = nil
                }
            }
        }
    }

    /// Check (on main thread and main DB context) is message nonce already in DB.
    ///
    /// This is useful during incoming message processing to check
    /// if a message is already processed to prevent race conditions
    /// between App and Notification Extension.
    ///
    /// - Parameter nonce: Message Nonce to check
    /// - Returns: True nonce found in DB
    func isMessageNonceAlreadyInDB(nonce: Data) -> Bool {
        var isProcessed = false

        let isNonceAlreadyInDB: (Data) -> Void = { nonce in
            let entityFetcherOnMain = EntityFetcher(self.dbContext.main, myIdentityStore: MyIdentityStore.shared())
            self.dbContext.main.performAndWait {
                isProcessed = entityFetcherOnMain?.isNonceAlreadyInDB(nonce: nonce) ?? false
            }
        }

        if Thread.isMainThread {
            isNonceAlreadyInDB(nonce)
        }
        else {
            DispatchQueue.main.sync {
                isNonceAlreadyInDB(nonce)
            }
        }
        return isProcessed
    }

    @objc public func conversation(forContact: Contact, createIfNotExisting: Bool) -> Conversation? {
        let conversation = entityFetcher.conversation(forIdentity: forContact.identity)

        if createIfNotExisting, conversation == nil,
           let conversation = entityCreator.conversation() {
            conversation.contact = forContact

            if forContact.isContactHidden {
                forContact.isContactHidden = false

                let mediatorSyncableContacts = MediatorSyncableContacts()
                mediatorSyncableContacts.updateAcquaintanceLevel(
                    identity: forContact.identity,
                    value: NSNumber(integerLiteral: ContactAcquaintanceLevel.direct.rawValue)
                )
                mediatorSyncableContacts.syncAsync()
            }

            if forContact.showOtherThreemaTypeIcon {
                // Add work info as first message
                let systemMessage = entityCreator.systemMessage(for: conversation)
                systemMessage?.type = NSNumber(value: kSystemMessageContactOtherAppInfo)
                systemMessage?.remoteSentDate = Date()
            }
            return conversation
        }

        return conversation
    }

    @objc public func conversation(for contactIdentity: String, createIfNotExisting: Bool) -> Conversation? {
        guard let contact = entityFetcher.contact(for: contactIdentity) else {
            return nil
        }
        return conversation(forContact: contact, createIfNotExisting: createIfNotExisting)
    }
    
    /// Set sent property of own message to true and save.
    ///
    /// - Parameter messageID: Message to set sent true
    /// - Parameter isLocal: Is the message NOT sent to the chat server?
    public func markMessageAsSent(_ messageID: Data, isLocal: Bool = false) {
        performSyncBlockAndSafe {
            if let dbMsg = self.entityFetcher.ownMessage(with: messageID), let sent = Bool(exactly: dbMsg.sent), !sent {
                dbMsg.sent = true
                dbMsg.sendFailed = false
                        
                // Only set remote sent date if it was actually sent to the chat server
                if !isLocal {
                    dbMsg.remoteSentDate = .now
                }
            }
        }
    }
    
    /// Set forward security mode of own message and save.
    ///
    /// - Parameter messageID: Message to set FS mode on
    /// - Parameter forwardSecurityMode: new mode
    public func setForwardSecurityMode(_ messageID: Data, forwardSecurityMode: ForwardSecurityMode) {
        performSyncBlockAndSafe {
            if let dbMsg = self.entityFetcher.ownMessage(with: messageID) {
                dbMsg.forwardSecurityMode = forwardSecurityMode.rawValue as NSNumber
            }
        }
    }

    // Refresh all NSManagedObject on current context.
    @objc public func refreshAll() {
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
        guard let object = object else {
            return
        }
        
        performBlockAndWait {
            self.dbContext.current.refresh(object, mergeChanges: mergeChanges)
        }
    }
}
    
// MARK: Private functions

private extension EntityManager {
    private func internalSave() {
        guard dbContext.current.hasChanges else {
            return
        }
        
        // Fixes Crash when swipe-deleting Conversation on iOS15b8
        #if DEBUG
            DDLogVerbose("inserted objects: \(dbContext.current.insertedObjects)")
            DDLogVerbose("updated objects: \(dbContext.current.updatedObjects)")
            DDLogVerbose("deleted objects: \(dbContext.current.deletedObjects)")
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
            ErrorHandler.abortWithError(error)
        }
        
        if success {
            if dbContext.current.parent != nil {
                // Save parent context (changes were pushed by save in child context)
                dbContext.main.performAndWait {
                    do {
                        try self.dbContext.main.save()
                    }
                    catch {
                        DDLogError("Error saving main context: \(error)")
                        ErrorHandler.abortWithError(error)
                    }
                }
            }
        }
    }
}
