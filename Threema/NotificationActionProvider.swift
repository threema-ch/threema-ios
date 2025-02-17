//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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

@objc class NotificationActionProvider: NSObject {
    
    // MARK: - Identifiers

    enum Action: String {
        case replyAction = "REPLY_MESSAGE"
        case callBackAction = "CALLBACK"
        
        case thumbsUpEmojiAction = "THUMBSUPEMOJI"
        case thumbsDownEmojiAction = "THUMBSDOWNEMOJI"
        case heartEmojiAction = "HEARTEMOJI"
        case laughterEmojiAction = "LAUGHTEREMOJI"
        case cryingEmojiAction = "CRYINGEMOJI"
        case foldedHandsEmojiAction = "FOLDEDHANDSEMOJI"
        
        private var title: String {
            switch self {
            case .replyAction:
                #localize("decryption_push_reply")
            case .callBackAction:
                #localize("call_back")
            case .thumbsUpEmojiAction:
                ReactionsManager.preferredEmojiVariant(for: .thumbsUpSign).rawValue
            case .thumbsDownEmojiAction:
                ReactionsManager.preferredEmojiVariant(for: .thumbsDownSign).rawValue
            case .heartEmojiAction:
                Emoji.heavyBlackHeart.rawValue
            case .laughterEmojiAction:
                Emoji.faceWithTearsOfJoy.rawValue
            case .cryingEmojiAction:
                Emoji.cryingFace.rawValue
            case .foldedHandsEmojiAction:
                ReactionsManager.preferredEmojiVariant(for: .personWithFoldedHands).rawValue
            }
        }
        
        private var options: UNNotificationActionOptions {
            switch self {
            case .replyAction, .thumbsUpEmojiAction, .thumbsDownEmojiAction, .heartEmojiAction, .laughterEmojiAction,
                 .cryingEmojiAction, .foldedHandsEmojiAction:
                .authenticationRequired
            case .callBackAction:
                .foreground
            }
        }

        private var icon: UNNotificationActionIcon? {
            switch self {
            case .replyAction:
                UNNotificationActionIcon(systemImageName: "arrowshape.turn.up.left")
            case .thumbsUpEmojiAction, .thumbsDownEmojiAction, .heartEmojiAction, .laughterEmojiAction,
                 .cryingEmojiAction, .foldedHandsEmojiAction:
                nil
            case .callBackAction:
                UNNotificationActionIcon(systemImageName: "phone")
            }
        }
        
        var action: UNNotificationAction {
            switch self {
            case .replyAction:
                UNTextInputNotificationAction(
                    identifier: rawValue,
                    title: title,
                    options: options,
                    icon: icon,
                    textInputButtonTitle: #localize("send"),
                    textInputPlaceholder: #localize("decryption_push_placeholder")
                )
            case .thumbsUpEmojiAction, .thumbsDownEmojiAction, .heartEmojiAction, .laughterEmojiAction,
                 .cryingEmojiAction, .foldedHandsEmojiAction, .callBackAction:
                UNNotificationAction(
                    identifier: rawValue,
                    title: title,
                    options: options,
                    icon: icon
                )
            }
        }
        
        static func isEmojiAction(identifier: String) -> Bool {
            guard let action = Action(rawValue: identifier) else {
                return false
            }
            return switch action {
            case .replyAction, .callBackAction:
                false
            case .thumbsUpEmojiAction, .thumbsDownEmojiAction, .heartEmojiAction, .laughterEmojiAction,
                 .cryingEmojiAction, .foldedHandsEmojiAction:
                true
            }
        }
        
        static func emoji(for identifier: String) -> EmojiVariant? {
            guard let action = Action(rawValue: identifier) else {
                return nil
            }
            
            switch action {
            case .replyAction, .callBackAction:
                return nil
            case .thumbsUpEmojiAction:
                return ReactionsManager.preferredEmojiVariant(for: .thumbsUpSign)
            case .thumbsDownEmojiAction:
                return ReactionsManager.preferredEmojiVariant(for: .thumbsDownSign)
            case .heartEmojiAction:
                return EmojiVariant(base: .heavyBlackHeart, skintone: nil)
            case .laughterEmojiAction:
                return EmojiVariant(base: .faceWithTearsOfJoy, skintone: nil)
            case .cryingEmojiAction:
                return EmojiVariant(base: .cryingFace, skintone: nil)
            case .foldedHandsEmojiAction:
                return ReactionsManager.preferredEmojiVariant(for: .personWithFoldedHands)
            }
        }
    }
    
    enum Category: String {
        case singleCategory = "SINGLE"
        case groupCategory = "GROUP"
        case callCategory = "CALL"
                
        private var actions: [UNNotificationAction] {
            switch self {
            case .singleCategory, .groupCategory:
                [
                    Action.replyAction.action,
                    Action.thumbsUpEmojiAction.action,
                    Action.thumbsDownEmojiAction.action,
                    Action.heartEmojiAction.action,
                    Action.laughterEmojiAction.action,
                    Action.cryingEmojiAction.action,
                    Action.foldedHandsEmojiAction.action,
                ]
                
            case .callCategory:
                [Action.replyAction.action, Action.callBackAction.action]
            }
        }
        
        var category: UNNotificationCategory {
            UNNotificationCategory(identifier: rawValue, actions: actions, intentIdentifiers: [])
        }
    }
    
    @objc lazy var defaultCategories: Set<UNNotificationCategory> = [
        Category.callCategory.category,
        Category.singleCategory.category,
        Category.groupCategory.category,
    ]
}
