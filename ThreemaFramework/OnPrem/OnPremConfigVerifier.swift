import CocoaLumberjackSwift
import Ed25519
import Foundation

protocol OnPremConfigVerifierProtocol {
    func verify(oppfData: String) throws -> OnPremConfig
}

final class OnPremConfigVerifier: OnPremConfigVerifierProtocol {
    private let trustedPublicKeys: [String]?

    /// - Parameter publicKey: The public key in Base64
    init(trustedPublicKeys: [String]?) {
        self.trustedPublicKeys = trustedPublicKeys
    }
    
    /// - Parameter oppfData: The OPPF data to verify
    ///
    /// - Returns: the resulting JSON document
    func verify(oppfData: String) throws -> OnPremConfig {
        guard let trustedPublicKeys else {
            DDLogError("Missing config public keys")
            throw OnPremConfigError.missingPublicKeys
        }

        let publicKeys = try trustedPublicKeys.map { publicKey -> Data in
            guard let key = Data(base64Encoded: publicKey) else {
                throw OnPremConfigError.invalidPublicKey
            }
            return key
        }

        // Extract signature
        guard let lfIndex = oppfData.lastIndex(of: "\n") else {
            throw OnPremConfigError.badInputOppfData
        }
        
        let jsonData = oppfData[..<lfIndex]
        guard let sig = Data(base64Encoded: String(oppfData[oppfData.index(lfIndex, offsetBy: 1)...])) else {
            throw OnPremConfigError.badInputOppfData
        }
        
        // Verify signature
        var valid = false
        var chosenPublicKey: Data?
        for publicKey in publicKeys {
            let edPublicKey = try PublicKey([UInt8](publicKey))
            if try edPublicKey.verify(signature: [UInt8](sig), message: [UInt8](Data(jsonData.utf8))) {
                valid = true
                chosenPublicKey = publicKey
                break
            }
        }
        
        if !valid {
            throw OnPremConfigError.badSignature
        }
        
        // Parse config
        let decoder = JSONDecoder()
        let dateFormat = Foundation.DateFormatter()
        dateFormat.timeZone = .current
        dateFormat.dateFormat = "yyyy-MM-dd"
        decoder.dateDecodingStrategy = .formatted(dateFormat)
        let config = try decoder.decode(OnPremConfig.self, from: Data(jsonData.utf8))
        
        // Check that the version is supported
        if config.version != "1.0" {
            throw OnPremConfigError.unsupportedVersion
        }
        
        // Check that the signature key matches
        if config.signatureKey != chosenPublicKey {
            throw OnPremConfigError.signatureKeyMismatch
        }
        
        // Check that the license is not expired (add one day to account for the fact
        // that the expiration date is defined as "not valid after")
        let expires = config.license.expires + 86400
        if expires < Date() {
            throw OnPremConfigError.licenseExpired
        }
        
        return config
    }
}
