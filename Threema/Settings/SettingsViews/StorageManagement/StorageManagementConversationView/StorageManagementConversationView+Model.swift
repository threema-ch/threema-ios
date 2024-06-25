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
        }
    
        // MARK: - General methods
        
        /// Refresh message and media count and update the ui
        @Sendable
        func load() async {
            await businessInjector.runInBackground { backgroundBusinessInjector in
                let conversations = self.conversations(backgroundBusinessInjector.entityManager)
                self.count(backgroundBusinessInjector.entityManager, conversations)
            }
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
                await businessInjector.runInBackground { [weak self] backgroundBusinessInjector in
                    guard let self else {
                        return
                    }
                    guard let count = await backgroundBusinessInjector
                        .entityManager
                        .entityDestroyer
                        .deleteMessages(
                            olderThan: option.date,
                            for: self.conversation?.objectID
                        ) else {
                        DDLogNotice("[EntityDestroyer] no messages got deleted")
                        await MainActor.run {
                            self.deleteInProgress = false
                        }

                        return
                    }

                    DDLogNotice("[EntityDestroyer] \(count) messages deleted")
                    self.recalculate(backgroundBusinessInjector)
                    FileUtility.shared.cleanTemporaryDirectory(olderThan: nil)

                    await MainActor.run {
                        self.deleteInProgress = false
                    }
                }
            }
        }
        
        /// Delete files and media older than the specified option
        ///
        /// - Parameter option: The `OlderThanOption` that specifies the age of files and media to be deleted.
        func mediaDelete(_ option: OlderThanOption) {
            deleteInProgress = true
            Task {
                await businessInjector.runInBackground { [weak self] backgroundBusinessInjector in
                    guard let self else {
                        return
                    }
                    guard let count = await backgroundBusinessInjector
                        .entityManager
                        .entityDestroyer
                        .deleteMedias(
                            olderThan: option.date,
                            for: self.conversation?.objectID
                        ) else {
                        DDLogNotice("[EntityDestroyer] media files deleted")
                        await MainActor.run {
                            self.deleteInProgress = false
                        }

                        return
                    }

                    DDLogNotice("[EntityDestroyer] \(count) media files deleted")
                    self.recalculate(backgroundBusinessInjector)
                    FileUtility.shared.cleanTemporaryDirectory(
                        olderThan: option == OlderThanOption.everything ? Date() : nil
                    )

                    await MainActor.run {
                        self.deleteInProgress = false
                    }
                }
            }
        }
        
        // MARK: - Private Helper
        
        /// Get the recalculated total number of messages and media within a set of conversations
        /// and also update the unread messages count.
        ///
        /// - Parameter backgroundBusinessInjector: `BusinessInjector` for background thread
        /// - Returns: Count of messages and media of the conversations
        private func recalculate(_ backgroundBusinessInjector: BusinessInjectorProtocol) {
            let conversations = conversations(backgroundBusinessInjector.entityManager)
            backgroundBusinessInjector.unreadMessages.totalCount(doCalcUnreadMessagesCountOf: conversations)
            NotificationManager(businessInjector: backgroundBusinessInjector).updateUnreadMessagesCount()
            count(backgroundBusinessInjector.entityManager, conversations)
        }
        
        /// Get total number of messages and media within a set of conversations.
        ///
        /// - Parameters:
        ///   - backgroundEntityManager: The EntityManager instance to count messages and media.
        ///   - conversations: The set of conversations to count.
        /// - Returns: Count of messages and media of the conversations
        private func count(
            _ backgroundEntityManager: EntityManager,
            _ conversations: Set<Conversation>
        ) {
            var messagesCount = 0
            var mediaCount = 0
            conversations.forEach {
                let fetcher = MessageFetcher(for: $0, with: backgroundEntityManager)
                messagesCount += fetcher.count()
                mediaCount += fetcher.mediaCount()
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }
                self.totalMessagesCount = messagesCount
                self.totalMediaCount = mediaCount
            }
        }
        
        /// Retrieves a set of conversations from the entity manager.
        /// If a specific conversation is provided, it returns a set with that single conversation.
        /// Otherwise, it fetches non-archived conversations from the entity manager.
        ///
        /// - Parameter backgroundEntityManager: The EntityManager instance to fetch conversations from.
        /// - Returns: A set of `Conversation` objects.
        private func conversations(_ backgroundEntityManager: EntityManager) -> Set<Conversation> {
            guard let conversation else {
                return Set(backgroundEntityManager.entityFetcher.notArchivedConversations() as? [Conversation] ?? [])
            }
            
            return [conversation]
        }
    }
}
