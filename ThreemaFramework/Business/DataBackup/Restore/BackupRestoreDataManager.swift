import DataBackup
import FileUtility
import Foundation
import libthreemaSwift
import ThreemaEssentials

/// The Threema ID the backup belongs to has to be on the device first, which is ``BackupRestoreIdentityManager``.
public final class BackupRestoreDataManager: BackupRestoreDataManagerProtocol {

    // MARK: - Private properties

    private let myIdentityStore: any MyIdentityStoreProtocol
    private let providersFactory: BackupRestoreProvidersFactory
    private let entityManager: EntityManager
    private let fileUtility: any FileUtilityProtocol

    // MARK: - Lifecycle

    /// - Parameters:
    ///   - makeProfileStore: Builds the profile store for a Threema ID. Called only once the ID is known, which on a
    ///     restore is after the backup handed it over, so this must not capture a store built up front.
    ///   - entityManager: Must be a background one. The restore occupies its context's queue from start to finish, so
    ///     driving it on the main context deadlocks the app.
    ///   - fileUtility: Reads the backup file. Must not be one that decrypts with the remote secret: the backup is the
    ///     user's own file, encrypted with the recovery key alone.
    public init(
        myIdentityStore: any MyIdentityStoreProtocol,
        makeProfileStore: @escaping (ThreemaIdentity) -> any ProfileStoreProtocol = { ProfileStore(myIdentity: $0) },
        userSettings: any UserSettingsProtocol,
        entityManager: EntityManager,
        fileUtility: any FileUtilityProtocol
    ) {
        self.myIdentityStore = myIdentityStore
        self.providersFactory = BackupRestoreProvidersFactory(
            makeProfileStore: makeProfileStore,
            userSettings: userSettings,
            entityManager: entityManager
        )
        self.entityManager = entityManager
        self.fileUtility = fileUtility
    }

    // MARK: - Public methods

    /// - Precondition: ``BackupRestoreIdentityManager/restoreIdentity(from:password:)`` ran on this backup, so the app
    ///   already stands on the identity — and the remote secret — everything read here is written under. The stream
    ///   fails with ``BackupRestoreDataManagerError/identityNotRestored`` otherwise.
    public func restore(url: URL, password: String) -> AsyncThrowingStream<DataRestoreProgress, any Error> {
        let (stream, continuation) = AsyncThrowingStream<DataRestoreProgress, any Error>.makeStream()

        let task = Task.detached(priority: .userInitiated) { [self] in
            do {
                // `DataRestore` holds its delegate weakly, so this has to stay in scope for the whole restore.
                let delegate = DataRestoreProgressDelegate(
                    myIdentityStore: myIdentityStore,
                    providersFactory: providersFactory,
                    continuation: continuation
                )

                let restoreTask = BackupRestoreTask(password: password)
                let dataRestore = DataRestore(
                    backupURL: url,
                    fileUtility: fileUtility,
                    restoreTask: restoreTask,
                    delegate: delegate
                )

                // The whole restore runs on the Core Data context's queue rather than on whatever thread called in.
                //
                // The providers write Core Data as the backup is read, and they are not self-sufficient about it: most
                // of their methods hop onto the queue with `performAndWait`, but several reach `entityFetcher`
                // directly, and `EntityManager.save()` and `rollback()` never hop at all. Off the context's queue that
                // is a threading violation — it traps outright with `-com.apple.CoreData.ConcurrencyDebug 1`, which
                // the app scheme enables.
                //
                // Holding the queue for the entire restore makes every one of those accesses correct, and the nested
                // `performAndWait` calls inside the providers are fine because Core Data allows them re-entrantly on
                // the same queue.
                try entityManager.performAndWait {
                    try dataRestore.performOnCurrentThread()
                }

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
}

// MARK: - DataRestoreProgressDelegate

/// Drives ``BackupRestoreDataManager/restore(url:password:)``.
///
/// Owns the continuation of the one restore it was made for, so nothing about a running restore outlives it on the
/// manager.
private final class DataRestoreProgressDelegate: DataRestoreDelegate {

    private let myIdentityStore: any MyIdentityStoreProtocol
    private let providersFactory: BackupRestoreProvidersFactory
    private let continuation: AsyncThrowingStream<DataRestoreProgress, any Error>.Continuation

    init(
        myIdentityStore: any MyIdentityStoreProtocol,
        providersFactory: BackupRestoreProvidersFactory,
        continuation: AsyncThrowingStream<DataRestoreProgress, any Error>.Continuation
    ) {
        self.myIdentityStore = myIdentityStore
        self.providersFactory = providersFactory
        self.continuation = continuation
    }

    func dataRestore(
        _ dataRestore: DataRestore,
        didReceiveIdentityData data: libthreemaSwift.IdentityData
    ) throws {
        let identity = try ThreemaIdentity(identity: data.userIdentity)

        // The identity pass put it there, and the remote secret everything below is written under was resolved for it.
        // A restore that starts without it would fill the database for an ID the app does not have.
        guard myIdentityStore.identity == identity.rawValue else {
            throw BackupRestoreDataManagerError.identityNotRestored
        }

        try dataRestore.addProviders(providersFactory.make(identity: identity))
    }

    func dataRestore(
        _ dataRestore: DataRestore,
        didReceiveStateUpdate update: libthreemaSwift.BackupRestoreStateUpdate
    ) {
        continuation.yield(DataRestoreProgress(update))
    }
}
