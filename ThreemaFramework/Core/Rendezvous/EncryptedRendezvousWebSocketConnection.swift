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
