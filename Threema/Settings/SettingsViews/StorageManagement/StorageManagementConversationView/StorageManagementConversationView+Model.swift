//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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

import MBProgressHUD
import SwiftUI
import ThreemaFramework

// MARK: - StorageManagementConversationView.Model

extension StorageManagementConversationView {
    class Model: ObservableObject {
        
        private var conversation: Conversation?
        private var businessInjector: BusinessInjectorProtocol
        
        @Published var totalMessagesCount = 0
        @Published var totalMediaCount = 0
        
        @Published var deleteInProgress = false {
            willSet {
                let hud = ProgressHUD
                    .make(label: "delete_in_progress".localized)
                (newValue ? hud.show : hud.hide)?()
            }
        }
        
        var isSingleConversation: Bool {
            conversation != nil
        }
        
        var conversationName: String {
            conversation?.displayName ?? ""
        }
        
        /// Manage the Messages and Media
        ///
        /// - Parameters:
        ///   - conversation: Specify a `Conversation` object to manage storage for. Otherwise, storage for all
        /// conversations will be managed.
        ///   - businessInjector: An object conforming to `BusinessInjectorProtocol` used for dependency injection.
        init(conversation: Conversation?, businessInjector: BusinessInjectorProtocol) {
            self.businessInjector = businessInjector
            self.conversation = conversation
            refresh()
        }
    
        // MARK: - General methods
        
        /// Refresh message and media count and update the ui
        func refresh() {
            let conversations = conversations(businessInjector.entityManager)
            count(conversations)
        }
        
        func avatarImageProvider(completion: @escaping (UIImage?) -> Void) {
            AvatarMaker.shared().avatar(
                for: conversation,
                size: DetailsHeaderProfileView.avatarImageSize,
                masked: true
            ) { avatarImage, _ in
                DispatchQueue.main.async {
                    completion(avatarImage)
                }
            }
        }
        
        // MARK: - Deletion Logic
        
        /// Delete messages older than the specified option
        ///
        /// - Parameter option: The `OlderThanOption` that specifies the age of messages to be deleted.
        func messageDelete(_ option: OlderThanOption) {
            deleteInProgress = true
            Task {
                guard let count = await businessInjector
                    .backgroundEntityManager
                    .entityDestroyer
                    .deleteMessages(
                        olderThan: option.date,
                        for: conversation?.objectID
                    ) else {
                    DDLogNotice("[EntityDestroyer] no messages got deleted")
                    await MainActor.run {
                        deleteInProgress = false
                    }

                    return
                }
                
                DDLogNotice("[EntityDestroyer] \(count) messages deleted")
                await recalculate()
                FileUtility.cleanTemporaryDirectory(olderThan: nil)
            }
        }
        
        /// Delete files and media older than the specified option
        ///
        /// - Parameter option: The `OlderThanOption` that specifies the age of files and media to be deleted.
        func mediaDelete(_ option: OlderThanOption) {
            deleteInProgress = true
            Task {
                guard let count = await businessInjector
                    .backgroundEntityManager
                    .entityDestroyer
                    .deleteMedias(
                        olderThan: option.date,
                        for: conversation?.objectID
                    ) else {
                    DDLogNotice("[EntityDestroyer] media files deleted")
                    await MainActor.run {
                        deleteInProgress = false
                    }

                    return
                }
                
                DDLogNotice("[EntityDestroyer] \(count) media files deleted")
                await recalculate()
                FileUtility.cleanTemporaryDirectory(
                    olderThan: option == OlderThanOption.everything ? Date() : nil
                )
            }
        }
        
        // MARK: - Private Helper
        
        /// Recalculate the total number of messages and media within a set of conversations
        /// and also update the unread messages count.
        private func recalculate() async {
            let conversations = conversations(businessInjector.backgroundEntityManager)
            UnreadMessages(entityManager: businessInjector.backgroundEntityManager)
                .totalCount(doCalcUnreadMessagesCountOf: conversations)
        
            NotificationManager().updateUnreadMessagesCount()
            count(conversations)
            
            await MainActor.run {
                deleteInProgress = false
            }
        }
        
        /// Count the total number of messages and media within a set of conversations.
        /// Asynchronously update the `totalMessagesCount` and `totalMediaCount` properties.
        ///
        /// - Parameter conversations: The set of conversations to count.
        private func count(_ conversations: Set<Conversation>) {
            DispatchQueue.main.async {
                self.totalMessagesCount = 0
                self.totalMediaCount = 0
            }
            
            conversations.forEach { [weak self] in
                let fetcher = MessageFetcher(for: $0, with: businessInjector.backgroundEntityManager)
                DispatchQueue.main.async {
                    self?.totalMessagesCount += fetcher.count()
                    self?.totalMediaCount += fetcher.mediaCount()
                }
            }
        }
        
        /// Retrieves a set of conversations from the entity manager.
        /// If a specific conversation is provided, it returns a set with that single conversation.
        /// Otherwise, it fetches non-archived conversations from the entity manager.
        ///
        /// - Parameter entityManager: The EntityManager instance to fetch conversations from.
        /// - Returns: A set of `Conversation` objects.
        private func conversations(_ entityManager: EntityManager) -> Set<Conversation> {
            guard let conversation else {
                return Set(entityManager.entityFetcher.notArchivedConversations() as? [Conversation] ?? [])
            }
            
            return [conversation]
        }
    }
}
