import CocoaLumberjackSwift
import DataBackup
import FileUtility
import Foundation
import libthreemaSwift
import ThreemaEssentials

public final class BackupCreateManager: BackupCreateManagerProtocol {

    // MARK: Private properties

    private let myIdentityStore: any MyIdentityStoreProtocol
    private let providersFactory: BackupRestoreProvidersFactory
    private let fileUtility: any FileUtilityProtocol
    private let encryptionKeyService: any BackupEncryptionKeyServiceProtocol
    private let userDefaults: any UserDefaultsService
    private let dateProvider: () -> Date

    private let lastBackupKey = "DataBackupLastBackup"

    public var backupSettings = BackupMetadata()

    public var currentRecoveryKey: BackupEncryptionKey {
        encryptionKeyService.currentKey
    }

    public var backupURL: URL {
        URL.documentsDirectory
            .appending(path: "Backup", directoryHint: .notDirectory)
            .appendingPathExtension("dat")
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

    public init(
        myIdentityStore: any MyIdentityStoreProtocol,
        userSettings: any UserSettingsProtocol,
        entityManager: EntityManager,
        fileUtility: any FileUtilityProtocol,
        encryptionKeyService: any BackupEncryptionKeyServiceProtocol,
        userDefaults: any UserDefaultsService,
        dateProvider: @escaping () -> Date
    ) {
        self.myIdentityStore = myIdentityStore
        self.providersFactory = BackupRestoreProvidersFactory(
            // Built from the ID `makeDataBackup` validated, so the store can't end up on a different one than the
            // backup is written for — and its singletons stay out of initialization until a backup runs.
            makeProfileStore: { ProfileStore(myIdentity: $0) },
            userSettings: userSettings,
            entityManager: entityManager
        )
        self.fileUtility = fileUtility
        self.encryptionKeyService = encryptionKeyService
        self.userDefaults = userDefaults
        self.dateProvider = dateProvider
    }

    // MARK: Public methods

    public func createNewRecoveryKey() throws {
        try encryptionKeyService.renewKey()
    }

    public func deleteDefaultRecoveryKey() throws {
        try encryptionKeyService.deleteKey()
    }

    public func create(url: URL, password: String) -> AsyncThrowingStream<DataBackupProgress, any Error> {

        // Only the most recent one is worth keeping.
        let (stream, continuation) = AsyncThrowingStream<DataBackupProgress, any Error>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )

        // TODO: Rename previous file with `YYYY_MM_DD_Backup.dat` instead of deleting the previous `Backup.dat`
        do {
            try removePreviousBackup()
        }
        catch {
            continuation.finish(throwing: BackupCreateManagerError.deletionPreviousBackupFailed)
        }

        // Detached, because `create` is not isolated: a plain `Task` would inherit the caller's isolation and build the
        // Core Data backed providers on whatever actor happens to call this.
        let task = Task.detached(priority: .userInitiated) { [self] in
            do {
                let dataBackup = try makeDataBackup(url: url, password: password) { progress in
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
        guard let sizeInBytes = fileUtility.fileSizeInBytes(fileURL: backupURL) else {
            throw BackupCreateManagerError.missingBackupFile
        }

        let record = BackupMetadata(
            date: dateProvider(),
            size: UInt64(max(0, sizeInBytes)),
            includesMessages: backupSettings.includesMessages,
            includesMedia: backupSettings.includesMedia
        )

        let data = try JSONEncoder().encode(record)
        try encryptionKeyService.markKeyAsDefault()

        userDefaults.set(data, forKey: lastBackupKey)
    }

    public func removePreviousBackup() throws {
        if fileUtility.fileExists(at: backupURL) {
            try fileUtility.delete(at: backupURL)
        }

        userDefaults.set(nil, forKey: lastBackupKey)
    }

    // MARK: Private methods

    private func makeDataBackup(
        url: URL,
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

        let providers = providersFactory.make(identity: identity)

        let context = BackupCreateContextInit(
            password: password,
            identityData: identityData,
            userProfile: providers.userProfile,
            settings: providers.settings,
            cspNonces: providers.cspNonces,
            contacts: providers.contacts,
            groups: providers.groups,
            distributionLists: providers.distributionLists,
            polls: providers.polls,
            conversations: providers.conversations
        )

        let createTask = try BackupCreateTask(init: context)

        return DataBackup(
            backupURL: url,
            fileUtility: fileUtility,
            createTask: createTask,
            onProgress: onProgress
        )
    }
}
