import libthreemaSwift

extension LibthreemaConversationVisibility {
    init?(_ visibility: ConversationEntity.Visibility?) {
        guard let visibility else {
            self.init(rawValue: LibthreemaConversationVisibility.normal.rawValue)
            return
        }

        let libthreemaConversationVisibility: LibthreemaConversationVisibility =
            switch visibility {
            case .archived: .archived
            case .default: .normal
            case .pinned: .pinned
            }
        self.init(rawValue: libthreemaConversationVisibility.rawValue)
    }
}
