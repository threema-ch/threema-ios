//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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

import Foundation

class ConversationStore: NSObject {
    
    private var entityManager: EntityManager
    
    @objc init(entityManager: EntityManager) {
        self.entityManager = entityManager
    }
    
    @objc override convenience init() {
        self.init(entityManager: EntityManager())
    }
    
    @objc public func unmarkAllPrivateConversations() {
        entityManager.performSyncBlockAndSafe {
            for conversation in self.entityManager.entityFetcher.privateConversations() {
                guard let conversation = conversation as? Conversation else {
                    continue
                }
                conversation.conversationCategory = .default
            }
        }
        UserSettings.shared().hidePrivateChats = false
    }
}
