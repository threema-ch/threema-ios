//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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

final class ReactionsMessageProcessor: NSObject {
    
    enum ReactionsMessageProcessingError: Error {
        case reactionCreationFailed
    }
    
    private let entityManager: EntityManager
    
    @objc init(entityManager: EntityManager) {
        self.entityManager = entityManager
    }

    @objc func handleMessage(
        abstractMessage: ReactionMessage,
        conversation: ConversationEntity
    ) -> BaseMessage? {
        let message: BaseMessage? = entityManager.performAndWaitSave {
            
            guard let decoded = abstractMessage.decoded else {
                return nil
            }
            
            guard let message = self.entityManager.entityFetcher.message(
                with: decoded.messageID.littleEndianData,
                conversation: conversation
            ) else {
                return nil
            }
            
            guard message.deletedAt == nil else {
                return nil
            }
            
            let contact = self.entityManager.entityFetcher.contact(for: abstractMessage.fromIdentity)
            
            // If the contact is nil, this might mean we are the sender. If this is not the case we discard
            guard contact != nil || abstractMessage.fromIdentity == MyIdentityStore.shared().identity else {
                DDLogError("[Reaction] Contact not found and we were not the sender too. Discarding reaction message.")
                return nil
            }
            
            switch decoded.action {
            case let .apply(reactionData):
                guard reactionData.count <= 64 else {
                    DDLogError("[Reaction] Received reaction data exceeded 64 bytes.")
                    return nil
                }
                
                guard let reactionString = String(data: reactionData, encoding: .utf8) else {
                    DDLogError("[Reaction] Could not decode reaction data.")
                    return nil
                }
                
                guard self.entityManager.entityFetcher.messageReactionEntity(
                    forMessageID: decoded.messageID.littleEndianData,
                    creator: contact,
                    reaction: reactionString
                ) == nil else {
                    DDLogWarn("[Reaction] Tried to apply a reaction that already exists.")
                    return nil
                }

                guard let reactionEntity = self.entityManager.entityCreator.messageReactionEntity() else {
                    assertionFailure("Should never happen.")
                    return nil
                }
                
                reactionEntity.date = abstractMessage.date
                reactionEntity.creator = contact
                reactionEntity.reaction = reactionString
                reactionEntity.message = message
               
            case let .withdraw(reactionData):
                guard reactionData.count <= 64 else {
                    DDLogError("[Reaction] Received reaction data exceeded 64 bytes.")
                    return nil
                }
                
                guard let reactionString = String(data: reactionData, encoding: .utf8) else {
                    DDLogError("[Reaction] Could not decode reaction data.")
                    return nil
                }
                
                guard let reaction = self.entityManager.entityFetcher.messageReactionEntity(
                    forMessageID: decoded.messageID.littleEndianData,
                    creator: contact,
                    reaction: reactionString
                ) else {
                    return nil
                }
                
                self.entityManager.entityDestroyer.delete(reaction: reaction)

            case .none:
                DDLogError("Received unknown action for reaction.")
            }
            
            return message
        }
        return message
    }
    
    @objc func handleGroupMessage(
        abstractMessage: GroupReactionMessage,
        conversation: ConversationEntity
    ) -> BaseMessage? {
        let message: BaseMessage? = entityManager.performAndWaitSave {
            
            guard let decoded = abstractMessage.decoded else {
                return nil
            }
            
            guard let message = self.entityManager.entityFetcher.message(
                with: decoded.messageID.littleEndianData,
                conversation: conversation
            ) else {
                return nil
            }
            
            guard message.deletedAt == nil else {
                return nil
            }
            
            let contact = self.entityManager.entityFetcher.contact(for: abstractMessage.fromIdentity)
            
            // If the contact is nil, this might mean we are the sender. If this is not the case we discard
            guard contact != nil || abstractMessage.fromIdentity == MyIdentityStore.shared().identity else {
                DDLogError("[Reaction] Contact not found and we were not the sender too. Discarding reaction message.")
                return nil
            }
            
            switch decoded.action {
            case let .apply(reactionData):
                guard reactionData.count <= 64 else {
                    DDLogError("[Reaction] Received reaction data exceeded 64 bytes.")
                    return nil
                }
                
                guard let reactionString = String(data: reactionData, encoding: .utf8) else {
                    DDLogError("[Reaction] Could not decode reaction data.")
                    return nil
                }
                
                guard self.entityManager.entityFetcher.messageReactionEntity(
                    forMessageID: decoded.messageID.littleEndianData,
                    creator: contact,
                    reaction: reactionString
                ) == nil else {
                    DDLogWarn("[Reaction] Tried to apply a reaction that already exists.")
                    return nil
                }
                
                guard let reactionEntity = self.entityManager.entityCreator.messageReactionEntity() else {
                    assertionFailure("Should never happen.")
                    return nil
                }
                
                reactionEntity.date = abstractMessage.date
                reactionEntity.creator = contact
                reactionEntity.reaction = reactionString
                reactionEntity.message = message
               
            case let .withdraw(reactionData):
                guard reactionData.count <= 64 else {
                    DDLogError("[Reaction] Received reaction data exceeded 64 bytes.")
                    return nil
                }
                
                guard let reactionString = String(data: reactionData, encoding: .utf8) else {
                    DDLogError("[Reaction] Could not decode reaction data.")
                    return nil
                }
                
                guard let reaction = self.entityManager.entityFetcher.messageReactionEntity(
                    forMessageID: decoded.messageID.littleEndianData,
                    creator: contact,
                    reaction: reactionString
                ) else {
                    return nil
                }
                
                self.entityManager.entityDestroyer.delete(reaction: reaction)

            case .none:
                DDLogError("Received unknown action for reaction.")
            }
            
            return message
        }
        return message
    }
    
    /// Must be called in a save block
    @objc func handleLegacyReaction(ack: Bool, date: Date, messageID: NSManagedObjectID, sender: String) throws {
       
        guard let message = entityManager.entityFetcher.existingObject(with: messageID) as? BaseMessage,
              !message.isDeleted else {
            DDLogError("[Reaction] Message not found or is marked as deleted. Discarding incoming ack/dec.")
            return
        }
        
        let contact = entityManager.entityFetcher.contact(for: sender)
        
        // If the contact is nil, this might mean we are the sender. If this is not the case we discard
        guard contact != nil || sender == MyIdentityStore.shared().identity else {
            DDLogError("[Reaction] Contact not found and we were not the sender too. Discarding reaction message.")
            return
        }
        
        // If we have a reaction from the sender on the message already and we receive another legacy ack/deck, we
        // assume he still does not fully support reactions and remove the ones sent before to mimic the legacy
        // behavior.
        if let existingReactions = entityManager.entityFetcher.messageReactionEntities(
            for: message,
            creator: contact
        ), !existingReactions.isEmpty {
            
            for existingReaction in existingReactions {
                entityManager.entityDestroyer.delete(reaction: existingReaction)
            }
        }
            
        // Map legacy reaction to new reaction
        guard let reaction = entityManager.entityCreator.messageReactionEntity() else {
            DDLogError("[Reaction] Could not create reaction entity. Discarding incoming ack/dec.")

            throw ReactionsMessageProcessingError.reactionCreationFailed
        }
        
        reaction.creator = contact
        reaction.reaction = ack ? "👍" : "👎"
        reaction.date = date
        reaction.message = message
    }
}
