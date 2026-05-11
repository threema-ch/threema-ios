import Foundation
import ThreemaFramework

// MARK: - BootstrapContainer

/// Contains dependencies available before RemoteSecret initialization.
@MainActor
final class BootstrapContainer {
    
    // MARK: - Dependencies
    
    let appLaunchManager: any AppLaunchManagerProtocol
    let bootstrapUserSettings: any BootstrapUserSettingsProtocol
    let bootstrapIdentityStore: any BootstrapIdentityStoreProtocol
    let licenseStore: any LicenseStoreAdapterProtocol
    let bootstrapServerAPI: any BootstrapServerAPIProtocol
    let bootstrapIdentityCreator: any BootstrapIdentityCreatorProtocol
    let bootstrapKeychainManager: any BootstrapKeychainManagerProtocol
    let bootstrapBackupStore: any BootstrapBackupStoreProtocol
    let bootstrapWorkDataFetcher: any BootstrapWorkDataFetcherProtocol
    let bootstrapContactStore: any BootstrapContactStoreProtocol
    let bootstrapPhoneNumberNormalizer: any PhoneNumberNormalizerProtocol
    let bootstrapMDM: any BootstrapMDMSetupProtocol
    
    // MARK: - Initialization
    
    init(
        appLaunchManager: any AppLaunchManagerProtocol,
        bootstrapUserSettings: any BootstrapUserSettingsProtocol,
        bootstrapIdentityStore: any BootstrapIdentityStoreProtocol,
        licenseStore: any LicenseStoreAdapterProtocol,
        bootstrapServerAPI: any BootstrapServerAPIProtocol,
        bootstrapIdentityCreator: any BootstrapIdentityCreatorProtocol,
        bootstrapKeychainManager: any BootstrapKeychainManagerProtocol,
        bootstrapBackupStore: any BootstrapBackupStoreProtocol,
        bootstrapContactStore: any BootstrapContactStoreProtocol,
        bootstrapWorkDataFetcher: any BootstrapWorkDataFetcherProtocol,
        bootstrapPhoneNumberNormalizer: any PhoneNumberNormalizerProtocol,
        bootstrapMDM: any BootstrapMDMSetupProtocol
    ) {
        self.appLaunchManager = appLaunchManager
        self.bootstrapUserSettings = bootstrapUserSettings
        self.bootstrapIdentityStore = bootstrapIdentityStore
        self.licenseStore = licenseStore
        self.bootstrapServerAPI = bootstrapServerAPI
        self.bootstrapIdentityCreator = bootstrapIdentityCreator
        self.bootstrapKeychainManager = bootstrapKeychainManager
        self.bootstrapBackupStore = bootstrapBackupStore
        self.bootstrapWorkDataFetcher = bootstrapWorkDataFetcher
        self.bootstrapContactStore = bootstrapContactStore
        self.bootstrapPhoneNumberNormalizer = bootstrapPhoneNumberNormalizer
        self.bootstrapMDM = bootstrapMDM
    }
}

// MARK: - Live Factory

extension BootstrapContainer {
    static func live() -> BootstrapContainer {
        let identityStore = BootstrapIdentityStoreAdapter()
        
        return BootstrapContainer(
            appLaunchManager: AppLaunchManagerAdapter(),
            bootstrapUserSettings: BootstrapUserSettingsAdapter(),
            bootstrapIdentityStore: identityStore,
            licenseStore: LicenseStoreAdapter(),
            bootstrapServerAPI: BootstrapServerAPIAdapter(identityStore: identityStore),
            bootstrapIdentityCreator: BootstrapIdentityCreatorAdapter(),
            bootstrapKeychainManager: BootstrapKeychainManagerAdapter(),
            bootstrapBackupStore: BootstrapBackupStoreAdapter(),
            bootstrapContactStore: BootstrapContactStoreAdapter(),
            bootstrapWorkDataFetcher: BootstrapWorkDataFetcherAdapter(),
            bootstrapPhoneNumberNormalizer: PhoneNumberNormalizer(),
            bootstrapMDM: BootstrapMDMAdapter(mdmSetup: MDMSetup())
        )
    }
}
