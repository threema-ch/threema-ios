//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

extension BaseMessage {
    /// Contains the sender and message type
    public var accessibilitySenderAndMessageTypeText: String {
        
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
    public var accessibilityDateAndState: String {
        
        let dateString = DateFormatter.relativeLongStyleDateShortStyleTime(displayDate)
        
        let resolvedString =
            if messageDisplayState == .none {
                if isGroupMessage, let groupReactionString = accessibilityGroupReactionState() {
                    "\(dateString), \(groupReactionString)."
                }
                else {
                    "\(dateString)."
                }
            }
            else {
                // Style: "Today at 15:44. Delivered."
                "\(dateString). \(messageDisplayState.accessibilityLabel)."
            }
        
        if let marked = messageMarkers?.star.boolValue, marked {
            return "\(resolvedString) \("marker_accessibility_label".localized)"
        }
        else {
            return resolvedString
        }
    }
    
    private func accessibilityGroupReactionState() -> String? {
        guard messageGroupReactionState != .none else {
            return nil
        }
        
        let myReactionString =
            if isMyReaction(.acknowledged) {
                "\("accessibility_status_group_acknowledged_my_reaction".localized), "
            }
            else if isMyReaction(.declined) {
                "\("accessibility_status_group_declined_my_reaction".localized), "
            }
            else {
                // We have to use a empty string when there is no own reaction. Otherwise the app will crash because a
                // string is missing for the localizedString placeholder
                ""
            }
        
        let ack = groupReactionsCount(of: .acknowledged)
        let dec = groupReactionsCount(of: .declined)
        if ack > 0, dec > 0 {
            let statusString = "accessibility_status_group_acknowledged_declined".localized
            return String.localizedStringWithFormat(statusString, ack, dec, myReactionString)
        }
        else if ack > 0 {
            let statusString = "accessibility_status_group_acknowledged".localized
            return String.localizedStringWithFormat(statusString, ack, myReactionString)
        }
        else if dec > 0 {
            let statusString = "accessibility_status_group_declined".localized
            return String.localizedStringWithFormat(statusString, dec, myReactionString)
        }
        
        return nil
    }
    
    /// Contains the sender.
    public var accessibilityMessageSender: String? {
        guard !isOwnMessage else {
            return BundleUtil.localizedString(forKey: "me")
        }
        
        if isGroupMessage {
            if let sender {
                return sender.displayName
            }
            return nil
        }
        
        return conversation?.displayName
    }
}
