import Foundation
@testable import ThreemaFramework

final class MessageProcessorDelegateMock: NSObject, MessageProcessorDelegate {
    func beforeDecode() {
        // no-op
    }

    func changedManagedObjectID(_ objectID: NSManagedObjectID) {
        // no-op
    }

    func incomingMessageStarted(_ message: AbstractMessage) {
        // no-op
    }

    func incomingMessageChanged(_ message: AbstractMessage, baseMessageEntity baseMessageEntityObject: NSObject) {
        // no-op
    }

    func incomingMessageFinished(_ message: AbstractMessage) {
        // no-op
    }

    func incomingMessageFailed(_ message: BoxedMessage) {
        // no-op
    }
    
    func incomingAbstractMessageFailed(_ message: AbstractMessage) {
        // no-op
    }
    
    func incomingForwardSecurityMessageWithNoResultFinished(_ message: AbstractMessage) {
        // no-op
    }

    func readMessage(inConversations: Set<AnyHashable>?) {
        // no-op
    }

    func taskQueueEmpty() {
        // no-op
    }

    func chatQueueDry() {
        // no-op
    }

    func reflectionQueueDry() {
        // no-op
    }

    func processTypingIndicator(_ message: TypingIndicatorMessage) {
        // no-op
    }

    func processVoIPCall(
        _ message: NSObject,
        identity: String?,
        onCompletion: @escaping ((any MessageProcessorDelegate)?) -> Void,
        onError: @escaping (any Error, (any MessageProcessorDelegate)?) -> Void
    ) {
        // no-op
    }
}
