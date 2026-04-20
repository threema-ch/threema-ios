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
    let licenseStore: any LicenseStoreProtocol
    let bootstrapServerAPI: any BootstrapServerAPIProtocol
    let bootstrapIdentityCreator: any BootstrapIdentityCreatorProtocol
    let bootstrapKeychainManager: any BootstrapKeychainManagerProtocol
    let bootstrapBackupStore: any BootstrapBackupStoreProtocol
    let bootstrapWorkDataFetcher: any BootstrapWorkDataFetcherProtocol
    let bootstrapContactStore: any BootstrapContactStoreProtocol
    let bootstrapPhoneNumberNormalizer: any BootstrapPhoneNumberNormalizerProtocol
    let bootstrapMDM: any BootstrapMDMSetupProtocol
    
    // MARK: - Initialization
    
    init(
        appLaunchManager: any AppLaunchManagerProtocol,
        bootstrapUserSettings: any BootstrapUserSettingsProtocol,
        bootstrapIdentityStore: any BootstrapIdentityStoreProtocol,
        licenseStore: any LicenseStoreProtocol,
        bootstrapServerAPI: any BootstrapServerAPIProtocol,
        bootstrapIdentityCreator: any BootstrapIdentityCreatorProtocol,
        bootstrapKeychainManager: any BootstrapKeychainManagerProtocol,
        bootstrapBackupStore: any BootstrapBackupStoreProtocol,
        bootstrapContactStore: any BootstrapContactStoreProtocol,
        bootstrapWorkDataFetcher: any BootstrapWorkDataFetcherProtocol,
        bootstrapPhoneNumberNormalizer: any BootstrapPhoneNumberNormalizerProtocol,
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
        /// It doesn't belong here, but the these IDs need to be set before we
        /// init `MDMSetup`.
        AppGroup.setGroupID(BundleUtil.threemaAppGroupIdentifier())
        BundleUtil.mainBundle()?.bundleIdentifier.map(AppGroup.setAppID(_:))
        
        let appLaunchManager = AppLaunchManagerAdapter()
        let identityStore = BootstrapIdentityStoreAdapter()
        
        return BootstrapContainer(
            appLaunchManager: appLaunchManager,
            bootstrapUserSettings: BootstrapUserSettingsAdapter(),
            bootstrapIdentityStore: identityStore,
            licenseStore: LicenseStoreAdapter(),
            bootstrapServerAPI: BootstrapServerAPIAdapter(identityStore: identityStore),
            bootstrapIdentityCreator: BootstrapIdentityCreatorAdapter(),
            bootstrapKeychainManager: BootstrapKeychainManagerAdapter(),
            bootstrapBackupStore: BootstrapBackupStoreAdapter(),
            bootstrapContactStore: BootstrapContactStoreAdapter(),
            bootstrapWorkDataFetcher: BootstrapWorkDataFetcherAdapter(),
            bootstrapPhoneNumberNormalizer: BootstrapPhoneNumberNormalizerAdapter(),
            bootstrapMDM: BootstrapMDMAdapter(
                mdmSetup: MDMSetup(),
                appLaunchManager: appLaunchManager
            )
        )
    }
}
