//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

class ChatViewTypingIndicatorInformationProvider {
    // MARK: - Properties

    @Published var currentlyTyping: Bool
    
    // MARK: - Private Properties

    private var conversationIsTypingToken: NSKeyValueObservation?
    
    // MARK: - Lifecycle

    init(conversation: Conversation, entityManager: EntityManager) {
        self.currentlyTyping = conversation.typing.boolValue
        
        setupObservers(conversation: conversation)
    }
    
    // MARK: - Configuration Functions

    private func setupObservers(conversation: Conversation) {
        conversationIsTypingToken = conversation.observe(\.typing, options: .new) { [weak self] _, change in
            self?.currentlyTyping = change.newValue?.boolValue ?? false
        }
    }
}
