//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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
    ///     - myIdenityStore: To fetch group conversation and  contact display name
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
    
    @objc public func conversation(forContact: Contact, createIfNotExisting: Bool) -> Conversation? {
        let conversation = entityFetcher.conversation(forIdentity: forContact.identity)
        
        if createIfNotExisting, conversation == nil,
           let conversation = entityCreator.conversation() {
            conversation.contact = forContact
            if !ThreemaUtilityObjC.hideThreemaTypeIcon(for: forContact) {
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
    public func markMessageAsSent(_ messageID: Data) {
        performSyncBlockAndSafe {
            if let dbMsg = self.entityFetcher.ownMessage(with: messageID) {
                if let sent = Bool(exactly: dbMsg.sent), !sent {
                    dbMsg.sent = true
                }
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
            DDLogVerbose(String(format: "inserted objects: %@", dbContext.current.insertedObjects))
            DDLogVerbose(String(format: "updated objects: %@", dbContext.current.updatedObjects))
            DDLogVerbose(String(format: "deleted objects: %@", dbContext.current.deletedObjects))
        #endif
        
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
