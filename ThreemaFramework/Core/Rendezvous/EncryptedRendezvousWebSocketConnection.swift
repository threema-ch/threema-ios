//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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

/// An encrypted rendezvous connection on top of a WebSocket using `RendezvousCrypto` for encryption
final class EncryptedRendezvousWebSocketConnection: EncryptedRendezvousConnection {
    
    private let rendezvousWebSocketConnection: RendezvousWebSocketConnection
    private let rendezvousCrypto: RendezvousCrypto
    
    /// Create a new encrypted rendezvous WebSocket connection
    /// - Parameters:
    ///   - rendezvousWebSocketConnection: RendezvousWebSocketConnection to use for data transfer
    ///   - rendezvousCrypto: RendezvousCrypto to en- and decrypt the transferred data
    init(rendezvousWebSocketConnection: RendezvousWebSocketConnection, rendezvousCrypto: RendezvousCrypto) {
        self.rendezvousWebSocketConnection = rendezvousWebSocketConnection
        self.rendezvousCrypto = rendezvousCrypto
    }
    
    // MARK: - EncryptedRendezvousConnection

    func connect() throws {
        try rendezvousWebSocketConnection.connect()
    }
    
    func receive() async throws -> Data {
        let encryptedData = try await rendezvousWebSocketConnection.receive()
        return try rendezvousCrypto.decrypt(encryptedData)
    }
    
    func send(_ data: Data) async throws {
        let encryptedData = try rendezvousCrypto.encrypt(data)
        try await rendezvousWebSocketConnection.send(encryptedData)
    }
    
    func close() {
        rendezvousWebSocketConnection.close()
    }
}
