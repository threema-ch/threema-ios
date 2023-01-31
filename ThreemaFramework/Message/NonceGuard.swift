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

/// A message with the same nonce should only be processed once.
///
/// This should prevent processing messages that malicious several times sent
/// or by a race condition between the App and the Notification Extension.
class NonceGuard: NSObject {

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
    /// Reflected messages are not yet checked, because the message nonce is missing at the moment (see IOS-3096).
    /// - Parameters:
    ///    - message: Message to check
    ///    - isReflected: Indicates a reflected message
    @objc
    func isProcessed(message: AbstractMessage, isReflected: Bool) -> Bool {
        if isReflected, message.nonce == nil {
            DDLogWarn("If message nonce is nil for a reflected message always return false")
            return false
        }

        guard let nonce = message.nonce else {
            DDLogError("Message nonce is nil")
            return true
        }

        return entityManager.isMessageNonceAlreadyInDB(nonce: nonce)
    }

    /// Incoming message nonce will be stored in DB.
    ///
    /// Throws no exception is message nonce nil for reflected message (see IOS-3096).
    /// - Parameters:
    ///    - message: Message to store
    ///    - isReflected: Indicates a reflected message
    /// - Throws: NonceGuardError.messageNonceIsNull (if `isReflected` is `false`)
    @objc
    @discardableResult
    func processed(message: AbstractMessage, isReflected: Bool) throws -> AnyPromise {
        if isReflected, message.nonce == nil {
            DDLogWarn("If message nonce is nil for reflected message will not throw an error")
            return AnyPromise()
        }

        guard let nonce = message.nonce else {
            throw NonceGuardError.messageNonceIsNil
        }

        guard !isProcessed(message: message, isReflected: isReflected) else {
            return AnyPromise()
        }

        return AnyPromise(processed(nonce: nonce))
    }

    /// Outgoing message nonce will be stored in DB.
    ///
    /// - Parameters:
    ///    - message: Message to store
    /// - Throws: NonceGuardError.messageNonceIsNull
    @objc
    @discardableResult
    func processed(boxedMessage: BoxedMessage) throws -> AnyPromise {
        guard let nonce = boxedMessage.nonce else {
            throw NonceGuardError.messageNonceIsNil
        }

        guard !entityManager.isMessageNonceAlreadyInDB(nonce: nonce) else {
            return AnyPromise()
        }

        return AnyPromise(processed(nonce: nonce))
    }

    private func processed(nonce: Data) -> Promise<Void> {
        Promise { seal in
            self.entityManager.performAsyncBlockAndSafe {
                self.entityManager.entityCreator.nonce(with: NonceHasher.hashedNonce(nonce))
                seal.fulfill_()
            }
        }
    }
}
