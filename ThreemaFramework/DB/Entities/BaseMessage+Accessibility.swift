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

public extension BaseMessage {
    /// Contains the sender and message type
    var accessibilitySenderAndMessageTypeText: String {
        
        var text = ""
        
        guard let message = self as? MessageAccessibility else {
            return text
        }
        // Sent by me, style: "Your Message"
        if message.isOwnMessage {
            text = String.localizedStringWithFormat(
                BundleUtil.localizedString(forKey: "accessibility_senderDescription_ownMessage"),
                message.accessibilityMessageTypeDescription
            )
        }
        // Sent by other, style: "Phil's Message"
        else if message.isGroupMessage {
            text = String.localizedStringWithFormat(
                BundleUtil.localizedString(forKey: "accessibility_senderDescription_otherMessage_group"),
                message.accessibilityMessageTypeDescription,
                // Quickfix: Sender should never be `nil` for a message in a group that is not my own
                message.sender?.displayName ?? ""
            )
        }
        // Sent by other, 1-to-1 conversation, style: "Message"
        else {
            text = message.accessibilityMessageTypeDescription
        }
        
        return "\(text)."
    }

    /// Contains the status and the message date.
    var accessibilityDateAndState: String {
        
        let dateString = DateFormatter.relativeLongStyleDateShortStyleTime(displayDate)
        
        if messageDisplayState == .none {
            return dateString
        }
        else {
            // Style: "Delivered, Today at 15:44."
            return "\(String.localizedStringWithFormat(messageDisplayState.accessibilityLabel(), dateString))."
        }
    }
    
    /// Contains the sender.
    var accessibilityMessageSender: String? {
        guard !isOwnMessage else {
            return BundleUtil.localizedString(forKey: "me")
        }
        
        if isGroupMessage {
            if let sender = sender {
                return sender.displayName
            }
            return nil
        }
        
        return conversation?.displayName
    }
}
