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
import ThreemaProtocols

public class EntityManager: NSObject {
    
    fileprivate let dbContext: DatabaseContext
    fileprivate let myIdentityStore: MyIdentityStoreProtocol

    fileprivate let getOrCreateMessageQueue = DispatchQueue(label: "ch.threema.EntityManager.getOrCreateMessageQueue")

    @objc public let entityCreator: EntityCreator
    @objc public let entityFetcher: EntityFetcher
    @objc public let entityDestroyer: EntityDestroyer
    
    // MARK: - Lifecycle
    
    @objc override public convenience init() {
        self.init(myIdentityStore: MyIdentityStore.shared())
    }
    
    /// With DB main context.
    /// - Parameter myIdentityStore: To fetch group conversation and  contact display name
    public required init(myIdentityStore: MyIdentityStoreProtocol) {
        self.dbContext = DatabaseManager.db().getDatabaseContext()
        self.myIdentityStore = myIdentityStore
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
        self.myIdentityStore = myIdentityStore
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
        self.myIdentityStore = myIdentityStore
        self.entityCreator = EntityCreator(dbContext.current)
        self.entityFetcher = EntityFetcher(dbContext.current, myIdentityStore: myIdentityStore)
        self.entityDestroyer = EntityDestroyer(managedObjectContext: dbContext.current)
        super.init()
    }
    
    // MARK: - General actions

    var hasBackgroundChildContext: Bool {
        dbContext.current !== dbContext.main
    }

    func isEqualWithCurrentContext(managedObjectContext: NSManagedObjectContext) -> Bool {
        dbContext.current === managedObjectContext
    }

    @available(*, deprecated, renamed: "performSave(_:)")
    @objc public func performAsyncBlockAndSafe(_ block: (() -> Void)?) {
        // perform always runs on the correct queue for `current`
        dbContext.current.perform {
            block?()
            self.internalSave()
        }
    }
    
    @available(*, deprecated, renamed: "performAndWaitSave(_:)")
    @objc public func performSyncBlockAndSafe(_ block: (() -> Void)?) {
        dbContext.current.performAndWait {
            block?()
            internalSave()
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
    
    public func performAndWaitSave<T>(_ block: @escaping () throws -> T) rethrows -> T {
        try dbContext.current.performAndWait {
            let returnValue = try block()
            self.internalSave()
            return returnValue
        }
    }

    public func performSave<T>(_ block: @escaping () throws -> T) async rethrows -> T {
        try await dbContext.current.perform(schedule: .immediate) {
            let returnValue = try block()
            self.internalSave()
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
    public func repairDatabaseIntegrity() {
        performAndWaitSave {
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
    /// - Parameter nonce: Message Nonce to check
    /// - Returns: True nonce found in DB
    func isMessageNonceAlreadyInDB(nonce: Data) -> Bool {
        var isProcessed = false

        let isNonceAlreadyInDB: (Data) -> Void = { nonce in
            let entityFetcherOnMain = EntityFetcher(self.dbContext.main, myIdentityStore: self.myIdentityStore)
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

    /// Set delivered and delivery date of incoming message.
    /// - Parameters:
    /// - abstractMessage: Incoming message
    /// - receivedAt: Receive date is reflected at or now if message was not reflected
    public func markMessageAsReceived(_ abstractMessage: AbstractMessage, receivedAt: Date = .now) {

        performAndWaitSave {
            var conversation: Conversation?

            if abstractMessage.flagGroupMessage() {
                guard let groupMessage = abstractMessage as? AbstractGroupMessage else {
                    DDLogError("Could not update message because it is not group message")
                    return
                }
                conversation = self.entityFetcher.conversation(
                    for: groupMessage.groupID,
                    creator: groupMessage.groupCreator
                )
            }
            else {
                conversation = self.entityFetcher.conversation(forIdentity: abstractMessage.fromIdentity)
            }

            guard let conversation else {
                DDLogError("Could not update message because we could not find the conversation")
                return
            }

            guard let msg = self.entityFetcher.message(
                with: abstractMessage.messageID,
                conversation: conversation
            ) else {
                DDLogWarn(
                    "Could not update message because we could not find the message ID \(abstractMessage.messageID?.hexString ?? "nil")"
                )
                return
            }

            msg.delivered = NSNumber(booleanLiteral: true)
            msg.deliveryDate = receivedAt
        }
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
        in conversation: Conversation,
        sentAt: Date = .now,
        isLocal: Bool = false
    ) {
        performAndWaitSave {
            if let dbMsg = self.entityFetcher.ownMessage(with: messageID, conversation: conversation),
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
        in conversation: Conversation,
        forwardSecurityMode: ForwardSecurityMode
    ) {
        performAndWaitSave {
            guard let dbMsg = self.entityFetcher.ownMessage(with: messageID, conversation: conversation) else {
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
    func removeContacts(
        with contactIDs: Set<String>,
        fromRejectedListOfMessageWith messageID: Data,
        in conversation: Conversation
    ) {
        performAndWaitSave {
            guard let dbMsg = self.entityFetcher.ownMessage(with: messageID, conversation: conversation) else {
                DDLogWarn("No own message to be found for \(messageID)")
                return
            }

            // Only remove all possible contacts if there are any rejected
            guard !(dbMsg.rejectedBy?.isEmpty ?? true) else {
                return
            }

            for contactID in contactIDs {
                // For example if your own ID happens to be in contactIDs the contact cannot be loaded
                guard let contact = self.entityFetcher.contact(for: contactID) else {
                    continue
                }

                dbMsg.removeRejectedBy(contact)
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
        guard let object else {
            return
        }
        
        performBlockAndWait {
            let stalenessInterval: TimeInterval = self.dbContext.current.stalenessInterval
            self.dbContext.current.stalenessInterval = 0.0
            self.dbContext.current.refresh(object, mergeChanges: mergeChanges)
            self.dbContext.current.stalenessInterval = stalenessInterval
        }
    }
}
    
// MARK: Private functions

extension EntityManager {
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

// MARK: Convenience functions to accessing multiple contexts (current and main)

extension EntityManager {
    enum EntityManagerError: Error {
        case incomingMessageSenderMyself, missingSender, missingConversation, wrongBaseMessageType,
             unknownAbstractMessage
    }

    @objc public func conversation(
        forContact contactEntity: ContactEntity,
        createIfNotExisting: Bool
    ) -> Conversation? {
        conversation(forContact: contactEntity, createIfNotExisting: createIfNotExisting, setLastUpdate: true)
    }
    
    public func conversation(
        forContact contactEntity: ContactEntity,
        createIfNotExisting: Bool,
        setLastUpdate: Bool = true
    ) -> Conversation? {
        let conversation = entityFetcher.conversation(forIdentity: contactEntity.identity)

        if createIfNotExisting, conversation == nil,
           let conversation = entityCreator.conversation(setLastUpdate) {
            conversation.contact = contactEntity

            if contactEntity.isContactHidden {
                contactEntity.isContactHidden = false

                let mediatorSyncableContacts = MediatorSyncableContacts()
                mediatorSyncableContacts.updateAcquaintanceLevel(
                    identity: contactEntity.identity,
                    value: NSNumber(integerLiteral: ContactAcquaintanceLevel.direct.rawValue)
                )
                mediatorSyncableContacts.syncAsync()
            }

            if contactEntity.showOtherThreemaTypeIcon {
                // Add work info as first message
                let systemMessage = entityCreator.systemMessage(for: conversation)
                systemMessage?.type = NSNumber(value: kSystemMessageContactOtherAppInfo)
                systemMessage?.remoteSentDate = Date()
            }
            return conversation
        }
        else if createIfNotExisting, conversation == nil {
            DDLogError("Create conversation failed")
        }

        return conversation
    }

    @objc public func conversation(for identity: String, createIfNotExisting: Bool) -> Conversation? {
        conversation(for: identity, createIfNotExisting: createIfNotExisting, setLastUpdate: true)
    }
    
    public func conversation(
        for identity: String,
        createIfNotExisting: Bool,
        setLastUpdate: Bool = true
    ) -> Conversation? {
        guard let contact = entityFetcher.contact(for: identity) else {
            return nil
        }
        return conversation(forContact: contact, createIfNotExisting: createIfNotExisting, setLastUpdate: setLastUpdate)
    }

    func conversation(forMessage message: AbstractMessage) -> Conversation? {
        if let groupMessage = message as? AbstractGroupMessage {
            groupConversation(forMessage: groupMessage, fetcher: entityFetcher)
        }
        else {
            oneToOneConversation(forMessage: message, fetcher: entityFetcher)
        }
    }

    /// Looking for existing contact entity (sender) and conversation in current and in main DB context.
    ///
    /// - Parameter abstractMessage: Get sender and conversation from DB for that message
    /// - Returns: Conversation if is exists
    ///     Outgoing:
    ///         - Sender is nil because its me
    ///         - Receiver of one to one conversation otherwise nil
    ///     Incoming:
    ///         - Sender of the message
    ///         - Receiver is nil because its me
    func existingConversationSenderReceiver(for abstractMessage: AbstractMessage)
        -> (conversation: Conversation?, sender: ContactEntity?, receiver: ContactEntity?) {

        // Get DB objects Conversation and ContactEntity from particular entity fetcher
        func conversationSenderReceiver(fetcher: EntityFetcher)
            -> (conversation: Conversation?, sender: ContactEntity?, receiver: ContactEntity?) {
            var sender: ContactEntity?
            var receiver: ContactEntity?
            var conversation: Conversation?

            if let groupMessage = abstractMessage as? AbstractGroupMessage {
                conversation = groupConversation(forMessage: groupMessage, fetcher: fetcher)

                // From identity it's me if the message is a reflected outgoing message
                if abstractMessage.fromIdentity != myIdentityStore.identity {
                    sender = fetcher.contact(for: abstractMessage.fromIdentity)
                }

                assert(receiver == nil, "Receiver is always nil for group messages")
            }
            else {
                conversation = oneToOneConversation(forMessage: abstractMessage, fetcher: fetcher)
                
                if let conversation {
                    // From identity it's me if the message is a reflected outgoing message
                    if abstractMessage.fromIdentity != myIdentityStore.identity {
                        sender = conversation.contact
                    }
                    else {
                        receiver = conversation.contact
                    }
                }
                else {
                    if abstractMessage.fromIdentity != myIdentityStore.identity {
                        sender = fetcher.contact(for: abstractMessage.fromIdentity)
                    }
                    else {
                        receiver = fetcher.contact(for: abstractMessage.toIdentity)
                    }
                }
                
                assert(
                    (sender != nil && receiver == nil) || (sender == nil && receiver != nil),
                    "Sender or receiver have to be set, but never both (because I'm one of them)"
                )
            }
                
            return (conversation, sender, receiver)
        }

        var result: (conversation: Conversation?, sender: ContactEntity?, receiver: ContactEntity?)!
        dbContext.current.performAndWait {
            result = conversationSenderReceiver(fetcher: entityFetcher)
        }

        if result.conversation == nil, result.sender == nil, result.receiver == nil, !isMainDBContext {
            DDLogWarn("Looking for contact entity and conversation on main DB context")
            var resultObjectIDs: (
                conversationObjectID: NSManagedObjectID?,
                senderObjectID: NSManagedObjectID?,
                receiverObjectID: NSManagedObjectID?
            )
            dbContext.main.performAndWait {
                let resultObject =
                    conversationSenderReceiver(fetcher: EntityFetcher(
                        dbContext.main,
                        myIdentityStore: myIdentityStore
                    ))
                resultObjectIDs = (
                    resultObject.conversation?.objectID,
                    resultObject.sender?.objectID,
                    resultObject.receiver?.objectID
                )
            }

            // Apply contact entity and conversation to current DB context
            if let conversationObjectID = resultObjectIDs.conversationObjectID {
                result.conversation = dbContext.current.object(with: conversationObjectID) as? Conversation
            }
            if let senderObjectID = resultObjectIDs.senderObjectID {
                result.sender = dbContext.current.object(with: senderObjectID) as? ContactEntity
            }
            if let receiverObjectID = resultObjectIDs.receiverObjectID {
                result.receiver = dbContext.current.object(with: receiverObjectID) as? ContactEntity
            }
        }

        return result
    }
    
    @objc func existingContact(with identity: String) -> Bool {
        var objectID: NSManagedObjectID?
        dbContext.current.performAndWait {
            guard let contact = entityFetcher.contact(for: identity) else {
                return
            }
            objectID = contact.objectID
        }

        guard objectID == nil else {
            return true
        }
        
        dbContext.main.performAndWait {
            guard let contact = EntityFetcher(dbContext.main, myIdentityStore: myIdentityStore).contact(for: identity)
            else {
                return
            }
            objectID = contact.objectID
        }
        
        if let objectID {
            dbContext.current.object(with: objectID)
        }
        
        return objectID != nil
    }

    @available(*, deprecated, message: "Just for Objective-C calls")
    @objc func existingConversationSenderReceiver(
        for abstractMessage: AbstractMessage,
        sender: UnsafeMutablePointer<ContactEntity?>,
        receiver: UnsafeMutablePointer<ContactEntity?>
    ) -> Conversation? {
        let result = existingConversationSenderReceiver(for: abstractMessage)
        sender.pointee = result.sender
        receiver.pointee = result.receiver
        return result.conversation
    }

    /// Looking for existing message in current and in main DB context or creating new message it was not found.
    ///
    /// - Parameters:
    ///   - abstractMessage: Get or create message from DB for that message
    ///   - sender: Is only necessary for group message and I'm not the sender
    ///   - conversation: Search or insert message in this conversation
    ///   - thumbnail: Is needed to create deprecated `VideoMessageEntity`, because thumbnail is not optional
    ///   - onCompletion: Existing or new (unsaved) message from DB
    ///   - onError: ThreemaProtocolError.messageAlreadyProcessed, TaskExecutionError.messageTypeMismatch
    @available(*, deprecated, message: "Just for Objective-C calls")
    @objc func getOrCreateMessage(
        for abstractMessage: AbstractMessage,
        sender: ContactEntity?,
        conversation: Conversation,
        thumbnail: UIImage?,
        onCompletion: @escaping (BaseMessage) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        do {
            try onCompletion(
                getOrCreateMessage(
                    for: abstractMessage,
                    sender: sender,
                    conversation: conversation,
                    thumbnail: thumbnail
                )
            )
        }
        catch {
            onError(error)
        }
    }

    /// Looking for existing message in current and in main DB context or creating new message it was not found.
    ///
    /// - Parameters:
    ///   - abstractMessage: Get or create message from DB for that message
    ///   - sender: Is only necessary for group message and I'm not the sender
    ///   - conversation: Search or insert message in this conversation
    ///   - thumbnail: Is needed to create deprecated `VideoMessageEntity`, because thumbnail is not optional
    /// - Returns: Existing or new (unsaved) message from DB
    /// - Throws: ThreemaProtocolError.messageAlreadyProcessed, TaskExecutionError.messageTypeMismatch
    func getOrCreateMessage(
        for abstractMessage: AbstractMessage,
        sender: ContactEntity?,
        conversation: Conversation,
        thumbnail: UIImage?
    ) throws -> BaseMessage {
        assert(abstractMessage.fromIdentity != nil, "Sender identity is needed to calculating sending direction")

        // Get DB objects BaseMessage from particular entity fetcher
        func getMessage(for conversation: Conversation, fetcher: EntityFetcher) -> BaseMessage? {
            fetcher.message(with: abstractMessage.messageID, conversation: conversation)
        }

        return try getOrCreateMessageQueue.sync {
            var message: BaseMessage?

            try dbContext.current.performAndWait {
                message = getMessage(for: conversation, fetcher: entityFetcher)
                guard !(message?.delivered.boolValue ?? false) else {
                    DDLogWarn("Message ID \(abstractMessage.messageID.hexString) already processed")
                    throw ThreemaProtocolError.messageAlreadyProcessed
                }
            }

            if message == nil, !isMainDBContext {
                DDLogNotice("Looking for the message \(abstractMessage.messageID.hexString) on main DB context")
                var messageObjectID: NSManagedObjectID?
                dbContext.main.performAndWait {
                    messageObjectID = getMessage(
                        for: conversation,
                        fetcher: EntityFetcher(dbContext.main, myIdentityStore: myIdentityStore)
                    )?.objectID
                }

                // Apply message to current DB context
                if let messageObjectID {
                    DDLogNotice("Apply message \(abstractMessage.messageID.hexString) to current DB context")
                    message = dbContext.current.object(with: messageObjectID) as? BaseMessage
                    guard !(message?.delivered.boolValue ?? false) else {
                        DDLogWarn("Message ID \(abstractMessage.messageID.hexString) already processed")
                        throw ThreemaProtocolError.messageAlreadyProcessed
                    }
                }
            }

            if let message {
                // Validate type of existing message
                if abstractMessage is BoxAudioMessage || abstractMessage is GroupAudioMessage {
                    guard message is AudioMessageEntity else {
                        throw TaskExecutionError
                            .messageTypeMismatch(message: "message ID: \(abstractMessage.messageID.hexString)")
                    }
                }
                else if abstractMessage is BoxBallotCreateMessage || abstractMessage is GroupBallotCreateMessage {
                    guard message is BallotMessage else {
                        throw TaskExecutionError
                            .messageTypeMismatch(message: "message ID: \(abstractMessage.messageID.hexString)")
                    }
                }
                else if abstractMessage is BoxFileMessage || abstractMessage is GroupFileMessage {
                    guard message is FileMessageEntity else {
                        throw TaskExecutionError
                            .messageTypeMismatch(message: "message ID: \(abstractMessage.messageID.hexString)")
                    }
                }
                else if abstractMessage is BoxImageMessage || abstractMessage is GroupImageMessage {
                    guard message is ImageMessage else {
                        throw TaskExecutionError
                            .messageTypeMismatch(message: "message ID: \(abstractMessage.messageID.hexString)")
                    }
                }
                else if abstractMessage is BoxLocationMessage || abstractMessage is GroupLocationMessage {
                    guard message is LocationMessage else {
                        throw TaskExecutionError
                            .messageTypeMismatch(message: "message ID: \(abstractMessage.messageID.hexString)")
                    }
                }
                else if abstractMessage is BoxTextMessage || abstractMessage is GroupTextMessage {
                    guard message is TextMessage else {
                        throw TaskExecutionError
                            .messageTypeMismatch(message: "message ID: \(abstractMessage.messageID.hexString)")
                    }
                }
                else if abstractMessage is BoxVideoMessage || abstractMessage is GroupVideoMessage {
                    guard message is VideoMessageEntity else {
                        throw TaskExecutionError
                            .messageTypeMismatch(message: "message ID: \(abstractMessage.messageID.hexString)")
                    }
                }
            }
            else {
                // Create new message and save it to DB (without applying sender and conversation)
                try performAndWaitSave {
                    if let amsg = abstractMessage as? BoxAudioMessage {
                        message = self.entityCreator.audioMessageEntity(fromBox: amsg)
                    }
                    else if let amsg = abstractMessage as? BoxBallotCreateMessage {
                        message = self.entityCreator.ballotMessage(fromBox: amsg)
                    }
                    else if let amsg = abstractMessage as? BoxFileMessage {
                        message = self.entityCreator.fileMessageEntity(fromBox: amsg)
                    }
                    else if let amsg = abstractMessage as? BoxImageMessage {
                        message = self.entityCreator.imageMessageEntity(fromBox: amsg)
                    }
                    else if let amsg = abstractMessage as? BoxLocationMessage {
                        message = self.entityCreator.locationMessage(fromBox: amsg)
                    }
                    else if let amsg = abstractMessage as? BoxTextMessage {
                        message = self.entityCreator.textMessage(fromBox: amsg)
                    }
                    else if let amsg = abstractMessage as? BoxVideoMessage {
                        message = self.entityCreator.videoMessageEntity(fromBox: amsg)
                    }
                    else if let amsg = abstractMessage as? GroupAudioMessage {
                        message = self.entityCreator.audioMessageEntity(fromGroupBox: amsg)
                        message?.sender = sender
                    }
                    else if let amsg = abstractMessage as? GroupBallotCreateMessage {
                        message = self.entityCreator.ballotMessage(fromBox: amsg)
                        message?.sender = sender
                    }
                    else if let amsg = abstractMessage as? GroupFileMessage {
                        message = self.entityCreator.fileMessageEntity(fromBox: amsg)
                        message?.sender = sender
                    }
                    else if let amsg = abstractMessage as? GroupImageMessage {
                        message = self.entityCreator.imageMessageEntity(fromGroupBox: amsg)
                        message?.sender = sender
                    }
                    else if let amsg = abstractMessage as? GroupLocationMessage {
                        message = self.entityCreator.locationMessage(fromGroupBox: amsg)
                        message?.sender = sender
                    }
                    else if let amsg = abstractMessage as? GroupTextMessage {
                        message = self.entityCreator.textMessage(fromGroupBox: amsg)
                        message?.sender = sender
                    }
                    else if let amsg = abstractMessage as? GroupVideoMessage {
                        message = self.entityCreator.videoMessageEntity(fromGroupBox: amsg)
                        message?.sender = sender
                    }

                    if message is VideoMessageEntity {
                        if let thumbnail,
                           let imageData = self.entityCreator.imageData() {

                            imageData.data = thumbnail.jpegData(compressionQuality: kJPEGCompressionQualityLow)
                            imageData.width = NSNumber(floatLiteral: thumbnail.size.width)
                            imageData.height = NSNumber(floatLiteral: thumbnail.size.height)

                            (message as? VideoMessageEntity)?.thumbnail = imageData
                        }
                        else {
                            fatalError("Create video message failed, because of missing thumbnail")
                        }
                    }

                    guard let message else {
                        DDLogWarn("Unknown message type (ID: \(abstractMessage.messageID.hexString))")
                        throw ThreemaProtocolError.unknownMessageType
                    }

                    message.conversation = conversation

                    let isOutgoingMessage = abstractMessage.fromIdentity == self.myIdentityStore.identity
                    message.isOwn = NSNumber(booleanLiteral: isOutgoingMessage)

                    conversation.lastMessage = message
                    conversation.lastUpdate = .now
                }
            }

            return message!
        }
    }

    @available(*, deprecated, message: "Just for Objective-C calls")
    @objc func deleteMessage(
        for abstractMessage: AbstractMessage,
        conversation: Conversation,
        onError: @escaping (Error) -> Void
    ) -> BaseMessage? {
        do {
            return try deleteMessage(for: abstractMessage, conversation: conversation)
        }
        catch {
            onError(error)
        }
        return nil
    }

    func deleteMessage(
        for abstractMessage: AbstractMessage,
        conversation: Conversation
    ) throws -> BaseMessage {
        var e2eDeleteMessage: CspE2e_DeleteMessage?

        if let deleteMessage = abstractMessage as? DeleteMessage {
            e2eDeleteMessage = deleteMessage.decoded
        }
        else if let deleteGroupMessage = abstractMessage as? DeleteGroupMessage {
            e2eDeleteMessage = deleteGroupMessage.decoded
        }

        guard let e2eDeleteMessage else {
            DDLogError("Abstract message \(abstractMessage.messageID.hexString) it's not an delete message")
            throw ThreemaProtocolError.messageToDeleteNotFound
        }

        return try performAndWaitSave {
            guard let message = self.entityFetcher.message(
                with: e2eDeleteMessage.messageID.littleEndianData,
                conversation: conversation
            ) else {
                DDLogWarn("Message \(e2eDeleteMessage.messageID.littleEndianData.hexString) to delete not found")
                throw ThreemaProtocolError.messageToDeleteNotFound
            }

            if abstractMessage.fromIdentity != self.myIdentityStore.identity {
                // If sender nil, then its a reflected outgoing message
                if let sender = message.sender ?? conversation.contact {
                    guard sender.identity == abstractMessage.fromIdentity else {
                        DDLogWarn("Message \(message.id.hexString) can't be deleted because of sender mismatch")
                        throw ThreemaProtocolError.messageSenderMismatch
                    }
                }
            }

            message.deletedAt = abstractMessage.date
            message.lastEditedAt = nil

            // Delete content of this base message
            try self.entityDestroyer.deleteMessageContent(of: message)

            conversation.updateLastDisplayMessage(with: self)

            return message
        }
    }

    @available(*, deprecated, message: "Just for Objective-C calls")
    @objc func editMessage(
        for abstractMessage: AbstractMessage,
        conversation: Conversation,
        onError: @escaping (Error) -> Void
    ) -> BaseMessage? {
        do {
            return try editMessage(for: abstractMessage, conversation: conversation)
        }
        catch {
            onError(error)
        }
        return nil
    }

    func editMessage(
        for abstractMessage: AbstractMessage,
        conversation: Conversation
    ) throws -> BaseMessage {
        var e2eEditMessage: CspE2e_EditMessage?

        if let editMessage = abstractMessage as? EditMessage {
            e2eEditMessage = editMessage.decoded
        }
        else if let editGroupMessage = abstractMessage as? EditGroupMessage {
            e2eEditMessage = editGroupMessage.decoded
        }

        guard let e2eEditMessage else {
            DDLogError("Abstract message \(abstractMessage.messageID.hexString) it's not an edit message")
            throw ThreemaProtocolError.messageToEditNotFound
        }

        return try performAndWaitSave {
            guard let message = self.entityFetcher.message(
                with: e2eEditMessage.messageID.littleEndianData,
                conversation: conversation
            ) else {
                DDLogWarn("Message \(e2eEditMessage.messageID.littleEndianData.hexString) to edit not found")
                throw ThreemaProtocolError.messageToEditNotFound
            }

            if abstractMessage.fromIdentity != self.myIdentityStore.identity {
                // If sender nil, then its a reflected outgoing message
                if let sender = message.sender ?? conversation.contact {
                    guard sender.identity == abstractMessage.fromIdentity else {
                        DDLogWarn("Message \(message.id.hexString) can't be edited because of sender mismatch")
                        throw ThreemaProtocolError.messageSenderMismatch
                    }
                }
            }
            
            let history = self.entityCreator.messageHistoryEntry(for: message)
          
            if let textMessage = message as? TextMessage {
                history?.text = textMessage.text
                textMessage.text = e2eEditMessage.text
                textMessage.lastEditedAt = abstractMessage.date
            }
            else if let fileMessage = message as? FileMessageEntity {
                history?.text = fileMessage.caption
                fileMessage.caption = e2eEditMessage.text
                fileMessage.json = FileMessageEncoder.jsonString(for: fileMessage)
                fileMessage.lastEditedAt = abstractMessage.date
            }
            else if let history {
                DDLogWarn("Received edit for unsupported message type")
                self.entityDestroyer.deleteObject(object: history)
            }

            return message
        }
    }

    private func groupConversation(forMessage message: AbstractGroupMessage, fetcher: EntityFetcher) -> Conversation? {
        fetcher.conversation(for: message.groupID, creator: message.groupCreator)
    }

    private func oneToOneConversation(forMessage message: AbstractMessage, fetcher: EntityFetcher) -> Conversation? {
        assert(!(message is AbstractGroupMessage))

        if message.toIdentity != myIdentityStore.identity {
            return fetcher.conversation(forIdentity: message.toIdentity)
        }
        else if message.fromIdentity != myIdentityStore.identity {
            return fetcher.conversation(forIdentity: message.fromIdentity)
        }

        return nil
    }

    private var isMainDBContext: Bool {
        dbContext.main === dbContext.current
    }
}
