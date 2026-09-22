import libthreemaSwift

extension ConversationEntity.Visibility {
    init?(_ libthreemaConversationVisibility: LibthreemaConversationVisibility) {
        let visibility: ConversationEntity.Visibility =
            switch libthreemaConversationVisibility {
            case .archived: .archived
            case .normal: .default
            case .pinned: .pinned
            }
        self.init(rawValue: visibility.rawValue)
    }
}
