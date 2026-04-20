import Keychain
import RemoteSecretProtocol

/// Access all remote secret functionality after initialization
///
/// Use `RemoteSecretManagerCreator` to create this manager. This should only be done once during app launch or during
/// setup
final class RemoteSecretManager: RemoteSecretManagerProtocol {
    
    let isRemoteSecretEnabled = true
    
    let crypto: any RemoteSecretCryptoProtocol
    
    private let monitor: any RemoteSecretMonitorSwiftProtocol
    private let keychainManagerType: any KeychainManagerProtocol.Type

    init(
        crypto: any RemoteSecretCryptoProtocol,
        monitor: any RemoteSecretMonitorSwiftProtocol,
        keychainManagerType: any KeychainManagerProtocol.Type
    ) {
        self.crypto = crypto
        self.monitor = monitor
        self.keychainManagerType = keychainManagerType
    }
    
    func checkValidity() {
        Task.detached { [weak self] in
            await self?.monitor.runCheck()
        }
    }
    
    func stopMonitoring() async {
        // Ensure that the remote secret was already deleted from keychain
        let remoteSecret = try? keychainManagerType.loadRemoteSecret()
        guard remoteSecret == nil else {
            return
        }
        
        await monitor.stop()
    }
}
