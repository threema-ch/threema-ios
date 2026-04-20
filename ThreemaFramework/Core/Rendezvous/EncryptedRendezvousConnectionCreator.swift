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
