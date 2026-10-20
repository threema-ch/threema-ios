import Foundation
import libthreemaSwift

final class ConversationProviderMock: libthreemaSwift.ConversationProvider {
    func addMessages(messages: [libthreemaSwift.MessageState]) throws {
        throw ProviderError.ContractViolation("Not implemented yet")
    }
    
    func setTypingIndicator(senderIdentity: LibthreemaThreemaID, isTyping: Bool) throws {
        throw ProviderError.ContractViolation("Not implemented yet")
    }
    
    func updateMessages(updates: [libthreemaSwift.MessageStateUpdate]) throws {
        throw ProviderError.ContractViolation("Not implemented yet")
    }
    
    func getManyMessages(conversationType: libthreemaSwift.ConversationType, batchIndex: UInt64) throws -> [
        libthreemaSwift.MessageState
    ] {
        throw ProviderError.ContractViolation("Not implemented yet")
    }

    // swiftformat:disable:next acronyms
    func getMessagesMetadata(conversationId: LibthreemaConversationID, messageIds: [LibthreemaMessageID]) throws -> [
        libthreemaSwift.MessageStateMetadata
    ] {
        throw ProviderError.ContractViolation("Not implemented yet")
    }

    // swiftformat:disable:next acronyms
    func isMessageMarkedUsed(senderIdentity: LibthreemaThreemaID, messageId: LibthreemaMessageID) throws -> Bool {
        throw ProviderError.ContractViolation("Not implemented yet")
    }
}
