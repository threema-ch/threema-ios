//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation
import PromiseKit

protocol NonceGuardProtocol: NonceGuardProtocolObjc {
    func isProcessed(nonce: Data) -> Bool
    func processed(nonce: Data) -> Promise<Void>
    func processed(nonces: [Data]) -> Promise<Void>
}

@objc
protocol NonceGuardProtocolObjc {
    func isProcessed(message: AbstractMessage) -> Bool
    @discardableResult
    func processed(message: AbstractMessage) throws -> AnyPromise
    @discardableResult
    func processed(boxedMessage: BoxedMessage) throws -> AnyPromise
}

/// A message with the same nonce should only be processed once.
///
/// This should prevent processing messages that malicious several times sent.
class NonceGuard: NSObject, NonceGuardProtocol {

    enum NonceGuardError: Int, Error {
        case messageNonceIsNil = 0
    }

    private let entityManager: EntityManager

    @objc
    required init(entityManager: EntityManager) {
        self.entityManager = entityManager
        super.init()
    }

    /// Check if incoming message is already processed.
    ///
    /// This checks on the main thread if the message nonce is stored in DB.
    /// - Parameters:
    ///    - message: Message to check
    /// - Returns: True nonce is already in DB
    @objc
    func isProcessed(message: AbstractMessage) -> Bool {
        guard let nonce = message.nonce, !nonce.isEmpty else {
            DDLogError("Message nonce is nil or empty")
            return true
        }

        return entityManager.isMessageNonceAlreadyInDB(nonce: nonce)
    }

    /// Check if message nonce is already processed.
    /// - Parameter nonce: Message nonce
    /// - Returns: True nonce is already in DB
    func isProcessed(nonce: Data) -> Bool {
        guard !nonce.isEmpty else {
            DDLogWarn("Message nonce is empty")
            return false
        }

        return entityManager.isMessageNonceAlreadyInDB(nonce: nonce)
    }

    /// Incoming message nonce will be stored in DB.
    ///
    /// - Parameter message: Store nonce of the Message
    /// - Throws: NonceGuardError.messageNonceIsNull
    @objc
    @discardableResult
    func processed(message: AbstractMessage) throws -> AnyPromise {
        guard let nonce = message.nonce else {
            throw NonceGuardError.messageNonceIsNil
        }

        return AnyPromise(processed(nonce: nonce))
    }

    /// Outgoing message nonce will be stored in DB.
    ///
    /// - Parameter message: Store nonce of the message
    /// - Throws: NonceGuardError.messageNonceIsNull
    @objc
    @discardableResult
    func processed(boxedMessage: BoxedMessage) throws -> AnyPromise {
        guard let nonce = boxedMessage.nonce else {
            throw NonceGuardError.messageNonceIsNil
        }

        return AnyPromise(processed(nonce: nonce))
    }

    /// Nonce will be stored in DB.
    /// - Parameter nonce: Message nonce
    func processed(nonce: Data) -> Promise<Void> {
        processed(nonces: [nonce])
    }

    /// Nonces will be stored in DB.
    /// - Parameter nonce: Message nonces
    func processed(nonces: [Data]) -> Promise<Void> {
        Promise { seal in
            Task {
                await self.entityManager.performSave {
                    for nonce in nonces {
                        guard !self.entityManager.isMessageNonceAlreadyInDB(nonce: nonce) else {
                            DDLogError("Nonce is already in DB")
                            continue
                        }
                        
                        self.entityManager.entityCreator.nonce(with: NonceHasher.hashedNonce(nonce))
                    }
                    seal.fulfill_()
                }
            }
        }
    }
}
