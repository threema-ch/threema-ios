import Foundation
import PromiseKit

protocol MessageProcessorProtocol {
    func processIncoming(
        boxedMessage: BoxedMessage,
        receivedAfterInitialQueueSend: Bool,
        maxBytesToDecrypt: Int32,
        timeoutDownloadThumbnail: Int32
    ) -> Promise<AbstractMessageAndFSMessageInfo?>
}

enum MessageProcessorError: Error {
    /// An unknown message was received. If it was inside a FS session the session is passed on. This is needed to
    /// persist the updated session anyway.
    case unknownMessageType(session: DHSession?)
}

// MARK: - MessageProcessor + MessageProcessorProtocol

extension MessageProcessor: MessageProcessorProtocol {
    func processIncoming(
        boxedMessage: BoxedMessage,
        receivedAfterInitialQueueSend: Bool,
        maxBytesToDecrypt: Int32,
        timeoutDownloadThumbnail: Int32
    ) -> Promise<AbstractMessageAndFSMessageInfo?> {
        Promise { seal in
            processIncomingBoxedMessage(
                boxedMessage,
                receivedAfterInitialQueueSend: receivedAfterInitialQueueSend,
                maxBytesToDecrypt: maxBytesToDecrypt,
                timeoutDownloadThumbnail: timeoutDownloadThumbnail
            ) { abstractMessage, fsMessageInfoObject in
                if abstractMessage == nil, fsMessageInfoObject == nil {
                    seal.fulfill(nil)
                }
                else {
                    seal.fulfill(
                        AbstractMessageAndFSMessageInfo(
                            message: abstractMessage,
                            fsMessageInfo: fsMessageInfoObject
                        )
                    )
                }
            } onError: { error, fsMessageInfoObject in
                // We need to persist the session also for unknown messages. Thus we pass the FS session along with
                // the error
                if (error as NSError).code == ThreemaProtocolError.unknownMessageType.rawValue,
                   let fsMessageInfo = fsMessageInfoObject as? FSMessageInfo {
                    seal.reject(MessageProcessorError.unknownMessageType(session: fsMessageInfo.session))
                }
                else {
                    seal.reject(error)
                }
            }
        }
    }
}
