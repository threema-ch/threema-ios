import Foundation
import ThreemaProtocols
@testable import ThreemaFramework

final class NonceGuardMock: NSObject, NonceGuardProtocol {
    var processedCalls = Set<Data>()

    func isProcessed(d2dIncomingMessage message: D2d_IncomingMessage) throws -> Bool {
        false
    }

    func processed(nonce: Data) {
        processedCalls(nonce: nonce)
    }

    func processed(nonces: [Data]) {
        for nonce in nonces {
            processedCalls(nonce: nonce)
        }
    }

    func isProcessed(message: AbstractMessage) -> Bool {
        false
    }

    func processed(message: AbstractMessage) throws {
        processedCalls(nonce: message.nonce)
    }

    func processed(boxedMessage: BoxedMessage) throws {
        processedCalls(nonce: boxedMessage.nonce)
    }

    func processed(reflectedEnvelope message: ThreemaProtocols.D2d_Envelope) throws {
        switch message.content {
        case let .incomingMessage(msg):
            processedCalls(nonce: msg.nonce)
        case let .outgoingMessage(msg):
            for nonce in msg.nonces {
                processedCalls(nonce: nonce)
            }
        default:
            // no-op
            break
        }
    }

    private func processedCalls(nonce: Data?) {
        if let nonce {
            processedCalls.insert(nonce)
        }
    }
}
