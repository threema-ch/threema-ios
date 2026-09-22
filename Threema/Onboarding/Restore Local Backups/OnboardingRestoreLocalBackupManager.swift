
import CocoaLumberjackSwift
import DataBackup
import FileUtility
import Keychain
import RemoteSecret
import RemoteSecretProtocol
import ThreemaEssentials
import ThreemaFramework
import ThreemaMacros

@MainActor
final class OnboardingRestoreLocalBackupManager {

    private enum LocalBackupRestoreError: LocalizedError {

        /// Why a picked data backup could not be read.
        case notOnDevice

        var errorDescription: String? {
            switch self {
            case .notOnDevice:
                #localize("restoring_backup_not_on_device")
            }
        }
    }

    private let myIdentityStore: () -> MyIdentityStore

    init(myIdentityStore: @escaping () -> MyIdentityStore = MyIdentityStore.shared) {
        self.myIdentityStore = myIdentityStore
    }

    // MARK: - Phase 1: Identity

    /// Takes the Threema ID out of the backup and puts it on the device. Nothing else of the backup is applied, and no
    /// database is touched, so this runs before the migrations.
    ///
    /// - Returns: The identity the backup belongs to.
    func restoreIdentity(from backupURL: URL, recoveryKey: String) async throws -> ThreemaIdentity {
        DDLogNotice("[LocalBackupRestore] Restore started")

        try await RemoteSecretProvider.setRemoteSecretManager(makePreRestoreRemoteSecret())

        let hasSecurityScope = backupURL.startAccessingSecurityScopedResource()

        defer {
            if hasSecurityScope {
                backupURL.stopAccessingSecurityScopedResource()
            }
        }

        try verifyIsOnDevice(backupURL)

        // Not `FileUtility.shared`: the backup is the user's own file and is already encrypted with the recovery key,
        // so it must not be read through the remote secret decorator, which would try to decrypt every chunk of it a
        // second time.
        let identityManager = BackupRestoreIdentityManager(
            myIdentityStore: myIdentityStore(),
            fileUtility: FileUtility()
        )

        let identity = try await identityManager.restoreIdentity(from: backupURL, password: recoveryKey)

        DDLogNotice("[LocalBackupRestore] Backup belongs to \(identity)")

        return identity
    }

    // MARK: - Phase 2: Data

    /// Migrates the app onto `remoteSecretManager` and reads the backup in, reporting progress as it goes.
    ///
    /// - Precondition: ``restoreIdentity(from:recoveryKey:)`` ran on this backup, and `remoteSecretManager` is the one
    ///   resolved for the identity it returned.
    func restoreData(
        from backupURL: URL,
        recoveryKey: String,
        remoteSecretManager: any RemoteSecretManagerProtocol
    ) -> AsyncThrowingStream<DataRestoreProgress, any Error> {
        let (stream, continuation) = AsyncThrowingStream<DataRestoreProgress, any Error>.makeStream()

        let task = Task {
            do {
                try await SetupApp.runDatabaseMigrationIfNeeded(remoteSecretManager: remoteSecretManager)

                try await SetupApp.runAppMigrationIfNeeded(
                    businessInjector: BusinessInjector(remoteSecretManager: remoteSecretManager)
                )

                let hasSecurityScope = backupURL.startAccessingSecurityScopedResource()

                defer {
                    if hasSecurityScope {
                        backupURL.stopAccessingSecurityScopedResource()
                    }
                }

                // The restore's poll loop never suspends, so it runs off the main thread — the injector it writes Core
                // Data through has to be a background one.
                let backgroundBusinessInjector = BusinessInjector(forBackgroundProcess: true)

                let dataManager = BackupRestoreDataManager(
                    myIdentityStore: backgroundBusinessInjector.myIdentityStore,
                    userSettings: backgroundBusinessInjector.userSettings,
                    entityManager: backgroundBusinessInjector.entityManager,
                    fileUtility: FileUtility()
                )

                // Reads straight from `backupURL`, which is the user's own file — nothing here deletes or writes to it.
                for try await progress in dataManager.restore(url: backupURL, password: recoveryKey) {
                    continuation.yield(progress)
                }

                DDLogNotice("[LocalBackupRestore] Restore done")

                continuation.finish()
            }
            catch {
                continuation.finish(throwing: error)
            }
        }

        continuation.onTermination = { _ in
            task.cancel()
        }

        return stream
    }

    // MARK: - Private methods

    /// The remote secret the identity is taken out of the backup with, before any identity exists.
    ///
    /// Deliberately does not go through `RemoteSecretResolver`: its resolution paths all end in a keychain sync that
    /// requires an identity. `RemoteSecretManagerCreator.initialize()` asks the keychain for one and hands back an
    /// `EmptyRemoteSecretManager` when there is none, which is exactly the state the identity pass runs in — and as
    /// soon as the identity is known, the caller resolves the real one and the data pass runs on that.
    private func makePreRestoreRemoteSecret() async throws -> any RemoteSecretManagerProtocol {
        try await RemoteSecretManagerCreator(
            appInfo: ThreemaUtility.appInfo,
            httpClient: HTTPClient(),
            keychainManagerType: KeychainManager.self
        ).initialize()
    }

    /// Checks that a backup held in iCloud Drive is actually on the device before it is read.
    ///
    /// A file shown in Files can still be a placeholder that was never downloaded, and `FileHandle(forReadingFrom:)`
    /// cannot materialize one — it just fails.
    private func verifyIsOnDevice(_ url: URL) throws {
        let values = try? url.resourceValues(
            forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]
        )

        guard values?.isUbiquitousItem == true, values?.ubiquitousItemDownloadingStatus != .current else {
            return
        }

        DDLogError("[LocalBackupRestore] Backup is not on the device: \(url.lastPathComponent)")

        throw LocalBackupRestoreError.notOnDevice
    }
}
