import CocoaLumberjackSwift
import CoreData
import Foundation
import ThreemaEssentials

/// This implements the _Group Spam Potential Detection Steps_ for group chats defined by the protocol
///
/// Based on 39f3fd03d41722a1843ab42de68e2297985b36d9 draft
public actor GroupSpamDetector: SpamDetecting {
    
    private let businessInjector: BusinessInjectorProtocol
    
    public init(businessInjector: BusinessInjectorProtocol) {
        self.businessInjector = businessInjector
    }
    
    public func isPotentialSpam(conversationObjectID: NSManagedObjectID) async -> Bool {
        
        // Background business injector is needed to access group manager
        await businessInjector.runInBackground { backgroundBusinessInjector in
            await backgroundBusinessInjector.entityManager.perform {

                let entityFetcher = backgroundBusinessInjector.entityManager.entityFetcher
                
                guard let conversationEntity = entityFetcher.conversationEntity(
                    with: conversationObjectID
                ) else {
                    return false
                }
                
                // 1. If the spam reporting state of the associated conversation is either
                //    _dismissed_ or _reported_, return that no spam potential was detected.
                guard conversationEntity.spamReportingState != .notSpam, conversationEntity.spamReportingState != .reported else {
                    return false
                }
                
                // 2. Let `group` be the associated group of the targeted group conversation
                //    and let `creator` be the creator of the group.
                
                guard let group = backgroundBusinessInjector.groupManager.getGroup(conversation: conversationEntity) else {
                    return false
                }
                
                // 3. & 4.
                guard let creator = self.checkGroupConversationAndGetCreator(
                    conversationEntity: conversationEntity,
                    group: group
                ) else {
                    return false
                }
                
                // 5. - 9.
                return self.messagesIndicateSpamPotential(
                    entityFetcher: entityFetcher,
                    conversationEntity: conversationEntity,
                    creator: creator
                )
            }
        }
    }
    
    /// Steps 3 & 4: If the group is active and somebody else created the group there is some spam potential
    ///
    /// - Parameters:
    ///   - group: Group to check
    ///   - conversationEntity: Conversation to check
    /// - Returns: Creator if there is some spam potential, `nil` otherwise
    private func checkGroupConversationAndGetCreator(
        conversationEntity: ConversationEntity,
        group: Group
    ) -> Contact? {
        // 3. If the user is the creator or the group is marked as _left_, return that
        //    no spam potential was detected.
        
        guard group.isOwnGroup == false else {
            return nil
        }
        
        guard group.didLeave == false, group.didForcedLeave == false else {
            return nil
        }
        
        // 4. If `creator`'s verification level is not `UNVERIFIED`, return that no
        //    spam potential was detected.
        
        // Checks again that the creator is not ourself and unknown
        guard case let .contact(creatorContact) = group.creator else {
            return nil
        }
        
        guard creatorContact.verificationLevel == .unverified else {
            return nil
        }
        
        return creatorContact
    }
    
    /// Step 5 - 9:  Check the messages of the group for spam potential
    ///
    /// - Parameters:
    ///   - entityFetcher: Fetcher used on background context
    ///   - conversationEntity: Conversation to check
    ///   - creator: Creator of group
    /// - Returns: `true` if the messages indicate spam potential
    private func messagesIndicateSpamPotential(
        entityFetcher: EntityFetcher,
        conversationEntity: ConversationEntity,
        creator: Contact
    ) -> Bool {
        
        // 5. If the group conversation contains at least one outgoing _content_
        //    message (i.e. one that was created by a message with persistent entry
        //    type _content_), return that no spam potential was detected.
        
        guard entityFetcher.outgoingContentMessagesCount(in: conversationEntity) <= 0 else {
            return false
        }
        
        // 6. Look up the earliest incoming _content_ message (i.e. one that was
        //    created by a message with persistent entry type _content_) in the
        //    conversation and let `earliest-message` be the result.
        // 7. If `earliest-message` is `undefined`, return that no spam potential was
        //    detected.
        
        guard let earliestIncomingContentMessageDate = entityFetcher.dateOfOldestContentMessage(in: conversationEntity) else {
            return false
        }
        
        // 8. If the timespan between `earliest-message`'s `received-at` date
        //    and the `creator`'s creation date is greater than 7 days, return that no
        //    spam potential was detected.
        
        guard let creatorCreationDate = creator.createdAt else {
            return false
        }
        
        guard earliestIncomingContentMessageDate.timeIntervalSince(creatorCreationDate) <= (60 * 60 * 24 * 7) else {
            return false
        }
        
        // 9. Return that potential spam was detected.
        return true
    }
}
