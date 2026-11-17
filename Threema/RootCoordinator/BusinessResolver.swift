import CocoaLumberjackSwift
import Keychain
import RemoteSecretProtocol
import ThreemaEssentials

/// Central point to run migrations, sync Keychain and create business injector
///
/// Shared between app launch and onboarding
protocol BusinessResolving {
    
    /// Run Core Data and app migrations, sync Keychain with in-memory stores and create business injector
    ///
    /// - Parameters:
    ///   - remoteSecretManager: Remote secret manager set for global usage
    ///   - keychainManager: Needed for keychain access and synchronization
    ///
    /// - Returns: Completely initialized business injector
    func resolve(
        with remoteSecretManager: any RemoteSecretManagerProtocol,
        and keychainManager: any KeychainManagerProtocol
    ) async throws -> any BusinessInjectorProtocol
}

final class BusinessResolver: BusinessResolving {
    
    enum Error: Swift.Error {
        case noIdentityFound
        case noLicenseFound
        case unableToStoreIdentity
        case unableToStoreLicense
    }
    
    private let myIdentityStore: any MyIdentityStoreProtocol
    private let licenseStore: any LicenseStoreProtocol
    private let flavorService: any AppFlavorServiceProtocol

    init(
        myIdentityStore: any MyIdentityStoreProtocol,
        licenseStore: any LicenseStoreProtocol,
        flavorService: any AppFlavorServiceProtocol
    ) {
        self.myIdentityStore = myIdentityStore
        self.licenseStore = licenseStore
        self.flavorService = flavorService
    }
    
    func resolve(
        with remoteSecretManager: any RemoteSecretManagerProtocol,
        and keychainManager: any KeychainManagerProtocol
    ) async throws -> any BusinessInjectorProtocol {
        
        RemoteSecretProvider.setRemoteSecretManager(remoteSecretManager)
        
        // The identity is used for certain app migrations, thus we ensure it is synced. On the other hand, the
        // license might be migrated (e.g. the migration to Keychain in 7.0 (actually 6.9, but that was never
        // publicly released)), thus we only sync it after the migrations
        // TODO: (IOS-6598) Remove as `MyIdentityStore` should not be accessed during app migration
        try syncIdentity(with: keychainManager)
        
        try await SetupApp.runDatabaseMigrationIfNeeded(
            remoteSecretManager: remoteSecretManager
        )
        
        let businessInjector = BusinessInjector(
            remoteSecretManager: remoteSecretManager
        )

        // TODO: (IOS-6598) Remove dependency on business injector
        try await SetupApp.runAppMigrationIfNeeded(
            businessInjector: businessInjector
        )
        
        // To ensure we're in the right state we also sync the identity one more time
        try syncIdentity(with: keychainManager)
        try syncLicense(with: keychainManager)
        
        return businessInjector
    }
    
    // MARK: - Keychain Syncing
    
    private func syncIdentity(with keychainManager: KeychainManagerProtocol) throws {
        // If we have a (new) identity and it is valid, we store it in the keychain.
        // If not we try to load the one stored in keychain
        if myIdentityStore.isValidIdentity {
            try storeIdentity(using: keychainManager)
        }
        else if let identity = try keychainManager.loadIdentity() {
            updateMyIdentityStore(with: identity)
        }
        else {
            DDLogError("No identity, neither in MyIdentityStore nor in keychain")
            assertionFailure("No identity in store or keychain")
            throw Error.noIdentityFound
        }
    }
    
    private func syncLicense(with keychainManager: KeychainManagerProtocol) throws {
        guard flavorService.isBusinessApp else {
            return
        }
        
        // If we have a license and it is valid, we store it in the keychain.
        // If not we try to load the one stored in keychain.
        if licenseStore.isValid() || ProcessInfoHelper.isRunningForScreenshots {
            try storeLicense(using: keychainManager)
        }
        else if let license = try keychainManager.loadLicense() {
            updateLicenseStore(with: license)
        }
        else {
            DDLogError("No license, neither in LicenseStore nor in keychain")
            assertionFailure("No license in store or keychain")
            throw Error.noLicenseFound
        }
    }
    
    // MARK: - Identity Helpers

    private func storeIdentity(using keychainManager: KeychainManagerProtocol) throws {
        guard
            let identity = myIdentityStore.identity,
            let clientKey = myIdentityStore.clientKey,
            let publicKey = myIdentityStore.publicKey,
            let serverGroup = myIdentityStore.serverGroup
        else {
            DDLogError("Cannot store identity: missing fields")
            assertionFailure("Missing identity fields for keychain storage")
            throw Error.unableToStoreIdentity
        }

        let myIdentity = MyIdentity(
            identity: ThreemaIdentity(identity),
            clientKey: ThreemaClientKey(clientKey),
            publicKey: ThreemaPublicKey(publicKey),
            serverGroup: ServerGroup(serverGroup)
        )

        // Keep the user's Easy Device Switch choice; a new identity (no keychain item yet) defaults to this device only
        let thisDeviceOnly = (try? keychainManager.isIdentityThisDeviceOnly()) ?? true
        try keychainManager.storeIdentity(myIdentity, thisDeviceOnly: thisDeviceOnly)

        // We could already be further in the process when coming from a safe restore
        if AppSetup.state.rawValue < AppSetupState.identityAdded.rawValue {
            AppSetup.state = .identityAdded
        }
    }

    private func updateMyIdentityStore(with identity: MyIdentity) {
        myIdentityStore.identity = identity.$identity
        myIdentityStore.clientKey = identity.$clientKey
        myIdentityStore.publicKey = identity.$publicKey
        myIdentityStore.serverGroup = identity.$serverGroup
    }
    
    // MARK: - License Helpers

    private func storeLicense(using keychainManager: KeychainManagerProtocol) throws {
        guard
            let username = licenseStore.licenseUsername,
            let password = licenseStore.licensePassword
        else {
            DDLogError("Cannot store license: missing username or password")
            assertionFailure("Missing license credentials for keychain storage")
            throw Error.unableToStoreLicense
        }

        let license = ThreemaLicense(
            user: username,
            password: password,
            deviceID: licenseStore.licenseDeviceID,
            onPremServer: licenseStore.onPremConfigURL
        )

        try keychainManager.storeLicense(license)
    }

    private func updateLicenseStore(with license: ThreemaLicense) {
        licenseStore.licenseUsername = license.user
        licenseStore.licensePassword = license.password
        
        if let deviceID = license.deviceID {
            licenseStore.licenseDeviceID = deviceID
        }
        
        licenseStore.onPremConfigURL = license.onPremServer
    }
}
