import Foundation

/// Contains all the info of a message edit to be displayed in the message details
///
/// - Note: See caveat in `Hashable` implementation below
public struct EditHistoryItem {
    // Internal ID to keep history items unique if all other properties are identical
    private let id: String
    
    /// Text of the edit
    public let text: String
    /// Date the edit was made
    public let date: Date
    /// If the edit is the current one
    public let isCurrent: Bool
    
    public init(textMessage: TextMessageEntity) {
        self.id = textMessage.objectID.uriRepresentation().absoluteString
        self.text = textMessage.text
        self.date = textMessage.lastEditedAt ?? textMessage.displayDate
        self.isCurrent = true
    }
    
    public init(fileMessage: FileMessage) {
        self.id = fileMessage.objectID.uriRepresentation().absoluteString
        self.text = fileMessage.caption ?? ""
        self.date = fileMessage.lastEditedAt ?? fileMessage.displayDate
        self.isCurrent = true
    }
    
    public init(messageHistoryEntry: MessageHistoryEntryEntity) {
        self.id = messageHistoryEntry.objectID.uriRepresentation().absoluteString
        self.text = messageHistoryEntry.text ?? ""
        self.date = messageHistoryEntry.editDate
        self.isCurrent = false
    }
}

// MARK: - Equatable

extension EditHistoryItem: Equatable {
    public static func == (lhs: EditHistoryItem, rhs: EditHistoryItem) -> Bool {
        lhs.id == rhs.id && lhs.date == rhs.date && lhs.text == rhs.text && lhs.isCurrent == rhs.isCurrent
    }
}

// MARK: - Hashable

/// With our current approach in `ChatViewMessageDetailsViewController` to store `EditHistoryItem` inside the diffable
/// DS snapshot we must include `isCurrent` to not have outdated cells. Ideally we would only store a constant
/// identifier inside the snapshot and reconfigure the items if the data of `isCurrent` changes

extension EditHistoryItem: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(date)
        hasher.combine(text)
        hasher.combine(isCurrent)
    }
}
