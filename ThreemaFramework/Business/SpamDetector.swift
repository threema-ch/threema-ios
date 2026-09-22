import CocoaLumberjackSwift
import CoreData
import Foundation
import ThreemaEssentials

/// Check if a conversation is potential spam
///
/// - Note: The detection needs Core Data access. Thus it is isolated to an actor to guarantee that it never runs on
///         the main queue.
public protocol SpamDetecting: Actor {
    func isPotentialSpam(conversationObjectID: NSManagedObjectID) async -> Bool
}

/// This implements the _Spam Potential Detection Steps_ defined by the protocol
///
/// Based on fcdb53c4ed669162b1c8a817db5081f55d664f95
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
        // 1. & 2.
        guard await contactIndicatesSpamPotential(of: conversationObjectID) else {
            return false
        }
        
        // 3. - 6.
        return await messagesIndicateSpamPotential(in: conversationObjectID)
    }
    
    /// Steps 1 & 2: Unverified contact has some spam potential
    ///
    /// - Parameter conversationObjectID: Object ID of the conversation to check
    /// - Returns: `true` if the contact indicates some spam potential
    private func contactIndicatesSpamPotential(of conversationObjectID: NSManagedObjectID) async -> Bool {
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
            
            // 2. If `contact`'s verification level is not `UNVERIFIED`, return that no
            //    spam potential was detected.
            guard contactEntity.contactVerificationLevel == .unverified else {
                return false
            }
            
            return true
        }
    }
    
    /// Steps 3 - 6: Check the messages of the conversation for spam potential
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
            
            // 3. If the conversation contains at least one outgoing _content_ message
            //    (i.e. one that was created by a message with persistent entry type
            //    _content_), return that no spam potential was detected.
            guard entityManager.entityFetcher.outgoingContentMessagesCount(in: conversationEntity) <= 0 else {
                return false
            }
            
            // 4. Look up the earliest incoming _content_ message (i.e. one that was
            //    created by a message with persistent entry type _content_) in the
            //    conversation and let `earliest-message` be the result.

            guard let oldestMessageDate = entityManager.entityFetcher.dateOfOldestContentMessage(
                in: conversationEntity
            ) else {
                return false
            }
            
            // 5. If the timespan between `earliest-message`'s `received-at` date and the
            //    `contact`'s creation date is greater than 7 days, return that no spam
            //    potential was detected.
            
            guard let contactCreationDate = conversationEntity.contact?.createdAt else {
                DDLogError("Contact creation date should be set")
                assertionFailure()
                return false
            }
            
            guard oldestMessageDate.timeIntervalSince(contactCreationDate) <= (24 * 60 * 60 * 7) else {
                return false
            }
            
            // 6. Return that spam potential was detected.
            return true
        }
    }
}
