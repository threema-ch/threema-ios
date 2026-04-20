import Foundation

public protocol RemoteSecretManagerProtocol: Sendable {
    /// Is remote secret active?
    ///
    /// Only use this for checks that show/hide certain info
    var isRemoteSecretEnabled: Bool { get }
    
    /// All functions to encrypt data with remote secret
    var crypto: RemoteSecretCryptoProtocol { get }
    
    /// Invoke check in the background if remote secret is still valid
    ///
    /// Errors are handled internally
    func checkValidity()
    
    /// Stop remote secret monitoring during reset of app
    ///
    /// - Warning: This only succeeds if the remote secret information is not in the keychain anymore
    func stopMonitoring() async
    
    func encryptDataIfNeeded(_ data: Data) -> Data

    func decryptDataIfNeeded(_ data: Data) -> Data
}

extension RemoteSecretManagerProtocol {
    
    // MARK: - Data
    
    public func encryptDataIfNeeded(_ data: Data) -> Data {
        if isRemoteSecretEnabled {
            crypto.encrypt(data)
        }
        else {
            data
        }
    }
    
    public func decryptDataIfNeeded(_ data: Data) -> Data {
        if isRemoteSecretEnabled {
            crypto.decrypt(data)
        }
        else {
            data
        }
    }
    
    public func encryptDataIfNeeded(_ data: Data?) -> Data? {
        guard let data else {
            return nil
        }
        
        let encryptedData: Data = encryptDataIfNeeded(data)
        return encryptedData
    }
    
    public func decryptDataIfNeeded(_ data: Data?) -> Data? {
        guard let data else {
            return nil
        }
        
        let decryptedData: Data = decryptDataIfNeeded(data)
        return decryptedData
    }
}
