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
import FileUtility
import Foundation
import Keychain
import RemoteSecret
import RemoteSecretProtocol
import ThreemaEssentials

public final class AppLaunchManager: NSObject {

    @objc public static let shared = {
        if FileUtility.shared == nil {
            FileUtility.updateSharedInstance(
                with: CrashingFileUtilityRemoteSecretDecorator(
                    wrapped: FileUtility(),
                    whitelist: Set(RemoteSecretFileEncryptionWhitelist.whiteList)
                )
            )
        }
        return AppLaunchManager()
    }()
    
    public enum AppLaunchError: Int, Error, CustomStringConvertible {
        public typealias RawValue = Int

        case remoteSecretMissing = 0
        case workURLMissing = 1
        case repairedDatabaseImportRequired = 2
        case requireDatabaseMigrationFailed = 3
        case databaseMigrationRequired = 4
        case appSetupRequired = 5
        case appMigrationRequired = 6
        case myIdentityIsMissing = 7
        case businessInjectorNotReady = 8

        public var description: String {
            let rawError = "AppLaunchError(rawValue: \(rawValue))"

            switch self {
            case .remoteSecretMissing:
                return "\(rawError) 'Remote Secret is missing'"
            case .workURLMissing:
                return "\(rawError) 'Work URL is missing"
            case .repairedDatabaseImportRequired:
                return "\(rawError) 'Require import of repaired database'"
            case .requireDatabaseMigrationFailed:
                return "\(rawError) 'Require database migration failed'"
            case .databaseMigrationRequired:
                return "\(rawError) 'Database Migration is required'"
            case .appSetupRequired:
                return "\(rawError) 'App setup is not finished yet'"
            case .appMigrationRequired:
                return "\(rawError) 'App migration is required'"
            case .myIdentityIsMissing:
                return "\(rawError) 'My identity is missing'"
            case .businessInjectorNotReady:
                return "\(rawError) 'Business is not ready to use'"
            }
        }
    }

    // TODO: (IOS-5387) Replace this by exposing `PersistenceManager` in `BusinessInjector` and remove this
    // For now this is the source of truth for RS
    /// - Warning: This will crash if `initializeRemoteSecret()` is not called
    @available(
        *,
        deprecated,
        message: "This should only be used if you can't directly use the correct business class through business injector"
    )
    public static var remoteSecretManager: RemoteSecretManagerProtocol! {
        didSet {
            isRemoteSecretEnabled = remoteSecretManager.isRemoteSecretEnabled
            
            FileUtility.updateSharedInstance(with: FileUtilityRemoteSecretDecorator(
                wrapped: FileUtility(),
                remoteSecretManager: AppLaunchManager.remoteSecretManager,
                whitelist: Set(RemoteSecretFileEncryptionWhitelist.whiteList)
            ))
        }
    }

    @available(*, deprecated, message: "Normally you should get remote secret injected into your class")
    @objc public private(set) static var isRemoteSecretEnabled = false

    @objc override private init() {
        // no-op
    }

    public var isLicenseValid: Bool {
        LicenseStore.shared().isValid()
    }

    public var isRepairedDatabaseImportRequired: Bool {
        DatabaseManager.storeRequiresImport(fileUtility: FileUtility.shared)
    }

    public func isDatabaseMigrationRequired(databaseManager: DatabaseManagerProtocol) throws -> Bool {
        switch databaseManager.storeRequiresMigration() {
        case .error:
            throw AppLaunchError.requireDatabaseMigrationFailed
        case .none:
            return false
        case .required:
            return true
        }
    }

    public var isAppSetupCompleted: Bool {
        AppSetup.isCompleted
    }

    public var isAppMigrationRequired: Bool {
        AppMigrationVersion.isMigrationRequired(userSettings: UserSettings.shared())
    }

    @discardableResult
    public func business(
        remoteSecretManager: RemoteSecretManagerProtocol,
        databaseManager: DatabaseManagerProtocol,
        myIdentityStore: MyIdentityStoreProtocol,
        forBackgroundProcess: Bool = false
    ) throws -> BusinessInjector {

        guard !isRepairedDatabaseImportRequired else {
            throw AppLaunchError.databaseMigrationRequired
        }

        guard try !isDatabaseMigrationRequired(databaseManager: databaseManager) else {
            throw AppLaunchError.databaseMigrationRequired
        }

        guard AppSetup.isIdentityAdded else {
            throw AppLaunchError.appSetupRequired
        }

        guard !isAppMigrationRequired else {
            throw AppLaunchError.appMigrationRequired
        }

        guard myIdentityStore.identity != nil else {
            throw AppLaunchError.myIdentityIsMissing
        }

        // TODO: (IOS-5305) Check if `remoteSecretManager` can be injected into `BusinessInjector`
        // TODO: (IOS-5387) `PersistenceManager` should be created here and injected into `BusinessInjector`
        return BusinessInjector(forBackgroundProcess: forBackgroundProcess)
    }

    @MainActor public func initializeRemoteSecret(
        navigationController: UINavigationController?,
        onDelete: (() -> Void)?,
        onCancel: (() -> Void)?
    ) async throws -> RemoteSecretManagerProtocol {

        // TODO: (IOS-5305) See if we can move before the BI creation
        let remoteSecretInitializeViewsManager =
            RemoteSecretInitializeViewsManager(navigationController: navigationController)
        let newRemoteSecretManager = try await remoteSecretInitializeViewsManager.start(
            onDelete: onDelete,
            onCancel: onCancel
        )
        
        AppLaunchManager.remoteSecretManager = newRemoteSecretManager

        return newRemoteSecretManager
    }
    
    /// Tries to create `BusinessInjector` will throw is App is not launched completely
    /// - Parameter forBackgroundProcess: Get BusinessInjector for running in background
    /// - Returns: BusinessInjector
    @objc public func business(forBackgroundProcess: Bool) throws -> BusinessInjector {
        guard let remoteSecretManager = AppLaunchManager.remoteSecretManager else {
            throw AppLaunchError.remoteSecretMissing
        }
        
        return try business(
            remoteSecretManager: remoteSecretManager,
            databaseManager: initializeDatabaseManager(remoteSecretManager: remoteSecretManager),
            myIdentityStore: MyIdentityStore.shared(),
            forBackgroundProcess: forBackgroundProcess
        )
    }
    
    #if DEBUG
        // Use only for testing
        func setRemoteSecretManager(_ remoteSecretManager: RemoteSecretManagerProtocol) {
            AppLaunchManager.remoteSecretManager = remoteSecretManager
        }
    #endif

    public func initializeDatabaseManager(remoteSecretManager: RemoteSecretManagerProtocol) -> DatabaseManagerProtocol {
        DatabaseManager(appGroupID: AppGroup.groupID(), remoteSecretManager: remoteSecretManager)
    }

    #if DEBUG
        public func importOldVersionDatabase(databaseManager: DatabaseManagerProtocol) {
            do {
                if try databaseManager.importOldVersionDatabase() {
                    DDLogWarn(
                        "Old version of database would be applied. Start the app again for testing database migration! Caution, please check on devices that the App is not running (in background) anymore, otherwise migration will fail!!!"
                    )
                    exit(EXIT_SUCCESS)
                }
            }
            catch {
                DDLogError("Import of old version of database failed: \(error)")
                exit(EXIT_FAILURE)
            }
        }
    #endif

    public func importRepairedDatabase(databaseManager: DatabaseManagerProtocol) throws {
        try databaseManager.importRepairedDatabase()
    }

    public func migrateDatabase(databaseManager: DatabaseManagerProtocol) throws {
        try databaseManager.checkFreeDiskSpaceForDatabaseMigration()
        try databaseManager.migrateDB()
    }
}
