import CocoaLumberjackSwift
import CoreData
import Foundation
import ThreemaEssentials

/// This implements the _Spam Potential Detection Steps_ for 1:1 chats defined by the protocol
///
/// Based on 39f3fd03d41722a1843ab42de68e2297985b36d9 draft
public actor SpamDetector: SpamDetecting {
    
    private let businessInjector: BusinessInjectorProtocol
        
    /// Entity manager with a private queue Core Data context
    ///
    /// The context is only created when the first detection runs. Because this is actor isolated it never happens on
    /// the main queue.
    private lazy var backgroundEntityManager: EntityManager = {
        let entityManager = businessInjector.runInBackgroundAndWait { backgroundBusinessInjector in
            backgroundBusinessInjector.entityManager
        }
        
        return entityManager
    }()
    
    public init(businessInjector: BusinessInjectorProtocol) {
        self.businessInjector = businessInjector
    }
    
    public func isPotentialSpam(conversationObjectID: NSManagedObjectID) async -> Bool {
        // 1. - 3.
        guard await contactAndConversationIndicatesSpamPotential(of: conversationObjectID) else {
            return false
        }
        
        // 4. - 8.
        return await messagesIndicateSpamPotential(in: conversationObjectID)
    }
    
    /// Steps 1 - 3: Open spam reporting state and unverified contact has some spam potential
    ///
    /// - Parameter conversationObjectID: Object ID of the conversation to check
    /// - Returns: `true` if the contact indicates some spam potential
    private func contactAndConversationIndicatesSpamPotential(of conversationObjectID: NSManagedObjectID) async -> Bool {
        let entityManager = backgroundEntityManager
        
        return await entityManager.perform { () -> Bool in
            // 1. Let `contact` be the associated contact of the targeted 1:1 conversation.
            
            guard let conversationEntity = entityManager.entityFetcher.conversationEntity(
                with: conversationObjectID
            ) else {
                DDLogError("Unable to load conversation for potential spam detection")
                return false
            }
            
            guard let contactEntity = conversationEntity.contact else {
                DDLogError("Unable to load contact for potential spam detection")
                return false
            }
            
            // 2. If the spam reporting state of the associated conversation is either
            //    _dismissed_ or _reported_, return that no spam potential was detected.
            guard conversationEntity.spamReportingState != .notSpam, conversationEntity.spamReportingState != .reported else {
                return false
            }
            
            // 3. If `contact`'s verification level is not `UNVERIFIED`, return that no
            //    spam potential was detected.
            guard contactEntity.contactVerificationLevel == .unverified else {
                return false
            }
            
            return true
        }
    }
    
    /// Steps 4 - 8: Check the messages of the conversation for spam potential
    ///
    /// - Parameter conversationObjectID: Object ID of the conversation to check
    /// - Returns: `true` if the messages indicate spam potential
    private func messagesIndicateSpamPotential(in conversationObjectID: NSManagedObjectID) async -> Bool {
        let entityManager = backgroundEntityManager
        
        return await entityManager.perform {
            guard let conversationEntity = entityManager.entityFetcher.conversationEntity(
                with: conversationObjectID
            ) else {
                DDLogError("Unable to load conversation for potential spam detection")
                return false
            }
            
            // 4. If the conversation contains at least one outgoing _content_ message
            //    (i.e. one that was created by a message with persistent entry type
            //    _content_), return that no spam potential was detected.
            guard entityManager.entityFetcher.outgoingContentMessagesCount(in: conversationEntity) <= 0 else {
                return false
            }
            
            // 5. Look up the earliest incoming _content_ message (i.e. one that was
            //    created by a message with persistent entry type _content_) in the
            //    conversation and let `earliest-message` be the result.
            // 6. If `earliest-message` is `undefined`, return that no spam potential was
            //    detected.
            
            guard let oldestMessageDate = entityManager.entityFetcher.dateOfOldestContentMessage(
                in: conversationEntity
            ) else {
                return false
            }
            
            // 7. If the timespan between `earliest-message`'s `received-at` date
            //    and the `contact`'s creation date is greater than 7 days, return that no
            //    spam potential was detected.
            
            guard let contactCreationDate = conversationEntity.contact?.createdAt else {
                DDLogError("Contact creation date should be set")
                assertionFailure()
                return false
            }
            
            guard oldestMessageDate.timeIntervalSince(contactCreationDate) <= (24 * 60 * 60 * 7) else {
                return false
            }
            
            // 8. Return that spam potential was detected.
            return true
        }
    }
}
