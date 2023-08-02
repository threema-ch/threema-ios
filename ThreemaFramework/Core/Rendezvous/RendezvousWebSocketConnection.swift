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

import CocoaLumberjackSwift
import Foundation

/// Rendezvous WebSocket connection based on `URLSessionWebSocketTask`
///
/// The send and received data is mapped to and from `TransportFrames.Frame`
final class RendezvousWebSocketConnection {
    
    // 1 MB
    private let maxChunkSize = 1024 * 1024
    
    private let url: URL
    
    /// Connected task. This has to be `nil` if we're not connected
    private var webSocketTask: URLSessionWebSocketTask?
    
    /// Create new connection using the provided url
    /// - Parameter url: WebSocket URL used for this connection
    init(url: URL) {
        self.url = url
    }

    func connect() throws {
        guard webSocketTask == nil else {
            throw EncryptedRendezvousConnectionError.alreadyConnected
        }
        
        webSocketTask = URLSessionManager.shared.storedSession(
            for: nil,
            createAsBackgroundSession: false
        ).webSocketTask(with: url)
        
        webSocketTask?.resume()
    }
    
    func send(_ data: Data) async throws {
        guard let webSocketTask else {
            throw EncryptedRendezvousConnectionError.noConnection
        }
        
        do {
            let chunks = try TransportFrame.chunkedFrame(from: data, maxChunkSize: maxChunkSize)
            for chunk in chunks {
                try await webSocketTask.send(.data(chunk))
            }
        }
        catch {
            DDLogError("Unable to write to WebSocket: \(error)")
            throw error
        }
    }
    
    func receive() async throws -> Data {
        guard let webSocketTask else {
            throw EncryptedRendezvousConnectionError.noConnection
        }
        
        do {
            // This will only return if any data is send over the connection or the connections gets closed
            let message = try await webSocketTask.receive()
            
            switch message {
            case let .data(frame):
                return try TransportFrame.data(from: frame)
            case .string:
                throw EncryptedRendezvousConnectionError.receivedStringInsteadOfDataMessage
            @unknown default:
                throw EncryptedRendezvousConnectionError.unknownDataReceived
            }
        }
        catch {
            DDLogError("Unable to read from WebSocket: \(error)")
            throw error
        }
    }
    
    func close() {
        guard let webSocketTask else {
            DDLogNotice("No WebSocket task to close")
            return
        }
        
        webSocketTask.cancel(with: .normalClosure, reason: nil)
        self.webSocketTask = nil
    }
}
