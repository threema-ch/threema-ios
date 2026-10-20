import libthreemaSwift

extension MessageTextRevision {
    init(historyEntry: MessageHistoryEntryEntity) throws {
        guard let text = historyEntry.text else {
            throw MappingError.messageTextRevisionTextMissing
        }

        self.init(
            createdAt: historyEntry.editDate.millisecondsSince1970,
            message: MessageText(text: text)
        )
    }
}
