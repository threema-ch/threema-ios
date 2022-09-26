//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

extension MessageSender {
    @objc static func sendTypingIndicator(conversation: Conversation) -> Bool {
        guard !conversation.isGroup() else {
            return false
        }
        
        return sendTypingIndicator(contact: conversation.contact)
    }

    @objc static func sendTypingIndicator(contact: Contact?) -> Bool {
        guard let contact = contact else {
            return false
        }
        
        return (UserSettings.shared().sendTypingIndicator && contact.typingIndicator == .default) || contact
            .typingIndicator == .send
    }
    
    @objc static func sendReadReceipt(conversation: Conversation) -> Bool {
        guard !conversation.isGroup() else {
            return false
        }
        
        return sendReadReceipt(contact: conversation.contact)
    }

    @objc static func sendReadReceipt(contact: Contact?) -> Bool {
        guard let contact = contact else {
            return false
        }
        
        return (UserSettings.shared().sendReadReceipts && contact.readReceipt == .default) || contact
            .readReceipt == .send
    }
    
    public static func sanitizeAndSendText(_ rawText: String, in conversation: Conversation) {
        DispatchQueue.global(qos: .userInitiated).async {
            let trimmedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            let splitMessages = ThreemaUtilityObjC.getTrimmedMessages(trimmedText)
            
            if let splitMessages = splitMessages as? [String] {
                for splitMessage in splitMessages {
                    DispatchQueue.main.async {
                        MessageSender.sendMessage(
                            splitMessage,
                            in: conversation,
                            quickReply: false,
                            requestID: nil,
                            completion: nil
                        )
                    }
                }
            }
            else {
                DispatchQueue.main.async {
                    MessageSender.sendMessage(
                        trimmedText,
                        in: conversation,
                        quickReply: false,
                        requestID: nil,
                        completion: nil
                    )
                }
            }
        }
    }
}
