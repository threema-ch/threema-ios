import Keychain
import ThreemaFramework

// MARK: - BootstrapKeychainManagerProtocol

@MainActor
protocol BootstrapKeychainManagerProtocol {
    var hasRemoteSecret: Bool { get }
    func deleteAllItems() throws
}

// MARK: - BootstrapKeychainManagerAdapter

@MainActor
final class BootstrapKeychainManagerAdapter: BootstrapKeychainManagerProtocol {

    var hasRemoteSecret: Bool {
        KeychainManager.hasRemoteSecretInStore()
    }

    func deleteAllItems() throws {
        try KeychainManager.deleteAllItems()
    }
}
