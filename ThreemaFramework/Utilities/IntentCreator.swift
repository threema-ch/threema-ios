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
import Intents
import PromiseKit

public class IntentCreator {
    
    public enum IntentError: Error {
        case couldNotCreateIntent
        case createIntentFailed(message: String)
    }
    
    private let userSettings: UserSettingsProtocol
    private let entityManager: EntityManager
    
    public init(userSettings: UserSettingsProtocol, entityManager: EntityManager) {
        self.userSettings = userSettings
        self.entityManager = entityManager
    }
    
    // MARK: - Functions
    
    public func inSendMessageIntentInteraction(
        for contactID: String,
        direction: INInteractionDirection
    ) -> INInteraction? {
        
        if direction == .outgoing,
           !userSettings.allowOutgoingDonations {
            DDLogVerbose("Donations for outgoing interactions are disabled by the user")
            return nil
        }
        
        if direction == .incoming {
            guard case NotificationType.complete.userSettingsValue = userSettings.notificationType.intValue else {
                DDLogVerbose("Donations for incoming interactions are disabled by the user")
                return nil
            }
        }
        
        var fetchedContact: ContactEntity?
        var isPrivate = false
        
        entityManager.performAndWaitSave {
            if let internalFetchedContact = self.entityManager.entityFetcher.contact(for: contactID) {
                fetchedContact = internalFetchedContact
                if let conversation = self.entityManager.conversation(
                    forContact: internalFetchedContact,
                    createIfNotExisting: false
                ) {
                    isPrivate = conversation.conversationCategory == .private
                }
            }
        }
        
        guard !isPrivate else {
            DDLogVerbose("Do not donate for private conversations")
            return nil
        }
        
        var conversationIdentifier: String?
        var contact: INPerson?
        var recipients = [INPerson]()
        var sender: INPerson?
        
        entityManager.performAndWait {
            guard let fetchedContact else {
                return
            }
            
            conversationIdentifier = fetchedContact.objectID.uriRepresentation().absoluteString
            contact = fetchedContact.inPerson
        }
        
        guard let conversationIdentifier,
              let contact else {
            return nil
        }
        
        if direction == .incoming {
            // Because this communication is incoming, we can infer that the current user is a recipient. Don't include
            // the current user when initializing the intent.
            sender = contact
        }
        else if direction == .outgoing {
            recipients.append(contact)
        }
                
        let intent = INSendMessageIntent(
            recipients: recipients,
            outgoingMessageType: .outgoingMessageText,
            content: nil,
            speakableGroupName: nil,
            conversationIdentifier: conversationIdentifier,
            serviceName: nil,
            sender: sender,
            attachments: nil
        )
        
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.groupIdentifier = conversationIdentifier
        interaction.direction = direction
        return interaction
    }
    
    public func inSendMessageIntentInteraction(
        for groupID: Data,
        creatorID: String,
        contactID: String?,
        direction: INInteractionDirection
    ) -> INInteraction? {
        
        if direction == .outgoing,
           !userSettings.allowOutgoingDonations {
            DDLogVerbose("Donations for outgoing interactions are disabled by the user")
            return nil
        }
        
        if direction == .incoming {
            guard case NotificationType.complete.userSettingsValue = userSettings.notificationType.intValue else {
                DDLogVerbose("Donations for incoming interactions are disabled by the user")
                return nil
            }
        }
        
        var fetchedContact: ContactEntity?
        var groupConversation: ConversationEntity?
        var isPrivate = false
        
        entityManager.performAndWait {
            if let internalFetchedContact = self.entityManager.entityFetcher.contact(for: contactID) {
                fetchedContact = internalFetchedContact
                if let conversation = self.entityManager.conversation(
                    forContact: internalFetchedContact,
                    createIfNotExisting: false
                ) {
                    isPrivate = conversation.conversationCategory == .private
                }
            }
            
            if let conversation = self.entityManager.entityFetcher.conversationEntity(
                for: groupID,
                creator: creatorID
            ) {
                isPrivate = isPrivate || conversation.conversationCategory == .private
                groupConversation = conversation
            }
        }
        
        guard !isPrivate else {
            DDLogVerbose("Do not donate for private conversations")
            return nil
        }
        
        var conversationIdentifier: String?
        var contact: INPerson?
        var sender: INPerson?
        var groupName: INSpeakableString?
        var groupImage: INImage?
        var recipientCount = 0
        
        entityManager.performAndWait {
            contact = fetchedContact?.inPerson ?? nil

            guard let groupConversation else {
                return
            }
            
            conversationIdentifier = groupConversation.objectID.uriRepresentation().absoluteString
            
            recipientCount = groupConversation.unwrappedMembers.count
            
            if let fetchedGroupName = groupConversation.groupName {
                groupName = INSpeakableString(spokenPhrase: fetchedGroupName)
            }
            
            let groupManager = GroupManager(entityManager: self.entityManager)
            if let group = groupManager.getGroup(conversation: groupConversation) {
                let image: UIImage = ProfilePictureGenerator.addBackground(to: group.profilePicture)
                groupImage = INImage(uiImage: image)
            }
        }
        
        guard let conversationIdentifier,
              let groupName else {
            return nil
        }
        
        let groupMemberCount = INSendMessageIntentDonationMetadata()
        groupMemberCount.recipientCount = recipientCount

        if direction == .incoming {
            // Because this communication is incoming, we can infer that the current user is a recipient. Don't include
            // the current user when initializing the intent.
            sender = contact
        }
        
        let intent = INSendMessageIntent(
            recipients: nil,
            outgoingMessageType: .outgoingMessageText,
            content: nil,
            speakableGroupName: groupName,
            conversationIdentifier: conversationIdentifier,
            serviceName: nil,
            sender: sender,
            attachments: nil
        )
        
        intent.donationMetadata = groupMemberCount
        
        // Set groupImage; this is needed to be displayed as group communication notification
        if let groupImage {
            intent.setImage(groupImage, forParameterNamed: \.speakableGroupName)
        }
        
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.groupIdentifier = conversationIdentifier
        interaction.direction = direction
        return interaction
    }
}

extension IntentCreator {
    func donateInteraction(for group: Group) -> Promise<Void> {
        Promise { seal in
            guard let interaction = self.inSendMessageIntentInteraction(
                for: group.groupID,
                creatorID: group.groupCreatorIdentity,
                contactID: nil,
                direction: .outgoing
            ) else {
                seal.reject(IntentCreator.IntentError.couldNotCreateIntent)
                return
            }
            
            interaction.donate { error in
                if let error {
                    DDLogError("An error has occurred when donating an interaction \(error.localizedDescription)")
                    seal.reject(error)
                }
                seal.fulfill_()
            }
        }
    }
    
    func donateInteraction(for contact: ContactEntity) -> Promise<Void> {
        Promise { seal in
            guard let interaction = self.inSendMessageIntentInteraction(
                for: contact.identity,
                direction: .outgoing
            ) else {
                seal.reject(IntentCreator.IntentError.couldNotCreateIntent)
                return
            }
            
            interaction.donate { error in
                if let error {
                    DDLogError("An error has occurred when donating an interaction \(error.localizedDescription)")
                    seal.reject(error)
                }
                seal.fulfill_()
            }
        }
    }
}
