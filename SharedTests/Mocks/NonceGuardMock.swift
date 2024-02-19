//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import Foundation
import ThreemaProtocols
@testable import ThreemaFramework

class NonceGuardMock: NSObject, NonceGuardProtocol {
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
