//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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

extension StorageManagementView {
    
    /// Holds the storage and conversation data for the view.
    /// It tracks the total, in-use, and free storage on the device, as well as the storage used by Threema
    /// and the list of conversations.
    final class Model: ObservableObject, @unchecked Sendable {
        
        typealias ConversationMetaData = (messageCount: Int, fileCount: Int)
        
        private unowned var businessInjector: BusinessInjectorProtocol

        init(businessInjector: BusinessInjectorProtocol) {
            self.businessInjector = businessInjector
        }
        
        // MARK: - Public Functions
        
        /// Provides a profile picture image for a given conversation.
        /// - Parameter conversation: The `ConversationEntity` object for which to provide the profile picture.
        /// - Returns: An optional `UIImage` representing the profile picture, or `nil` if not available.
        func profilePictureProvider(_ conversation: ConversationEntity) async -> UIImage {
            let entityManager = businessInjector.entityManager
            
            return await entityManager.perform {
                if conversation.isGroup,
                   let group = self.businessInjector.groupManager.getGroup(conversation: conversation) {
                    return group.profilePicture
                }
                else if let contact = conversation.contact,
                        let contactEntity = entityManager.entityFetcher.contact(for: contact.identity) {
                    let businessContact = Contact(contactEntity: contactEntity)
                    return businessContact.profilePicture
                }
                
                return ProfilePictureGenerator.unknownContactImage
            }
        }
        
        /// Calculates metadata for a given conversation.
        /// - Parameter conversation: The `ConversationEntity` object for which to calculate metadata.
        /// - Returns: A `ConversationMetaData` tuple containing the message count and file count.
        func calcMetaData(for conversation: ConversationEntity) async -> ConversationMetaData {
            await Task {
                let messageFetcher = MessageFetcher(
                    for: conversation,
                    with: self.businessInjector.entityManager
                )
                return await MainActor.run {
                    (messageFetcher.count(), messageFetcher.mediaCount())
                }
            }.value
        }
        
        // MARK: - Private Functions
        
        /// Retrieves all conversations from the entity manager, filters them by the default category,
        /// and sorts them by the message count in descending order.
        /// The sorted conversations are then assigned to the `conversations` published property.
        func getAllConversations() -> [ConversationEntity] {
            guard let allConversations = businessInjector.entityManager.entityFetcher
                .allConversations() as? [ConversationEntity] else {
                return []
            }
            return allConversations.filter { $0.conversationCategory == .default }.sorted {
                let messageFetcher0 = MessageFetcher(for: $0, with: businessInjector.entityManager)
                let messageFetcher1 = MessageFetcher(for: $1, with: businessInjector.entityManager)
                return messageFetcher0.count() > messageFetcher1.count()
            }
        }
    }
}
