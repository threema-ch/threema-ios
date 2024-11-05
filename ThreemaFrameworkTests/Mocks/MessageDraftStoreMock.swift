//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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
import ThreemaFramework

final class MessageDraftStoreMock: MessageDraftStoreProtocol {
    static var shared = MessageDraftStoreMock()
    
    var draftStore: [String: ThreemaFramework.Draft] = [:]
    
    func deleteDraft(for conversation: ConversationEntity) {
        if let storeKey = storeKey(conversation) {
            draftStore[storeKey] = nil
        }
    }
    
    func loadDraft(for conversation: ConversationEntity) -> ThreemaFramework.Draft? {
        if let storeKey = storeKey(conversation) {
            return draftStore[storeKey]
        }
        return nil
    }
    
    func saveDraft(_ draft: ThreemaFramework.Draft, for conversation: ConversationEntity) {
        if let storeKey = storeKey(conversation) {
            draftStore[storeKey] = draft
        }
    }
    
    func cleanupDrafts() {
        // no-op
    }
    
    func storeKey(_ conversation: ConversationEntity) -> String? {
        if conversation.isGroup, let hexStr = conversation.groupID?.hexString {
            let creator = conversation.contact?.identity ?? "*"
            return "\(creator)-\(hexStr)"
        }
        else {
            return conversation.contact?.identity
        }
    }
}
