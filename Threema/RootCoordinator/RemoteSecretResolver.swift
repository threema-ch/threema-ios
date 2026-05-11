import CocoaLumberjackSwift
import Foundation
import Keychain
import RemoteSecret
import RemoteSecretProtocol
import ThreemaEssentials
import ThreemaFramework

// MARK: - RemoteSecretResolverResult

enum RemoteSecretResolverResult {
    /// RS resolved without UI. Ready to proceed.
    case ready(remoteSecretManager: any RemoteSecretManagerProtocol, keychainManager: any KeychainManagerProtocol)
    
    /// RS is available (credentials in keychain) but the actual key must be fetched.
    /// The coordinator should present `RemoteSecretInitializeViewsManager`
    /// on a `UINavigationController`, then call `continueAfterFetch(remoteSecretManager:)`.
    case needsFetch
    
    /// Encrypted data detected without RS credentials. Unrecoverable — app must be reinstalled.
    case encryptedDataDetected
}

// MARK: - RemoteSecretResolving

@MainActor
protocol RemoteSecretResolving: AnyObject {

    /// Determines the current RS state and resolves it where possible without UI.
    func resolve() async throws -> RemoteSecretResolverResult

    /// Completes RS setup after the coordinator has presented the RS fetch UI and
    /// received a `RemoteSecretManagerProtocol` back from it.
    ///
    /// Only call this when `resolve()` returned `.needsFetch`.
    func continueAfterFetch(
        remoteSecretManager: any RemoteSecretManagerProtocol
    ) throws -> (
        remoteSecretManager: any RemoteSecretManagerProtocol,
        keychainManager: any KeychainManagerProtocol
    )
}

// MARK: - RemoteSecretResolver

/// Based on the four-state matrix it either:
/// - Creates a new RS (no UI needed)
/// - Creates an empty RS manager (no UI needed)
/// - Returns `.needsFetch` when RS is available but the actual key must be
///   fetched (requires UI for spinner + error recovery)
/// - Returns `.encryptedDataDetected` for unrecoverable states
///
/// After returning `.needsFetch`, a client (e.g., coordinator) should present
/// `RemoteSecretInitializeViewsManager`, and then call
/// `continueAfterFetch(remoteSecretManager:)` with the result.
@MainActor
final class RemoteSecretResolver: RemoteSecretResolving {

    // MARK: - Result

    enum Result {
        /// RS resolved without UI. Ready to proceed.
        case ready(remoteSecretManager: any RemoteSecretManagerProtocol, keychainManager: any KeychainManagerProtocol)

        /// RS is available (credentials in keychain) but the actual key must be fetched.
        /// The coordinator should present `RemoteSecretInitializeViewsManager`
        /// on a `UINavigationController`, then call `continueAfterFetch(remoteSecretManager:)`.
        case needsFetch

        /// Encrypted data detected without RS credentials. Unrecoverable — app must be reinstalled.
        case encryptedDataDetected
    }

    // MARK: - Errors

    enum ResolverError: Error {
        case missingInfo
        case noIdentityFound
        case unableToStoreLicense
        case unableToStoreIdentity
        case unableToGetWorkServerURL
    }

    // MARK: - Properties

    private let appLaunchManager: any AppLaunchManagerProtocol
    private let licenseStore: LicenseStore
    private let myIdentityStore: MyIdentityStore
    private let mdmSetup: MDMSetup
    private let flavorService: AppFlavorService
    private let hasPreexistingData: Bool

    private lazy var remoteSecretManagerCreator = RemoteSecretManagerCreator(
        appInfo: ThreemaUtility.appInfo,
        httpClient: HTTPClient(),
        keychainManagerType: KeychainManager.self
    )

    // MARK: - Lifecycle

    init(
        appLaunchManager: any AppLaunchManagerProtocol,
        licenseStore: LicenseStore,
        myIdentityStore: MyIdentityStore,
        mdmSetup: MDMSetup,
        flavorService: AppFlavorService,
        hasPreexistingData: Bool
    ) {
        self.appLaunchManager = appLaunchManager
        self.licenseStore = licenseStore
        self.myIdentityStore = myIdentityStore
        self.mdmSetup = mdmSetup
        self.flavorService = flavorService
        self.hasPreexistingData = hasPreexistingData
    }

    // MARK: - Resolve

    /// Determines RS state and resolves it if possible without UI.
    func resolve() async throws -> RemoteSecretResolverResult {
        loadIdentityFromKeychainIfNeeded()
        
        guard appLaunchManager.isAppSetupCompleted == false else {
            return try await makeReady()
        }

        let isRemoteSecretAvailable = try KeychainManager.loadRemoteSecret() != nil
        let isRemoteSecretEnabled = mdmSetup.enableRemoteSecret()

        let configuration = RemoteSecretConfiguration(
            isRemoteSecretAvailable: isRemoteSecretAvailable,
            isRemoteSecretEnabled: isRemoteSecretEnabled
        )

        switch configuration.state {
        case .availableAndEnabled:
            return .needsFetch

        case .availableAndDisabled:
            return try await resolveAvailableAndDisabled()

        case .notAvailableAndEnabled:
            return try await resolveNotAvailableAndEnabled()

        case .notAvailableAndDisabled:
            return try await resolveNotAvailableAndDisabled()
        }
    }

    /// Completes RS setup after the coordinator has fetched RS.
    ///
    /// Called after `.needsFetch` was returned and `RemoteSecretInitializeViewsManager`
    /// successfully returned a `RemoteSecretManagerProtocol`.
    func continueAfterFetch(
        remoteSecretManager: any RemoteSecretManagerProtocol
    ) throws -> (
        remoteSecretManager: any RemoteSecretManagerProtocol,
        keychainManager: any KeychainManagerProtocol
    ) {
        let keychainManager = KeychainManager(remoteSecretManager: remoteSecretManager)
        try syncKeychain(with: keychainManager)
        return (remoteSecretManager, keychainManager)
    }

    // MARK: - Resolution Paths

    /// RS is available (credentials in keychain) but no longer enabled by MDM.
    private func resolveAvailableAndDisabled() async throws -> RemoteSecretResolverResult {
        guard hasPreexistingData else {
            // No data — safe to delete stale encrypted keychain items and treat as disabled.
            try KeychainManager.deleteAllThisDeviceOnlyItems()
            return try await resolveNotAvailableAndDisabled()
        }

        // Data exists — we must still fetch RS to decrypt it.
        // The user will get a prompt to backup and restore later.
        return .needsFetch
    }

    /// RS is not available (no credentials in keychain) but enabled by MDM.
    private func resolveNotAvailableAndEnabled() async throws -> RemoteSecretResolverResult {
        guard !hasPreexistingData else {
            guard !DatabaseManager.isExistingDBEncrypted() else {
                // Encrypted data exists but no RS credentials — unrecoverable.
                return .encryptedDataDetected
            }
            // Unencrypted data exists; admin enabled RS too late. Treat as disabled.
            return try await resolveNotAvailableAndDisabled()
        }

        // No preexisting data — delete possibly stale encrypted keychain items, then create new RS.
        try KeychainManager.deleteAllThisDeviceOnlyItems()

        let remoteSecretManager = try await createRemoteSecret()
        let keychainManager = KeychainManager(remoteSecretManager: remoteSecretManager)
        try syncKeychain(with: keychainManager)

        return .ready(remoteSecretManager: remoteSecretManager, keychainManager: keychainManager)
    }

    /// RS is not available (no credentials in keychain) and not enabled by MDM.
    private func resolveNotAvailableAndDisabled() async throws -> RemoteSecretResolverResult {
        if hasPreexistingData, DatabaseManager.isExistingDBEncrypted() {
            // Encrypted data exists but RS is disabled and credentials are gone — unrecoverable.
            return .encryptedDataDetected
        }

        // Delete possibly stale keychain items from a previous installation on the same device.
        try KeychainManager.deleteAllThisDeviceOnlyItems()

        let remoteSecretManager = try await remoteSecretManagerCreator.initialize()
        let keychainManager = KeychainManager(remoteSecretManager: remoteSecretManager)
        try syncKeychain(with: keychainManager)

        return .ready(remoteSecretManager: remoteSecretManager, keychainManager: keychainManager)
    }
    
    private func makeReady() async throws -> RemoteSecretResolverResult {
        let remoteSecretManager = try await remoteSecretManagerCreator.initialize()
        let keychainManager = KeychainManager(remoteSecretManager: remoteSecretManager)
        
        return .ready(remoteSecretManager: remoteSecretManager, keychainManager: keychainManager)
    }

    // MARK: - RemoteSecret Creation

    private func createRemoteSecret() async throws -> any RemoteSecretManagerProtocol {
        guard
            let username = licenseStore.licenseUsername,
            let password = licenseStore.licensePassword,
            let identity = myIdentityStore.identity,
            let clientKey = myIdentityStore.clientKey
        else {
            assertionFailure("Missing credentials for RS creation")
            DDLogError("[RemoteSecretResolver] Cannot create RS: missing identity, clientKey, username, or password")
            throw ResolverError.missingInfo
        }

        return try await remoteSecretManagerCreator.create(
            workServerBaseURL: workServerURL(),
            licenseUsername: username,
            licensePassword: password,
            identity: ThreemaIdentity(identity),
            clientKey: clientKey
        )
    }

    private func workServerURL() async throws -> String {
        guard let url = try await ServerInfoProviderFactory.makeServerInfoProvider().workServerURL() else {
            throw ResolverError.unableToGetWorkServerURL
        }
        return url
    }

    // MARK: - Load Identity From Keychain

    private func loadIdentityFromKeychainIfNeeded() {
        guard
            myIdentityStore.identity == nil,
            let identity = try? KeychainManager.loadThreemaIdentity() else {
            return
        }
        
        myIdentityStore.identity = identity.rawValue
    }

    // MARK: - Keychain Sync

    /// Syncs identity and license between the in-memory stores and the keychain.
    /// Duplicated from SetupApp.handleKeychain.
    private func syncKeychain(with keychainManager: KeychainManagerProtocol) throws {
        if flavorService.isBusinessApp {
            if let license = try keychainManager.loadLicense() {
                updateLicenseStore(with: license)
            }
            else {
                try storeLicense(using: keychainManager)
            }
        }

        if myIdentityStore.identity != nil {
            try storeIdentity(using: keychainManager)
        }
        else if let identity = try keychainManager.loadIdentity() {
            updateMyIdentityStore(with: identity)
        }
        else {
            assertionFailure("No identity in store or keychain")
            DDLogError("[RemoteSecretResolver] No identity, neither in myIdentityStore nor in keychain")
            throw ResolverError.noIdentityFound
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
            assertionFailure("Missing identity fields for keychain storage")
            DDLogError("[RemoteSecretResolver] Cannot store identity: missing fields")
            throw ResolverError.unableToStoreIdentity
        }

        let myIdentity = MyIdentity(
            identity: ThreemaIdentity(identity),
            clientKey: ThreemaClientKey(clientKey),
            publicKey: ThreemaPublicKey(publicKey),
            serverGroup: ServerGroup(serverGroup)
        )

        try keychainManager.storeIdentity(myIdentity, thisDeviceOnly: true)

        // We could already be further in the process when coming from a safe restore.
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
            assertionFailure("Missing license credentials for keychain storage")
            DDLogError("[RemoteSecretResolver] Cannot store license: missing username or password")
            throw ResolverError.unableToStoreLicense
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
