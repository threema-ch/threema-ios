import Foundation
import RemoteSecretProtocol
import ThreemaFramework
import ThreemaMacros
import UIKit

// MARK: - SetupApp

/// Migration steps that have to run once an identity is available, both on a normal launch and at the end of
/// onboarding.
///
/// The remote secret and keychain setup that used to live here is now owned by `RemoteSecretResolver`.
enum SetupApp {

    @MainActor @discardableResult static func runDatabaseMigrationIfNeeded(
        remoteSecretManager: RemoteSecretManagerProtocol
    ) async throws -> DatabaseManagerProtocol {
        let databaseManager = AppLaunchManager.shared
            .initializeDatabaseManager(remoteSecretManager: remoteSecretManager)

        #if DEBUG
            AppLaunchManager.shared.importOldVersionDatabase(databaseManager: databaseManager)
        #endif

        if AppLaunchManager.shared.isRepairedDatabaseImportRequired {
            try await SpinnerPresenter.presentSpinner(
                label: #localize("updating_database"),
                window: SharedAppProvider.window
            ) {
                try AppLaunchManager.shared.importRepairedDatabase(databaseManager: databaseManager)
            }
        }

        if try AppLaunchManager.shared.isDatabaseMigrationRequired(databaseManager: databaseManager) {
            try await SpinnerPresenter.presentSpinner(
                label: #localize("updating_database"),
                window: SharedAppProvider.window
            ) {
                try AppLaunchManager.shared.migrateDatabase(databaseManager: databaseManager)
            }
        }

        return databaseManager
    }

    @MainActor static func runAppMigrationIfNeeded(
        businessInjector: BusinessInjectorProtocol
    ) async throws {
        guard AppLaunchManager.shared.isAppMigrationRequired else {
            return
        }

        let appMigration = AppMigration(businessInjector: businessInjector)

        if AppSetup.hasPreexistingDatabaseFile {
            try appMigration.run()
        }
        else {
            appMigration.updateAppMigrationVersionToLatest()
        }
    }
}
