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
import ThreemaProtocols

protocol NonceGuardProtocol: NonceGuardProtocolObjc {
    func isProcessed(d2dIncomingMessage message: D2d_IncomingMessage) throws -> Bool
    func processed(nonce: Data) throws
    func processed(nonces: [Data]) throws
    func processed(message: AbstractMessage) throws
    func processed(boxedMessage: BoxedMessage) throws
    func processed(reflectedEnvelope message: D2d_Envelope) throws
}

@objc
protocol NonceGuardProtocolObjc {
    func isProcessed(message: AbstractMessage) -> Bool
}

/// A message with the same nonce should only be processed once.
///
/// This should prevent processing messages that malicious several times sent.
class NonceGuard: NSObject, NonceGuardProtocol {

    enum NonceGuardError: Error {
        case messageNonceIsNil(message: String)
        case hashingFailed
    }

    private let myIdentityStore: MyIdentityStoreProtocol
    private let entityManager: EntityManager

    @objc
    required init(myIdentityStore: MyIdentityStoreProtocol, entityManager: EntityManager) {
        self.myIdentityStore = myIdentityStore
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
            DDLogError("Nonce of message \(message.loggingDescription) is empty")
            return true
        }

        return entityManager.isMessageNonceAlreadyInDB(nonce: nonce)
    }

    /// Check if message nonce is already processed.
    /// - Parameter message: D2D incoming message
    /// - Returns: True nonce is already in DB
    func isProcessed(d2dIncomingMessage message: D2d_IncomingMessage) throws -> Bool {
        guard !message.nonce.isEmpty else {
            throw NonceGuardError.messageNonceIsNil(message: "Nonce of message \(message.loggingDescription) is empty")
        }

        return entityManager.isMessageNonceAlreadyInDB(nonce: message.nonce)
    }

    /// Incoming message nonce will be stored in DB.
    ///
    /// - Parameter message: Store nonce of the message
    /// - Throws: NonceGuardError.messageNonceIsNil
    func processed(message: AbstractMessage) throws {
        guard let nonce = message.nonce else {
            throw NonceGuardError
                .messageNonceIsNil(message: "Can't store nonce of message \(message.loggingDescription)")
        }

        try processed(nonce: nonce)
    }

    /// Outgoing message nonce will be stored in DB.
    ///
    /// - Parameter message: Store nonce of the message
    /// - Throws: NonceGuardError.messageNonceIsNil
    func processed(boxedMessage message: BoxedMessage) throws {
        guard let nonce = message.nonce else {
            throw NonceGuardError
                .messageNonceIsNil(message: "Can't store nonce of message \(message.loggingDescription)")
        }

        try processed(nonce: nonce)
    }

    /// Incoming reflected message nonce(s) will be stored in DB.
    ///
    /// - Parameter message: Store nonce of the reflected message
    /// - Throws: NonceGuardError.messageNonceIsNil
    func processed(reflectedEnvelope message: D2d_Envelope) throws {
        switch message.content {
        case let .incomingMessage(incomingMessage):
            try processed(nonce: incomingMessage.nonce)
        case let .outgoingMessage(outgoingMessage):
            try processed(nonces: outgoingMessage.nonces)
        default:
            throw NonceGuardError
                .messageNonceIsNil(message: "Can't store nonce of message \(message.loggingDescription)")
        }
    }

    /// Nonce will be stored in DB.
    /// - Parameter nonce: Message nonce
    func processed(nonce: Data) throws {
        try processed(nonces: [nonce])
    }

    /// Nonces will be stored in DB.
    /// - Parameter nonce: Message nonces
    func processed(nonces: [Data]) throws {
        try entityManager.performAndWaitSave {
            for nonce in nonces {
                guard !self.entityManager.isMessageNonceAlreadyInDB(nonce: nonce) else {
                    DDLogError("Nonce is already in DB")
                    continue
                }
                
                // As soon as hashing of a nonce fails we'll report an error and stop processing them
                guard let hashedNonce = NonceHasher.hashedNonce(nonce, myIdentityStore: self.myIdentityStore) else {
                    throw NonceGuardError.hashingFailed
                }
                
                self.entityManager.entityCreator.nonceEntity(with: hashedNonce)
            }
        }
    }
}
