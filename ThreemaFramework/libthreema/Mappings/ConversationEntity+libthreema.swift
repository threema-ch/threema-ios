import libthreemaSwift

extension ConversationEntity {
    func update(with contact: LibthreemaContact) throws {
        guard let category = ConversationEntity.Category(contact.conversationCategory) else {
            throw MappingError.conversationCategory
        }

        guard let visibility = ConversationEntity.Visibility(contact.conversationVisibility) else {
            throw MappingError.conversationVisibility
        }

        self.category = NSNumber(value: category.rawValue)
        lastUpdate = contact.lastUpdateAt?.date
        self.visibility = NSNumber(value: visibility.rawValue)
    }

    func update(with contact: LibthreemaContactUpdate) throws {
        if let value = contact.conversationCategory {
            guard let category = ConversationEntity.Category(value) else {
                throw MappingError.conversationCategory
            }

            self.category = NSNumber(value: category.rawValue)
        }
        if let value = contact.conversationVisibility {
            guard let visibility = ConversationEntity.Visibility(value) else {
                throw MappingError.conversationVisibility
            }

            self.visibility = NSNumber(value: visibility.rawValue)
        }
    }
}
