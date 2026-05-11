import CocoaLumberjackSwift
import Foundation

/// Fetch work data like Work Directory, Logo, Support URL, Work Contacts
/// and applies in the lokal storage.
final class WorkDataFetcher: WorkDataFetcherProtocol {

    // MARK: Private properties

    private let licenseStore: any LicenseStoreProtocol
    private let contactStore: any WorkFetcherContactAdderProtocol
    private let identityStore: any MyIdentityStoreProtocol
    private let userSettings: any UserSettingsProtocol
    private let userDefaults: UserDefaults
    private let serverInfoProvider: ServerInfoProvider
    private let appFlavorService: any AppFlavorServiceProtocol
    private let entityManager: EntityManager
    private let workDataAPICaller: any WorkDataAPICallerProtocol
    private let workDataThreemaMDMFetcher: any WorkDataThreemaMDMFetcherProtocol
    private let mdmSetup: MDMSetupProtocol
    
    // MARK: Constants

    private static let defaultCheckInterval: TimeInterval = 86400
    private static let lastSyncKey = "WorkDataLastSync"
    private static let checkIntervalKey = "WorkDataCheckInterval"

    // MARK: - Lifecycle

    init(
        contactStore: any WorkFetcherContactAdderProtocol,
        licenseStore: any LicenseStoreProtocol,
        identityStore: any MyIdentityStoreProtocol,
        userSettings: any UserSettingsProtocol,
        userDefaults: UserDefaults,
        serverInfoProvider: ServerInfoProvider,
        appFlavorService: any AppFlavorServiceProtocol,
        entityManager: EntityManager,
        mdmSetup: any MDMSetupProtocol,
        workDataAPICaller: any WorkDataAPICallerProtocol,
        workDataThreemaMDMFetcher: any WorkDataThreemaMDMFetcherProtocol
    ) {
        self.licenseStore = licenseStore
        self.contactStore = contactStore
        self.identityStore = identityStore
        self.userSettings = userSettings
        self.userDefaults = userDefaults
        self.serverInfoProvider = serverInfoProvider
        self.entityManager = entityManager
        self.appFlavorService = appFlavorService
        self.mdmSetup = mdmSetup
        self.workDataAPICaller = workDataAPICaller
        self.workDataThreemaMDMFetcher = workDataThreemaMDMFetcher
    }
    
    // MARK: - WorkDataFetcherProtocol

    public func checkUpdateWorkData(force: Bool, forceSendMDM: Bool = false) async throws {
        guard appFlavorService.isBusinessApp else {
            return
        }
        
        guard shouldSync(force: force) else {
            DDLogInfo("[WorkDataFetcher] Still within work check interval - not syncing")
            return
        }
        
        guard licenseStore.licenseUsername != nil else {
            return
        }

        let contactIDs = entityManager.performAndWait {
            Array(self.entityManager.entityFetcher.contactIdentities())
        }
        let data = try await workDataAPICaller.fetchWorkData(with: contactIDs)

        let response = try JSONDecoder().decode(WorkDataResponse.self, from: data)

        DDLogInfo("[WorkDataFetcher]: Received work data: \(response)")
        
        // Delegate the mdm update
        try await workDataThreemaMDMFetcher.processAndApply(data, forceSend: forceSendMDM)
        
        applyLogo(response.logo)
        applySupportURL(response.support)
        applyOrganization(response.org)
        applyDirectory(response.directory, mdmSetup: mdmSetup)
        
        if !ProcessInfoHelper.isRunningForScreenshots, let contacts = response.contacts {
            let batchContacts = contacts.map { $0.mapToBatchAddWorkContact() }
            try await contactStore.batchAddWorkContacts(batchAddContacts: batchContacts, lastFullSyncAt: response.time)
        }

        recordSync(checkInterval: response.checkInterval)
    }

    public func resetLastSync() {
        resetSync()
    }

    // MARK: - Private functions

    private func applyLogo(_ logo: WorkDataResponse.WorkLogo?) {
        guard let logo else {
            identityStore.licenseLogoLightURL = nil
            identityStore.licenseLogoDarkURL = nil
            return
        }

        let oldLightURL = identityStore.licenseLogoLightURL
        let oldDarkURL = identityStore.licenseLogoDarkURL

        identityStore.licenseLogoLightURL = logo.light
        identityStore.licenseLogoDarkURL = logo.dark

        if oldLightURL != identityStore.licenseLogoLightURL ||
            oldDarkURL != identityStore.licenseLogoDarkURL {
            NotificationCenter.default.post(
                name: Notification.Name(kNotificationColorThemeChanged),
                object: nil
            )
        }
    }

    private func applySupportURL(_ support: String?) {
        identityStore.licenseSupportURL = support
    }

    private func applyDirectory(_ directory: WorkDataResponse.WorkDirectory?, mdmSetup: MDMSetupProtocol) {
        guard let directory else {
            userSettings.companyDirectory = false
            return
        }

        if mdmSetup.disableWorkDirectory() {
            userSettings.companyDirectory = false
        }
        else {
            if directory.enabled != userSettings.companyDirectory {
                userSettings.companyDirectory = directory.enabled
            }
            if let categories = directory.cat {
                identityStore.directoryCategories = NSMutableDictionary(dictionary: categories)
            }
            else {
                identityStore.directoryCategories = nil
            }
        }
    }

    private func applyOrganization(_ org: WorkDataResponse.WorkOrganization?) {
        guard let org, let name = org.name else {
            identityStore.companyName = nil
            return
        }

        if name != identityStore.companyName {
            identityStore.companyName = name
        }
    }

    private func shouldSync(force: Bool) -> Bool {
        guard !force else {
            return true
        }

        guard let lastSync = userDefaults.object(forKey: Self.lastSyncKey) as? Date else {
            return true
        }

        let interval = userDefaults.double(forKey: Self.checkIntervalKey)
        let checkInterval = interval > 0 ? interval : Self.defaultCheckInterval

        return -lastSync.timeIntervalSinceNow >= checkInterval
    }

    private func recordSync(checkInterval: Int?) {
        var interval = Self.defaultCheckInterval
        if let serverInterval = checkInterval, serverInterval > 0 {
            DDLogVerbose("[WorkDataFetcher] Server supplied check interval is \(serverInterval)")
            interval = TimeInterval(serverInterval)
        }

        userDefaults.set(Date.now, forKey: Self.lastSyncKey)
        userDefaults.set(interval, forKey: Self.checkIntervalKey)
    }

    private func resetSync() {
        userDefaults.removeObject(forKey: Self.lastSyncKey)
    }
}
