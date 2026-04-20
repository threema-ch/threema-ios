import Foundation

/// Helper for easier handling of NaCl in Swift
extension NaClCrypto {
    /// Representation of an NaCl key pair in Swift
    struct KeyPair {
        let publicKey: Data
        let privateKey: Data
    }
    
    enum Error: Swift.Error {
        case unableToGenerateKeyPair
    }
    
    /// Generate a new key pair
    /// - Returns: New key pair if successfully created
    /// - Throws: `NaClCrypto.Error` if generation fails
    func generateNewKeyPair() throws -> KeyPair {
        var publicKey: NSData?
        var privateKey: NSData?
        
        generateKeyPairPublicKey(&publicKey, secretKey: &privateKey)
        
        guard let publicKey, let privateKey else {
            throw Error.unableToGenerateKeyPair
        }
        
        return KeyPair(publicKey: Data(publicKey), privateKey: Data(privateKey))
    }
}
