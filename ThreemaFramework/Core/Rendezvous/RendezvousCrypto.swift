import Foundation

/// Cryptographic functions for Rendezvous protocol
protocol RendezvousCrypto: AnyObject {
    /// Encrypt the data
    /// - Parameter data: Data to encrypt
    /// - Returns: Encrypted data
    func encrypt(_ data: Data) throws -> Data
    
    /// Decrypt the data
    /// - Parameter data: Data to decrypt
    /// - Returns: Decrypted data
    func decrypt(_ data: Data) throws -> Data
    
    /// Switch to transport keys
    ///
    /// This should only be called once.
    ///
    /// - Parameters:
    ///   - localEphemeralTransportKeyPair: Local ephemeral transport key
    ///   - remotePublicEphemeralTransportKey: Remote public ephemeral transport key
    /// - Returns: Rendezvous path hash
    func switchToTransportKeys(
        localEphemeralTransportKeyPair: NaClCrypto.KeyPair,
        remotePublicEphemeralTransportKey: Data
    ) throws -> Data
}

enum RendezvousCryptoError: Swift.Error {
    case transportKeysAlreadyUsed
    case noAuthenticationKey
    case unableToDeriveKeys
}
