import Foundation

/// Various functions related to cryptography
public protocol GroupCallCryptoProtocol: Sendable {
    var symmetricNonceLength: Int32 { get }
    
    func symmetricEncryptData(_ plaintext: Data, withKey key: Data, nonce: Data) -> Data?
    func symmetricDecryptData(_ ciphertext: Data, withSecretKey key: Data, nonce: Data) -> Data?
    
    func randomBytes(of length: Int32) -> Data
    
    func generateKeyPair() throws -> (publicKey: Data, privateKey: Data)
    func encryptData(plaintext: Data, withPublicKey: Data, secretKey: Data, nonce: Data) -> Data?
    func decryptData(cipherText: Data, withKey: Data, signKey: Data, nonce: Data) -> Data?
    
    func sharedSecret(forPublicKey: Data, secretKey: Data) -> Data
    
    /// Returns the shared secret with a given Threema ID
    /// - Parameter identity: The Threema ID of the contact for which we want to calculate the shared secret with.
    /// The contact for this Threema ID must already be present in the database, the local ID.
    /// - Returns: Shared Secret with the Threema ID passed into `identity`.
    /// Nil if the contact for this identity does not exist or something went wrong
    func sharedSecret(with identity: String) -> Data?
    
    func padding() -> Data
}
