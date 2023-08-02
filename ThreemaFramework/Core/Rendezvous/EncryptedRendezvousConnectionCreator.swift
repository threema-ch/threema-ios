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

/// Wrapper to create an encrypted rendezvous connection and the crypto instance used
///
/// This mainly exists to make `RendezvousProtocol` testable
protocol EncryptedRendezvousConnectionCreator {
    /// Create a new encrypted rendezvous connection and rendezvous crypto from a rendezvous init
    ///
    /// The current implementation should use the provided WebSocket to create the connection
    ///
    /// - Parameter rendezvousInit: Rendezvous init to create connection from
    /// - Returns: A new encrypted rendezvous connection and a related rendezvous crypto instance
    /// - Throws: `EncryptedRendezvousConnectionCreatorError`
    func create(
        from rendezvousInit: Rendezvous_RendezvousInit
    ) throws -> (EncryptedRendezvousConnection, RendezvousCrypto)
}

enum EncryptedRendezvousConnectionCreatorError: Error {
    case invalidURL
}
