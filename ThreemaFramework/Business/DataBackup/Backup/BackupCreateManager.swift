import CocoaLumberjackSwift
import DataBackup
import FileUtility
import Foundation
import libthreemaSwift
import os
import ThreemaEssentials

public final class BackupCreateManager: BackupCreateManagerProtocol {

    // MARK: Private properties

    private let myIdentityStore: any MyIdentityStoreProtocol
    private let providersFactory: DataBackupProvidersFactory
    private let fileUtility: any FileUtilityProtocol
    private let encryptionKeyService: any BackupEncryptionKeyServiceProtocol
    private let userDefaults: any UserDefaultsService
    private let dateProvider: () -> Date

    private let partialBackupFiles: PartialBackupFiles

    private let lastBackupKey = "DataBackupLastBackup"

    /// Where the backup of the running ``create(password:)`` ends up once it is recorded, known only once libthreema
    /// named it. Until then it is written to its partial URL.
    ///
    /// Locked, because it is set from the detached backup task and read by ``recordSuccessfulBackup()`` on the caller's
    /// side.
    private let inProgressBackupURL = OSAllocatedUnfairLock<URL?>(initialState: nil)

    public var backupSettings = BackupMetadata()

    public var currentRecoveryKey: BackupEncryptionKey {
        encryptionKeyService.currentKey
    }

    public var backupURL: URL? {
        lastBackup?.fileName.map(backupFileURL(named:))
    }

    public var lastBackup: BackupMetadata? {
        guard let data = userDefaults.data(forKey: lastBackupKey) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(BackupMetadata.self, from: data)
        }
        catch {
            DDLogError("[BackupCreateManager] Could not decode the last backup: \(error)")
            return nil
        }
    }

    // MARK: Lifecycle

    public convenience init(
        myIdentityStore: any MyIdentityStoreProtocol,
        userSettings: any UserSettingsProtocol,
        entityManager: EntityManager,
        fileUtility: any FileUtilityProtocol,
        encryptionKeyService: any BackupEncryptionKeyServiceProtocol,
        userDefaults: any UserDefaultsService,
        dateProvider: @escaping () -> Date
    ) {
        self.init(
            myIdentityStore: myIdentityStore,
            providersFactory: DataBackupProvidersFactory(
                // Built from the ID `makeDataBackup` validated, so the store can't end up on a different one than the
                // backup is written for — and its singletons stay out of initialization until a backup runs.
                makeProfileStore: { ProfileStore(myIdentity: $0) },
                userSettings: userSettings,
                entityManager: entityManager
            ),
            fileUtility: fileUtility,
            encryptionKeyService: encryptionKeyService,
            userDefaults: userDefaults,
            dateProvider: dateProvider
        )
    }

    /// Takes the providers from `providersFactory`, so a test can run a backup on throwaway storage.
    init(
        myIdentityStore: any MyIdentityStoreProtocol,
        providersFactory: DataBackupProvidersFactory,
        fileUtility: any FileUtilityProtocol,
        encryptionKeyService: any BackupEncryptionKeyServiceProtocol,
        userDefaults: any UserDefaultsService,
        dateProvider: @escaping () -> Date
    ) {
        self.myIdentityStore = myIdentityStore
        self.providersFactory = providersFactory
        self.fileUtility = fileUtility
        self.encryptionKeyService = encryptionKeyService
        self.userDefaults = userDefaults
        self.dateProvider = dateProvider
        self.partialBackupFiles = PartialBackupFiles(fileUtility: fileUtility)
    }

    // MARK: Public methods

    public func createNewRecoveryKey() throws {
        try encryptionKeyService.renewKey()
    }

    public func deleteDefaultRecoveryKey() throws {
        try encryptionKeyService.deleteKey()
    }

    public func create(password: String) -> AsyncThrowingStream<DataBackupProgress, any Error> {

        // Only the most recent one is worth keeping.
        let (stream, continuation) = AsyncThrowingStream<DataBackupProgress, any Error>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )

        // The previous backup is kept until `recordSuccessfulBackup` replaces it, so a backup that fails does not leave
        // the user without one.

        // Detached, because `create` is not isolated: a plain `Task` would inherit the caller's isolation and build the
        // Core Data backed providers on whatever actor happens to call this.
        let task = Task.detached(priority: .userInitiated) { [self] in
            do {
                let dataBackup = try makeDataBackup(password: password) { progress in
                    continuation.yield(progress)
                }

                try await dataBackup.perform()
                continuation.finish()
            }
            catch {
                continuation.finish(throwing: error)
            }
        }

        // Set after the task was created: if it finished already this cancels a completed task, which is a no-op, and
        // the terminal state is kept until a consumer observes it.
        continuation.onTermination = { _ in
            task.cancel()
        }

        return stream
    }

    public func recordSuccessfulBackup() throws {
        guard
            let url = inProgressBackupURL.withLock({ $0 }),
            let sizeInBytes = fileUtility.fileSizeInBytes(fileURL: partialBackupFiles.partialURL(for: url))
        else {
            throw BackupCreateManagerError.missingBackupFile
        }

        // Read before the new record replaces the one it is derived from.
        let previousBackupURL = backupURL

        let record = BackupMetadata(
            date: dateProvider(),
            size: UInt64(max(0, sizeInBytes)),
            includesMessages: backupSettings.includesMessages,
            includesMedia: backupSettings.includesMedia,
            fileName: url.lastPathComponent
        )

        let data = try JSONEncoder().encode(record)
        try encryptionKeyService.markKeyAsDefault()

        // Renamed last, so a backup that is not recorded keeps its partial name and is deleted as a leftover.
        try partialBackupFiles.moveToFinalName(url)

        userDefaults.set(data, forKey: lastBackupKey)
        inProgressBackupURL.withLock { $0 = nil }

        // Two backups started within the same second get the same name, and then the new file already replaced the old.
        if let previousBackupURL, previousBackupURL != url, fileUtility.fileExists(at: previousBackupURL) {
            do {
                try fileUtility.delete(at: previousBackupURL)
            }
            catch {
                // The new backup is recorded and usable, so a leftover file is not worth failing it for.
                DDLogError("[BackupCreateManager] Could not delete the replaced backup: \(error)")
            }
        }
    }

    public func removePreviousBackup() throws {
        if let backupURL, fileUtility.fileExists(at: backupURL) {
            try fileUtility.delete(at: backupURL)
        }

        userDefaults.set(nil, forKey: lastBackupKey)
    }

    // MARK: Private methods

    private func makeDataBackup(
        password: String,
        onProgress: @escaping DataBackup.ProgressHandler
    ) throws -> DataBackup {
        guard let identity = try? ThreemaIdentity(identity: myIdentityStore.identity) else {
            throw BackupCreateManagerError.missingIdentity
        }

        guard let clientKey = myIdentityStore.clientKey else {
            throw BackupCreateManagerError.missingClientKey
        }

        guard let cspServerGroup = myIdentityStore.serverGroup else {
            throw BackupCreateManagerError.missingChatServerGroup
        }

        let identityData = IdentityData(
            userIdentity: LibthreemaThreemaID(identity.rawValue),
            clientKey: ClientKey(clientKey),
            cspServerGroup: cspServerGroup
        )

        let context = DataBackupCreateInit(
            password: password,
            identityData: identityData,
            providers: providersFactory.make(identity: identity)
        )

        let createTask = try DataBackupCreateTask(init: context)
        let url = backupFileURL(named: createTask.getFilename())

        // An earlier backup of this session that was not recorded would otherwise take up space until the next launch.
        partialBackupFiles.removeLeftovers()
        inProgressBackupURL.withLock { $0 = url }

        return DataBackup(
            backupURL: partialBackupFiles.partialURL(for: url),
            fileUtility: fileUtility,
            createTask: createTask,
            onProgress: onProgress
        )
    }

    private func backupFileURL(named fileName: String) -> URL {
        URL.documentsDirectory.appending(path: fileName, directoryHint: .notDirectory)
    }
}
