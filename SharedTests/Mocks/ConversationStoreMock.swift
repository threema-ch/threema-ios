//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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
@testable import ThreemaFramework

class ConversationStoreMock: NSObject, ConversationStoreProtocol, ConversationStoreInternalProtocol {
    // MARK: ConversationStoreProtocol

    func pin(_ conversation: Conversation) {
        // no-op
    }

    func unpin(_ conversation: Conversation) {
        // no-op
    }

    func makePrivate(_ conversation: Conversation) {
        // no-op
    }

    func makeNotPrivate(_ conversation: Conversation) {
        // no-op
    }

    func archive(_ conversation: Conversation) {
        // no-op
    }

    func unarchive(_ conversation: Conversation) {
        // no-op
    }

    // MARK: ConversationStoreInternalProtocol

    func updateConversation(withContact syncContact: ThreemaFramework.Sync_Contact) {
        // no-op
    }

    func updateConversation(withGroup syncGroup: ThreemaFramework.Sync_Group) {
        // no-op
    }
}
