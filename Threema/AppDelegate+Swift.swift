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

import BackgroundTasks
import Foundation
import Intents

extension AppDelegate {
    // MARK: - Intents
    
    static var keyWindow: UIWindow? {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow })
        else {
            return nil
        }
        return window
    }
    
    /// Used to handle Siri suggestions in widgets, search or on lock screen
    @objc func handleINSendMessageIntent(userActivity: NSUserActivity) -> Bool {
        guard let interaction = userActivity.interaction else {
            return false
        }
        
        guard let intent = interaction.intent as? INSendMessageIntent else {
            return false
        }
        
        if let selectedIdentity = intent.conversationIdentifier as String? {
            if let managedObject = EntityManager().entityFetcher.existingObject(withIDString: selectedIdentity) {
                if let contact = managedObject as? ContactEntity,
                   let conversation = EntityManager().entityFetcher.conversation(for: contact) {
                    NotificationCenter.default.post(
                        name: NSNotification.Name(rawValue: kNotificationShowConversation),
                        object: nil,
                        userInfo: [
                            kKeyConversation: conversation,
                            kKeyForceCompose: true,
                        ]
                    )
                    return true
                }
                else if let group = managedObject as? ConversationEntity {
                    NotificationCenter.default.post(
                        name: NSNotification.Name(rawValue: kNotificationShowConversation),
                        object: nil,
                        userInfo: [
                            kKeyConversation: group,
                            kKeyForceCompose: true,
                        ]
                    )
                    return true
                }
            }
        }
        
        if let recipient = intent.recipients?.first as? INPerson,
           let identity = recipient.personHandle?.value,
           identity.count == kIdentityLen,
           let singleConversation = EntityManager().entityFetcher.conversationEntity(forIdentity: identity) {
            NotificationCenter.default.post(
                name: NSNotification.Name(rawValue: kNotificationShowConversation),
                object: nil,
                userInfo: [
                    kKeyConversation: singleConversation,
                    kKeyForceCompose: true,
                ]
            )
            return true
        }
        
        return false
    }
}
