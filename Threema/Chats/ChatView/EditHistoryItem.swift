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

/// Contains all the info of a message edit to be displayed in the message details
///
/// - Note: See caveat in `Hashable` implementation below
public struct EditHistoryItem {
    /// Text of the edit
    public let text: String
    /// Date the edit was made
    public let date: Date
    /// If the edit is the current one
    public let isCurrent: Bool
    
    public init(textMessage: TextMessageEntity) {
        self.text = textMessage.text
        self.date = textMessage.lastEditedAt ?? textMessage.displayDate
        self.isCurrent = true
    }
    
    public init(fileMessage: FileMessage) {
        self.text = fileMessage.caption ?? ""
        self.date = fileMessage.lastEditedAt ?? fileMessage.displayDate
        self.isCurrent = true
    }
    
    public init(messageHistoryEntry: MessageHistoryEntryEntity) {
        self.text = messageHistoryEntry.text ?? ""
        self.date = messageHistoryEntry.editDate
        self.isCurrent = false
    }
}

// MARK: - Equatable

extension EditHistoryItem: Equatable {
    public static func == (lhs: EditHistoryItem, rhs: EditHistoryItem) -> Bool {
        lhs.date == rhs.date && lhs.text == rhs.text && lhs.isCurrent == rhs.isCurrent
    }
}

// MARK: - Hashable

/// With our current approach in `ChatViewMessageDetailsViewController` to store `EditHistoryItem` inside the diffable
/// DS snapshot we must include `isCurrent` to not have outdated cells. Ideally we would only store a constant
/// identifier inside the snapshot and reconfigure the items if the data of `isCurrent` changes

extension EditHistoryItem: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(date)
        hasher.combine(text)
        hasher.combine(isCurrent)
    }
}
