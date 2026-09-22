import Foundation
import libthreemaSwift

final class ConversationProvider: libthreemaSwift.ConversationProvider {
    func addMessages(messages: [libthreemaSwift.MessageState]) throws {
        // TODO: Implement
    }

    func setTypingIndicator(senderIdentity: LibthreemaThreemaID, isTyping: Bool) throws {
        // TODO: Implement
    }

    func updateMessages(updates: [libthreemaSwift.MessageStateUpdate]) throws {
        // TODO: Implement
    }

    func getManyMessages(conversationType: libthreemaSwift.ConversationType, batchIndex: UInt64) throws -> [
        libthreemaSwift.MessageState
    ] {
        [] // TODO: Implement
    }

    // swiftformat:disable:next acronyms
    func getMessagesMetadata(conversationId: LibthreemaConversationID, messageIds: [LibthreemaMessageID]) throws -> [
        libthreemaSwift.MessageStateMetadata
    ] {
        [] // TODO: Implement
    }

    // swiftformat:disable:next acronyms
    func isMessageMarkedUsed(senderIdentity: LibthreemaThreemaID, messageId: LibthreemaMessageID) throws -> Bool {
        false // TODO: Implement
    }
}
