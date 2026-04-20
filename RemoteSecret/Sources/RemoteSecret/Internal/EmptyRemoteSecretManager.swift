import RemoteSecretProtocol

struct EmptyRemoteSecretManager: RemoteSecretManagerProtocol {
    
    let isRemoteSecretEnabled = false
    
    let crypto: any RemoteSecretCryptoProtocol = EmptyRemoteSecretCrypto()
    
    func checkValidity() {
        // no-op
    }
    
    func stopMonitoring() async {
        // no-op
    }
}
