import Foundation
import ThreemaProtocols

/// The default implementation of `EncryptedRendezvousConnectionCreator`
struct DefaultEncryptedRendezvousConnectionCreator: EncryptedRendezvousConnectionCreator {
    public func create(
        from rendezvousInit: Rendezvous_RendezvousInit
    ) throws -> (EncryptedRendezvousConnection, RendezvousCrypto) {
        guard let webSocketURL = URL(string: rendezvousInit.relayedWebSocket.url) else {
            throw EncryptedRendezvousConnectionCreatorError.invalidURL
        }
        
        // Create encrypted WebSocket
        let webSocketConnection = RendezvousWebSocketConnection(url: webSocketURL)
        let crypto = try DefaultRendezvousCrypto(
            role: .responder,
            authenticationKey: rendezvousInit.ak,
            pathID: rendezvousInit.relayedWebSocket.pathID
        )
        let encryptedWebSocketConnection = EncryptedRendezvousWebSocketConnection(
            rendezvousWebSocketConnection: webSocketConnection,
            rendezvousCrypto: crypto
        )
                
        return (encryptedWebSocketConnection, crypto)
    }
}
