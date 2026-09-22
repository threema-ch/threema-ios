import libthreemaSwift

extension LibthreemaConversationCategory {
    init?(_ category: ConversationEntity.Category?) {
        guard let category else {
            self.init(rawValue: LibthreemaConversationCategory.default.rawValue)
            return
        }

        let libthreemaConversationCategory: LibthreemaConversationCategory =
            switch category {
            case .default: .default
            case .private: .protected
            }
        self.init(rawValue: libthreemaConversationCategory.rawValue)
    }
}
