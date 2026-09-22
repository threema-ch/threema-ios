import CocoaLumberjackSwift
import Keychain
import ThreemaEssentials
import ThreemaFramework

// MARK: - BootstrapKeychainManagerProtocol

@MainActor
protocol BootstrapKeychainManagerProtocol {
    var isKeychainLocked: Bool { get }
    var currentIdentity: ThreemaIdentity? { get }
    func deleteAllItems() throws
}

// MARK: - BootstrapKeychainManagerAdapter

@MainActor
final class BootstrapKeychainManagerAdapter: BootstrapKeychainManagerProtocol {
    
    var isKeychainLocked: Bool {
        KeychainManager.isKeychainLocked
    }

    var currentIdentity: ThreemaIdentity? {
        do {
            return try KeychainManager.loadThreemaIdentity()
        }
        catch {
            DDLogError("Failed to load Threema ID from keychain: \(error)")
            return nil
        }
    }

    func deleteAllItems() throws {
        try KeychainManager.deleteAllItems()
    }
}
