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

/// A rendezvous connection that transparently end-to-end encrypts all received and sent data
protocol EncryptedRendezvousConnection: AnyObject {
    
    /// Establish connection
    ///
    /// - Throws: `EncryptedRendezvousConnectionError.alreadyConnected` if a connection was established before
    func connect() throws
    
    /// Receive new data
    /// - Returns: Data received
    /// - Throws: `EncryptedRendezvousConnectionError` or error from connection
    func receive() async throws -> Data
    
    /// Encrypts and sends data
    /// - Parameter data: Data to encrypt and send
    /// - Throws: `EncryptedRendezvousConnectionError` or error from connection
    func send(_ data: Data) async throws
    
    /// Close connection
    ///
    /// After this only `connect()` is valid to be called
    func close()
}

enum EncryptedRendezvousConnectionError: Error {
    case noConnection
    case alreadyConnected
    case unknownDataReceived
    case receivedStringInsteadOfDataMessage
}
