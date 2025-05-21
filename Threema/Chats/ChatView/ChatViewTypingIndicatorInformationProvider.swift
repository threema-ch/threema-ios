//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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
import ThreemaMacros

protocol ChatViewTypingIndicatorInformationProviderProtocol {
    var currentlyTypingPublisher: Published<Bool>.Publisher { get }
}

class ChatViewTypingIndicatorInformationProvider: ChatViewTypingIndicatorInformationProviderProtocol {
    // MARK: - Properties

    var currentlyTypingPublisher: Published<Bool>.Publisher { $currentlyTyping }
    
    // MARK: - Private Properties

    @Published private var currentlyTyping: Bool
    
    private var conversationIsTypingToken: NSKeyValueObservation?
    
    // MARK: - Lifecycle

    init(conversation: ConversationEntity, entityManager: EntityManager) {
        self.currentlyTyping = conversation.typing.boolValue
        
        setupObservers(conversation: conversation)
    }
    
    // MARK: - Configuration Functions

    private func setupObservers(conversation: ConversationEntity) {
        conversationIsTypingToken = conversation.observe(\.typing, options: .new) { [weak self] _, change in
            self?.currentlyTyping = change.newValue?.boolValue ?? false
            self?.accessibilityTyping(conversation: conversation)
        }
    }
    
    /// Announce the typing indicator for accessibility if the current chat is the top view controller.
    /// - Parameter conversation: Conversation
    private func accessibilityTyping(conversation: ConversationEntity) {
        guard let topViewController = AppDelegate.shared().currentTopViewController() as? MainTabBarController,
              topViewController.isChatTopViewController() else {
            return
        }
        
        // Inform with accessibility notification post when user is typing or stops typing
        guard let displayName = conversation.contact?.displayName else {
            // If there is no display name, it will use the string 'Contact'
            let messageKey = currentlyTyping ? #localize("accessibility_senderDescription_typing") :
                #localize("accessibility_senderDescription_stopped_typing")
            UIAccessibility.post(
                notification: UIAccessibility.Notification.announcement,
                argument: messageKey
            )
            return
        }
        
        let messageKey = currentlyTyping ? #localize("accessibility_senderDescription_contact_typing") :
            #localize("accessibility_senderDescription_contact_stopped_typing")
        let message = String(format: messageKey, displayName)
        DispatchQueue.main.async {
            UIAccessibility.post(
                notification: UIAccessibility.Notification.announcement,
                argument: message
            )
        }
    }
}
