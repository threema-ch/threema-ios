//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

import ThreemaMacros

public struct MessageActionFactory: Factory {
    
    private static let showConversationNotificationName =
        NSNotification.Name(rawValue: kNotificationShowConversation)
    
    private let action: () -> Void
    
    init(action: @escaping () -> Void) {
        self.action = action
    }
    
    public func make() -> UIContextualAction {
        let messageAction = UIContextualAction(
            style: .normal,
            title: #localize("message")
        ) { _, _, handler in
            action()
            handler(true)
        }
        
        messageAction.image = UIImage(resource: .threemaLockBubbleRightFill)
        messageAction.backgroundColor = .primary
        
        return messageAction
    }
}

extension MessageActionFactory {
    public static func make(for contact: Contact) -> UIContextualAction {
        MessageActionFactory {
            NotificationCenter.default.post(
                name: showConversationNotificationName,
                object: nil,
                userInfo: [
                    kKeyContactIdentity: contact.identity.rawValue,
                    kKeyForceCompose: true,
                ]
            )
        }.make()
    }
    
    public static func make(for conversationEntity: ConversationEntity) -> UIContextualAction {
        MessageActionFactory {
            NotificationCenter.default.post(
                name: showConversationNotificationName,
                object: nil,
                userInfo: [
                    kKeyConversation: conversationEntity,
                    kKeyForceCompose: true,
                ]
            )
        }.make()
    }
}
