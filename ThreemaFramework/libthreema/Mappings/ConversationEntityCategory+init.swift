import libthreemaSwift

extension ConversationEntity.Category {
    init?(_ libthreemaConversationCategory: LibthreemaConversationCategory?) {
        guard let libthreemaConversationCategory else {
            self.init(rawValue: ConversationEntity.Category.default.rawValue)
            return
        }

        let category: ConversationEntity.Category =
            switch libthreemaConversationCategory {
            case .default: .default
            case .protected: .private
            }
        self.init(rawValue: category.rawValue)
    }
}
