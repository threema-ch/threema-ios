import Foundation
import PromiseKit
@testable import ThreemaFramework

final class MessageProcessorMock: NSObject, MessageProcessorProtocol {
    var processIncomingBoxedMessageCalls = [BoxedMessage]()
    
    var abstractMessage: AbstractMessage?
    var error: Error?

    func processIncoming(
        boxedMessage: BoxedMessage,
        receivedAfterInitialQueueSend: Bool,
        maxBytesToDecrypt: Int32,
        timeoutDownloadThumbnail: Int32
    ) -> Promise<AbstractMessageAndFSMessageInfo?> {
        processIncomingBoxedMessageCalls.append(boxedMessage)

        if let abstractMessage {
            return Promise { $0.fulfill(AbstractMessageAndFSMessageInfo(message: abstractMessage, fsMessageInfo: nil)) }
        }
        else if let error {
            return Promise(error: error)
        }
        return Promise { $0.fulfill(nil) }
    }
}
