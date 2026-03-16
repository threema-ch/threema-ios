//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import CocoaLumberjackSwift
import Foundation
import Keychain
import RemoteSecret
import RemoteSecretProtocol
import ThreemaEssentials
import ThreemaFramework
import ThreemaMacros

@objc protocol SetupAppDelegate {
    func mismatchCancelled()
    func encryptedDataDetected()
}

@MainActor final class SetupApp: NSObject {
    enum SetupError: Error {
        case missingInfo
        case noIdentityFound
        case unableToStoreLicense
        case unableToStoreIdentity
        case unableToGetWorkServerURL
    }

    weak var delegate: SetupAppDelegate?
    private let licenseStore: LicenseStore
    private let myIdentityStore: MyIdentityStore
    private let mdmSetup: MDMSetup
    private let hasPreexistingData: Bool
    private var previousVC: UIViewController?
    
    private lazy var remoteSecretManagerCreator = RemoteSecretManagerCreator(
        appInfo: ThreemaUtility.appInfo,
        httpClient: HTTPClient(),
        keychainManagerType: KeychainManager.self
    )
    
    // MARK: - Lifecycle
    
    @MainActor @objc required init(
        delegate: SetupAppDelegate?,
        licenseStore: LicenseStore,
        myIdentityStore: MyIdentityStore,
        mdmSetup: MDMSetup,
        hasPreexistingData: Bool,
    ) {
        self.delegate = delegate
        self.licenseStore = licenseStore
        self.myIdentityStore = myIdentityStore
        self.mdmSetup = mdmSetup
        self.hasPreexistingData = hasPreexistingData
    }

    // MARK: - Setup
    
    /// Creates the remote secret and sets up keychain based on the current app state after a restore
    @MainActor @objc func setupRemoteSecretAndKeychain() async throws -> RemoteSecretAndKeychainObjC? {
       
        // In some paths, we might enter this function twice, so we check if already completed the setup first.
        guard AppLaunchManager.remoteSecretManager == nil else {
            let keychainManager = KeychainManager(remoteSecretManager: AppLaunchManager.remoteSecretManager)
            try handleKeychain(with: keychainManager)
            return RemoteSecretAndKeychainObjC(
                remoteSecretManager: AppLaunchManager.remoteSecretManager,
                keychainManager: keychainManager
            )
        }
        
        // We decide upon what to do, based on if RS is in keychain and whether it is enabled through MDM
        let isRemoteSecretInKeychain = try KeychainManager.loadRemoteSecret() != nil
        let isRemoteSecretInMDMEnabled = mdmSetup.enableRemoteSecret()
        
        // If the user quit the app during setup, the identity is already present in the keychain. We pre fill it to the
        // identity store, so possible existing remote secrets can be fetched.
        if myIdentityStore.identity == nil, let identity = try? KeychainManager.loadThreemaIdentity() {
            myIdentityStore.identity = identity.rawValue
        }
        
        switch (isRemoteSecretInKeychain, isRemoteSecretInMDMEnabled) {
        case (true, true):
            return try await setupRemoteSecretIsInKeychainAndStillEnabled()
            
        case (true, false):
            return try await setupRemoteSecretIsInKeychainButNoLongerEnabled()
            
        case (false, true):
            return try await setupRemoteSecretIsNotInKeychainButEnabled()

        case (false, false):
            return try await setupRemoteSecretIsNotInKeychainAndNotEnabled()
        }
    }
    
    private func setupRemoteSecretIsInKeychainAndStillEnabled() async throws -> RemoteSecretAndKeychainObjC? {
        
        // At this point, the identity must be set, otherwise we cannot fetch the remote secret.
        guard myIdentityStore.identity != nil else {
            throw SetupError.missingInfo
        }
        
        // RS is in Keychain and still enabled through MDM. This means we have to:
        // 1.) Fetch the RS from the server
        let remoteSecretManager = try await setupRemoteSecretManagerFetch()
        
        AppLaunchManager.remoteSecretManager = remoteSecretManager
        
        // 3.) Create KeychainManager and set up Keychain
        let keychainManager = KeychainManager(remoteSecretManager: remoteSecretManager)
        try handleKeychain(with: keychainManager)
        
        return RemoteSecretAndKeychainObjC(remoteSecretManager: remoteSecretManager, keychainManager: keychainManager)
    }
    
    private func setupRemoteSecretIsInKeychainButNoLongerEnabled() async throws -> RemoteSecretAndKeychainObjC? {
        // RS is in Keychain but no longer enabled. This means we have to:
        // 1.) Check if we have data:
        guard hasPreexistingData else {
            // 1.1) If not: We can safely remove all encrypted Keychain Items and continue with setup as if it is
            // disabled.
            try KeychainManager.deleteAllThisDeviceOnlyItems()
            return try await setupRemoteSecretIsNotInKeychainAndNotEnabled()
        }
        
        // 1.2) If so: We simply continue setting up as if it was enabled.
        // The user will get a prompt to backup and restore later in the app.
        
        // 2.) Create RS Manager and store it in `AppLaunchManager`
        let remoteSecretManager = try await setupRemoteSecretManagerFetch()
        
        AppLaunchManager.remoteSecretManager = remoteSecretManager
        
        // 3.) Create KeychainManager and set up Keychain
        let keychainManager = KeychainManager(remoteSecretManager: remoteSecretManager)
        try handleKeychain(with: keychainManager)
        
        return RemoteSecretAndKeychainObjC(remoteSecretManager: remoteSecretManager, keychainManager: keychainManager)
    }
    
    private func setupRemoteSecretIsNotInKeychainButEnabled() async throws -> RemoteSecretAndKeychainObjC? {
        // RS is not in Keychain but enabled. This means we have to:
       
        // 1.) Check if we have data:
        guard !hasPreexistingData else {
            // 1.1.1) If it is encrypted, we can only recover by deleting the app.
            guard !DatabaseManager.isExistingDBEncrypted() else {
                delegate?.encryptedDataDetected()
                return nil
            }
            
            // 1.1.2) Else we simply continue setting up as if it was disabled. The user will get a prompt to backup
            // and restore later in the app.
            return try await setupRemoteSecretIsNotInKeychainAndNotEnabled()
        }
        
        // 1.2) If not: We remove all Keychain Items that could be still encrypted and continue with setup for enabling
        //      RS.
        try KeychainManager.deleteAllThisDeviceOnlyItems()
        
        // 2.) Create RS Manager and store it in `AppLaunchManager`
        let remoteSecretManager = try await setupRemoteSecretManagerCreate()
        AppLaunchManager.remoteSecretManager = remoteSecretManager
        
        // 3.) Create KeychainManager and set up Keychain
        let keychainManager = KeychainManager(remoteSecretManager: remoteSecretManager)
        try handleKeychain(with: keychainManager)
        
        return RemoteSecretAndKeychainObjC(remoteSecretManager: remoteSecretManager, keychainManager: keychainManager)
    }
    
    private func setupRemoteSecretIsNotInKeychainAndNotEnabled() async throws -> RemoteSecretAndKeychainObjC? {
        // RS is not in Keychain and not enabled. This means we have to:
        
        // 1.) Check if we have data that is encrypted. If so the only way to recover is to delete app
        if hasPreexistingData, DatabaseManager.isExistingDBEncrypted() {
            delegate?.encryptedDataDetected()
            return nil
        }
        
        // 2.) Delete all data in keychain if the app was not setup before. Data might still be in the keychain if we
        //     deleted the app on the home screen on the same device before
        if AppSetup.state == .notSetup {
            try KeychainManager.deleteAllThisDeviceOnlyItems()
        }
        
        // 3.) Create empty RS Manager and store it in `AppLaunchManager`
        let remoteSecretManager = setupEmptyRemoteSecretManager()
        AppLaunchManager.remoteSecretManager = remoteSecretManager
        
        // 4.) Create KeychainManager and set up Keychain
        let keychainManager = KeychainManager(remoteSecretManager: remoteSecretManager)
        try handleKeychain(with: keychainManager)
        
        return RemoteSecretAndKeychainObjC(remoteSecretManager: remoteSecretManager, keychainManager: keychainManager)
    }
    
    // MARK: - RemoteSecret
    
    func setupEmptyRemoteSecretManager() -> RemoteSecretManagerProtocol {
        remoteSecretManagerCreator.initializeEmptyRemoteSecretManager()
    }
    
    private func setupRemoteSecretManagerCreate() async throws -> RemoteSecretManagerProtocol {
        guard let username = licenseStore.licenseUsername,
              let password = licenseStore.licensePassword,
              let identity = myIdentityStore.identity,
              let clientKey = myIdentityStore.clientKey else {
            assertionFailure("This should not happen")
            DDLogError(
                "[SetupApp] Cannot create remote secret manager: No identity, private key, username or password set"
            )
            throw SetupError.missingInfo
        }
        
        return try await remoteSecretManagerCreator.create(
            workServerBaseURL: workServerURL(),
            licenseUsername: username,
            licensePassword: password,
            identity: ThreemaIdentity(identity),
            clientKey: clientKey
        )
    }
    
    private func setupRemoteSecretManagerFetch() async throws -> RemoteSecretManagerProtocol {
        // Store current view hierarchy to restore it later
        previousVC = AppDelegate.shared().window.rootViewController
       
        let navigationController = UINavigationController()
        navigationController.isNavigationBarHidden = true
        AppDelegate.shared().window.rootViewController = navigationController
        
        // Initialize RS
        let remoteSecretInitializeViewsManager = RemoteSecretInitializeViewsManager(
            navigationController: navigationController,
            showDeleteAfterRetries: 0
        )
        
        let remoteSecretManager = try await remoteSecretInitializeViewsManager.start(
            identity: ThreemaIdentity(myIdentityStore.identity),
            onDelete: {
                // We allow deletion of Keychain here, because of possible block or mismatch
                try! KeychainManager.deleteAllItems()
                exit(0)
            },
            onCancel: {
                // User can also go back to setup and enter a new ID
                AppDelegate.shared().window.rootViewController = self.previousVC
                self.delegate?.mismatchCancelled()
            }
        )
        
        // Restore view hierarchy
        AppDelegate.shared().window.rootViewController = previousVC
        
        return remoteSecretManager
    }
    
    // MARK: - Keychain
    
    private func handleKeychain(with keychainManager: KeychainManagerProtocol) throws {
        // If we are a business app, we make sure that the LicenseStore and the keychain have the same info
        if TargetManager.isBusinessApp {
            if let license = try keychainManager.loadLicense() {
                updateLicenseStore(with: license)
            }
            else {
                try storeLicense(using: keychainManager)
            }
        }
        
        // If we have a (new) identity and it is valid, we store it in the keychain.
        // If not we try to load the one stored in keychain
        if myIdentityStore.isValidIdentity {
            try storeIdentity(using: keychainManager)
        }
        else if let identity = try keychainManager.loadIdentity() {
            updateMyIdentityStore(with: identity)
        }
        else {
            assertionFailure("This should not happen")
            DDLogError("No identity, neither in myIdentityStore nor in keychain")
            throw SetupError.noIdentityFound
        }
    }
    
    // MARK: - Identity
    
    private func storeIdentity(using keychainManager: KeychainManagerProtocol) throws {
        guard let identity = myIdentityStore.identity,
              let clientKey = myIdentityStore.clientKey,
              let publicKey = myIdentityStore.publicKey,
              let serverGroup = myIdentityStore.serverGroup else {
            assertionFailure("This should not happen")
            DDLogError(
                "Cannot store identity in keychain: No identity, private key, public key or server group set"
            )
            throw SetupError.unableToStoreIdentity
        }
        
        let myIdentity = MyIdentity(
            identity: ThreemaIdentity(identity),
            clientKey: ThreemaClientKey(clientKey),
            publicKey: ThreemaPublicKey(publicKey),
            serverGroup: ServerGroup(serverGroup)
        )

        try keychainManager.storeIdentity(myIdentity)
        
        // We could already be further in the process when coming from a safe restore
        if AppSetup.state.rawValue < AppSetupState.identityAdded.rawValue {
            AppSetup.state = .identityAdded
        }
    }
    
    private func updateMyIdentityStore(with identity: MyIdentity) {
        myIdentityStore.identity = identity.identity.rawValue
        myIdentityStore.clientKey = identity.clientKey.rawValue
        myIdentityStore.publicKey = identity.publicKey.rawValue
        myIdentityStore.serverGroup = identity.serverGroup.rawValue
    }
    
    // MARK: - License
    
    private func storeLicense(using keychainManager: KeychainManagerProtocol) throws {
        guard let username = licenseStore.licenseUsername,
              let password = licenseStore.licensePassword else {
            assertionFailure("This should not happen")
            DDLogError("Cannot store license in keychain: No username or password set")
            throw SetupError.unableToStoreLicense
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
    
    // MARK: - Server Info
    
    private func workServerURL() async throws -> String {
        guard let workServerURL = try await ServerInfoProviderFactory.makeServerInfoProvider().workServerURL()
        else {
            throw SetupError.unableToGetWorkServerURL
        }
        
        return workServerURL
    }

    @MainActor @objc static func runDatabaseMigrationIfNeeded(
        remoteSecretAndKeychain: RemoteSecretAndKeychainObjC
    ) async throws {
        try await SetupApp
            .runDatabaseMigrationIfNeeded(remoteSecretManager: remoteSecretAndKeychain.remoteSecretManager)
    }

    @MainActor @discardableResult static func runDatabaseMigrationIfNeeded(
        remoteSecretManager: RemoteSecretManagerProtocol
    ) async throws
        -> DatabaseManagerProtocol {
        let databaseManager = AppLaunchManager.shared
            .initializeDatabaseManager(remoteSecretManager: remoteSecretManager)

        #if DEBUG
            AppLaunchManager.shared.importOldVersionDatabase(databaseManager: databaseManager)
        #endif

        if AppLaunchManager.shared.isRepairedDatabaseImportRequired {
            try await AppDelegate.shared().presentSpinner(label: #localize("updating_database")) {
                try AppLaunchManager.shared.importRepairedDatabase(databaseManager: databaseManager)
            }
        }

        if try AppLaunchManager.shared.isDatabaseMigrationRequired(databaseManager: databaseManager) {
            try await AppDelegate.shared().presentSpinner(label: #localize("updating_database")) {
                try AppLaunchManager.shared.migrateDatabase(databaseManager: databaseManager)
            }
        }

        return databaseManager
    }

    @MainActor @objc static func runAppMigrationIsNeeded() async throws {
        guard AppLaunchManager.shared.isAppMigrationRequired else {
            return
        }

        let appMigration = AppMigration()

        // Do app migration only there are data (database) present
        if AppSetup.hasPreexistingDatabaseFile {
            try await AppDelegate.shared().presentSpinner(label: #localize("updating_database")) {
                try appMigration.run()
            }
        }
        else {
            appMigration.updateAppMigrationVersionToLatest()
        }
    }
}
