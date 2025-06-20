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

extension BaseMessageEntity {
    /// Contains the sender and message type
    public var accessibilitySenderAndMessageTypeText: String {
        
        var text = ""
        
        guard let message = self as? MessageAccessibility else {
            return text
        }
        // Sent by me, style: "Your Message"
        if message.isOwnMessage {
            text = String.localizedStringWithFormat(
                #localize("accessibility_senderDescription_ownMessage"),
                message.accessibilityMessageTypeDescription
            )
        }
        // Sent by other, style: "Phil's Message"
        else if message.isGroupMessage {
            text = String.localizedStringWithFormat(
                #localize("accessibility_senderDescription_otherMessage_group"),
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
    public var accessibilityDateAndState: String {
        
        let dateString = DateFormatter.relativeLongStyleDateShortStyleTime(displayDate)
        var resolvedString = ""
        if messageDisplayState == .none {
            resolvedString = dateString
        }
        else {
            // Style: "Delivered, Today at 15:44."
            resolvedString = "\(String.localizedStringWithFormat(messageDisplayState.accessibilityLabel, dateString))."
        }
        
        if let marked = messageMarkers?.star.boolValue, marked {
            resolvedString += #localize("marker_accessibility_label")
        }
        
        return resolvedString
    }
    
    /// Contains the sender.
    public var accessibilityMessageSender: String? {
        guard !isOwnMessage else {
            return #localize("me")
        }
        
        if isGroupMessage {
            if let sender {
                return sender.displayName
            }
            return nil
        }
        
        return conversation.displayName
    }
}
