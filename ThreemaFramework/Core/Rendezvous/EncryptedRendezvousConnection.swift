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
