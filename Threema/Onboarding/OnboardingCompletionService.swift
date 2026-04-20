import CocoaLumberjackSwift
import Foundation
import Keychain
import RemoteSecretProtocol
import ThreemaFramework

/// Service responsible for handling the completion steps after identity setup.
/// This includes database migration, nickname persistence, email/phone linking,
/// contact sync, and Threema Safe setup.
@MainActor
final class OnboardingCompletionService {
    
    // MARK: - Properties
    
    private let bootstrapIdentityStore: any BootstrapIdentityStoreProtocol
    private let licenseStore: any LicenseStoreProtocol
    private let bootstrapUserSettings: any BootstrapUserSettingsProtocol
    private let bootstrapContactStore: any BootstrapContactStoreProtocol
    private let bootstrapServerAPI: any BootstrapServerAPIProtocol
    private let bootstrapPhoneNumberNormalizer: any BootstrapPhoneNumberNormalizerProtocol
    private let bootstrapMDM: any BootstrapMDMSetupProtocol
    private let safeComponentsFactory: SafeComponentsFactory
    
    // MARK: - Initialization
    
    init(
        bootstrapIdentityStore: any BootstrapIdentityStoreProtocol,
        licenseStore: any LicenseStoreProtocol,
        bootstrapUserSettings: any BootstrapUserSettingsProtocol,
        bootstrapContactStore: any BootstrapContactStoreProtocol,
        bootstrapServerAPI: any BootstrapServerAPIProtocol,
        bootstrapPhoneNumberNormalizer: any BootstrapPhoneNumberNormalizerProtocol,
        bootstrapMDM: any BootstrapMDMSetupProtocol,
        safeComponentsFactory: SafeComponentsFactory
    ) {
        self.bootstrapIdentityStore = bootstrapIdentityStore
        self.licenseStore = licenseStore
        self.bootstrapUserSettings = bootstrapUserSettings
        self.bootstrapContactStore = bootstrapContactStore
        self.bootstrapServerAPI = bootstrapServerAPI
        self.bootstrapPhoneNumberNormalizer = bootstrapPhoneNumberNormalizer
        self.bootstrapMDM = bootstrapMDM
        self.safeComponentsFactory = safeComponentsFactory
    }
    
    // MARK: - Public Methods
    
    /// Runs database and app migrations, updates feature mask, and sets app setup state.
    /// - Parameters:
    ///   - remoteSecretManager: The remote secret manager for database initialization
    ///   - keychainManager: The keychain manager for database initialization
    /// - Throws: Error if migration fails
    func runMigrationsAndSetup(
        remoteSecretManager: any RemoteSecretManagerProtocol,
        keychainManager: any KeychainManagerProtocol
    ) async throws {
        try await SetupApp.runDatabaseMigrationIfNeeded(remoteSecretManager: remoteSecretManager)
        try await SetupApp.runAppMigrationIsNeeded()
        try await FeatureMask.updateLocal()
        
        AppSetup.state = .identitySetupComplete
    }
    
    /// Persists the nickname from setup configuration to the identity store.
    /// - Parameter nickname: The nickname to persist, or nil to skip
    func persistNickname(_ nickname: String?) {
        guard let nickname, !nickname.isEmpty else {
            return
        }
        
        bootstrapIdentityStore.pushFromName = nickname
        licenseStore.performUpdateWorkInfo()
    }
    
    /// Synchronizes contacts from address book if enabled.
    /// - Parameter syncContacts: Whether to sync contacts
    /// - Returns: True if sync was performed and succeeded, false if skipped
    /// - Throws: Error if synchronization fails
    @discardableResult
    func syncContacts(
        _ syncContacts: Bool,
        userSettings: any UserSettingsProtocol
    ) async throws -> Bool {
        userSettings.syncContacts = syncContacts
        
        guard syncContacts else {
            return false
        }
        
        return try await bootstrapContactStore.synchronizeAddressBook(forceFullSync: true)
    }
    
    /// Links an email address to the identity.
    /// - Parameter email: The email address to link, or nil to skip
    /// - Returns: True if linking was performed, false if skipped
    /// - Throws: Error if linking fails
    @discardableResult
    func linkEmail(_ email: String?) async throws -> Bool {
        guard let email, !email.isEmpty else {
            return false
        }
        
        guard bootstrapIdentityStore.linkedEmail?.isEmpty ?? true else {
            return false
        }
        
        return try await bootstrapServerAPI.linkEmail(email)
    }
    
    /// Links a phone number to the identity.
    /// - Parameter phoneNumber: The phone number to link (will be normalized), or nil to skip
    /// - Returns: True if linking was performed, false if skipped
    /// - Throws: Error if linking fails
    @discardableResult
    func linkPhoneNumber(_ phoneNumber: String?) async throws -> Bool {
        guard let phoneNumber, !phoneNumber.isEmpty else {
            return false
        }
        
        guard bootstrapIdentityStore.linkedMobileNo?.isEmpty ?? true else {
            return false
        }
        
        guard let normalizedNumber = bootstrapPhoneNumberNormalizer.normalize(phoneNumber) else {
            DDLogWarn("Failed to normalize phone number, skipping link")
            return false
        }
        
        return try await bootstrapServerAPI.linkMobileNo(normalizedNumber)
    }
    
    /// Enables Threema Safe with the provided configuration.
    /// - Parameters:
    ///   - businessInjector: The business injector with all dependencies needed for Safe
    ///   - keychainManager: The keychain manager for Safe storage
    ///   - safePassword: The Safe password from setup configuration
    ///   - safeCustomServer: Custom server URL, or nil
    ///   - safeServerUsername: Server username, or nil
    ///   - safeServerPassword: Server password, or nil
    ///   - safeMaxBackupBytes: Maximum backup size, or nil
    ///   - safeRetentionDays: Retention days, or nil
    /// - Returns: True if Safe was enabled, false if skipped
    /// - Throws: Error if Safe activation fails
    @discardableResult
    func enableSafe(
        businessInjector: any BusinessInjectorProtocol,
        keychainManager: any KeychainManagerProtocol,
        safePassword: String?,
        safeCustomServer: String?,
        safeServerUsername: String?,
        safeServerPassword: String?,
        safeMaxBackupBytes: NSNumber?,
        safeRetentionDays: NSNumber?
    ) async throws -> Bool {
        businessInjector.userSettings.safeIntroShown = true
        
        let safeConfigManager = safeComponentsFactory.createSafeConfigManager(keychainManager: keychainManager)
        let safeAPIService = safeComponentsFactory.createSafeAPIService()
        
        var effectivePassword = safePassword
        if bootstrapMDM.isSafeBackupPasswordPreset {
            effectivePassword = bootstrapMDM.safePassword
        }
        
        let safeStore = safeComponentsFactory.createSafeStore(
            safeConfigManager: safeConfigManager,
            serverAPIConnector: bootstrapServerAPI.serverAPIConnector,
            groupManager: businessInjector.groupManager,
            myIdentityStore: businessInjector.myIdentityStore
        )
        let safeManager = SafeManager(
            safeConfigManager: safeConfigManager,
            safeStore: safeStore,
            safeAPIService: safeAPIService
        )
        
        guard let password = effectivePassword, password.count >= 8 else {
            DDLogError("Could not enable Threema Safe: invalid password")
            safeManager.deactivate()
            return false
        }
        
        var customServer = safeCustomServer
        var customServerUsername = safeServerUsername
        var customServerPassword = safeServerPassword
        
        if bootstrapMDM.isSafeBackupServerPreset {
            customServer = bootstrapMDM.safeServerURL
            customServerUsername = bootstrapMDM.safeServerUsername
            customServerPassword = bootstrapMDM.safeServerPassword
            
            safeConfigManager.setCustomServer(customServer)
            safeConfigManager.setServer(customServer)
        }
        
        guard let identity = bootstrapIdentityStore.identity else {
            DDLogError("Cannot enable Safe: no identity available")
            return false
        }
        
        try await safeManager.activate(
            identity: identity,
            safePassword: password,
            customServer: customServer,
            serverUser: customServerUsername,
            serverPassword: customServerPassword,
            server: customServer,
            maxBackupBytes: safeMaxBackupBytes,
            retentionDays: safeRetentionDays
        )
        
        return true
    }
}
