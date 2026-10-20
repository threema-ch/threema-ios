import libthreemaSwift

extension TextMessageState {
    init(textMessageEntity: TextMessageEntity) throws {
        let textMessageRevisions: [MessageTextRevision] =
            if let historyEntries = textMessageEntity.historyEntries {
                try historyEntries.map { try MessageTextRevision(historyEntry: $0) }
            }
            else {
                []
            }

        self.init(
            original: MessageText(text: textMessageEntity.text),
            revisions: textMessageRevisions
        )
    }
}
