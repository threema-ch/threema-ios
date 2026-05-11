import Keychain
import ThreemaFramework

// MARK: - BootstrapKeychainManagerProtocol

@MainActor
protocol BootstrapKeychainManagerProtocol {
    var isKeychainLocked: Bool { get }
    var hasRemoteSecret: Bool { get }
    func deleteAllItems() throws
}

// MARK: - BootstrapKeychainManagerAdapter

@MainActor
final class BootstrapKeychainManagerAdapter: BootstrapKeychainManagerProtocol {
    
    var isKeychainLocked: Bool {
        KeychainManager.isKeychainLocked
    }

    var hasRemoteSecret: Bool {
        KeychainManager.hasRemoteSecretInStore()
    }

    func deleteAllItems() throws {
        try KeychainManager.deleteAllItems()
    }
}
