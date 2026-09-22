import CocoaLumberjackSwift
import Foundation
import Keychain
import ThreemaEssentials
import ThreemaFramework

@MainActor
final class BootstrapIdentityService {

    private let bootstrapIdentityStore: BootstrapIdentityStoreProtocol
    private let bootstrapIdentityCreator: BootstrapIdentityCreatorProtocol
    private let bootstrapKeychainManager: BootstrapKeychainManagerProtocol
    private let bootstrapBackupStore: BootstrapBackupStoreProtocol
    private let appLaunchManager: AppLaunchManagerProtocol
    
    var currentIdentity: ThreemaIdentity? {
        bootstrapKeychainManager.currentIdentity
    }
    
    var hasDataOnDevice: Bool {
        appLaunchManager.hasPreexistingDatabaseFile
    }
    
    var isDatabaseEncrypted: Bool {
        appLaunchManager.isDatabaseEncrypted
    }
    
    init(
        bootstrapIdentityStore: BootstrapIdentityStoreProtocol,
        bootstrapIdentityCreator: BootstrapIdentityCreatorProtocol,
        bootstrapKeychainManager: BootstrapKeychainManagerProtocol,
        bootstrapBackupStore: BootstrapBackupStoreProtocol,
        appLaunchManager: AppLaunchManagerProtocol
    ) {
        self.bootstrapIdentityStore = bootstrapIdentityStore
        self.bootstrapIdentityCreator = bootstrapIdentityCreator
        self.bootstrapKeychainManager = bootstrapKeychainManager
        self.bootstrapBackupStore = bootstrapBackupStore
        self.appLaunchManager = appLaunchManager
    }

    func checkForIDBackup() -> String? {
        guard
            let backupData = bootstrapBackupStore.loadIdentityBackup(),
            bootstrapBackupStore.isValidBackupFormat(backupData)
        else {
            return nil
        }

        return backupData
    }

    func deleteAllKeychainItems() {
        do {
            try bootstrapKeychainManager.deleteAllItems()
        }
        catch {
            DDLogError("Failed to delete keychain items: \(error)")
        }
    }

    func generateKeyPair(from seed: Data) {
        bootstrapIdentityCreator.generateKeyPair(withSeed: seed)
    }

    func createIdentity() async -> BootstrapIdentityCreationResult {
        await bootstrapIdentityCreator.createIdentity()
    }
}
