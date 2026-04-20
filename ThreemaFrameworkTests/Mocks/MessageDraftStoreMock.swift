import Foundation

import ThreemaFramework

final class MessageDraftStoreMock: MessageDraftStoreProtocol {
    static var shared = MessageDraftStoreMock()
    
    var draftStore: [String: ThreemaFramework.Draft] = [:]
    
    func deleteDraft(for conversation: ConversationEntity) {
        if let storeKey = storeKey(conversation) {
            draftStore[storeKey] = nil
        }
    }
    
    func loadDraft(for conversation: ConversationEntity) -> ThreemaFramework.Draft? {
        if let storeKey = storeKey(conversation) {
            return draftStore[storeKey]
        }
        return nil
    }
    
    func saveDraft(_ draft: ThreemaFramework.Draft, for conversation: ConversationEntity) {
        if let storeKey = storeKey(conversation) {
            draftStore[storeKey] = draft
        }
    }
    
    func cleanupDrafts() {
        // no-op
    }
    
    func storeKey(_ conversation: ConversationEntity) -> String? {
        if conversation.isGroup, let hexStr = conversation.groupID?.hexString {
            let creator = conversation.contact?.identity ?? "*"
            return "\(creator)-\(hexStr)"
        }
        else {
            return conversation.contact?.identity
        }
    }
}
