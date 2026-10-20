import DataBackup
import FileUtility
import Foundation
import libthreemaSwift
import ThreemaEssentials

/// The ID lives inside the backup, and the app has to be set up for it — its remote secret above all — before the
/// backup's data can be written anywhere. That is what this is for: ``BackupRestoreDataManager`` reads the data in
/// afterwards.
public final class BackupRestoreIdentityManager: BackupRestoreIdentityManagerProtocol {

    // MARK: - Private properties

    private let myIdentityStore: any MyIdentityStoreProtocol
    private let fileUtility: any FileUtilityProtocol

    // MARK: - Lifecycle

    /// - Parameter fileUtility: Reads the backup file. Must not be one that decrypts with the remote secret: the
    ///   backup is the user's own file, encrypted with the recovery key alone.
    public init(
        myIdentityStore: any MyIdentityStoreProtocol,
        fileUtility: any FileUtilityProtocol
    ) {
        self.myIdentityStore = myIdentityStore
        self.fileUtility = fileUtility
    }

    // MARK: - Public methods

    public func restoreIdentity(from url: URL, password: String) async throws -> ThreemaIdentity {
        try await Task.detached(priority: .userInitiated) { [self] in
            // `DataRestore` holds its delegate weakly, so this has to stay in scope for the whole pass.
            let delegate = IdentityRestoreDelegate(myIdentityStore: myIdentityStore)

            let dataRestore = DataRestore(
                backupURL: url,
                fileUtility: fileUtility,
                restoreTask: DataBackupRestoreTask(password: password),
                delegate: delegate
            )

            try dataRestore.performUntilIdentityData()

            guard let identity = delegate.identity else {
                throw BackupRestoreIdentityManagerError.missingIdentity
            }

            return identity
        }.value
    }
}

// MARK: - IdentityRestoreDelegate

/// Drives ``BackupRestoreIdentityManager/restoreIdentity(from:password:)``.
///
/// Deliberately never adds providers: without them the restore task cannot advance past the identity, so nothing of
/// the backup can be applied by the pass this serves.
private final class IdentityRestoreDelegate: DataRestoreDelegate {

    private(set) var identity: ThreemaIdentity?

    private let myIdentityStore: any MyIdentityStoreProtocol

    init(myIdentityStore: any MyIdentityStoreProtocol) {
        self.myIdentityStore = myIdentityStore
    }

    func dataRestore(
        _ dataRestore: DataRestore,
        didReceiveIdentityData data: libthreemaSwift.IdentityData
    ) throws {
        let identity = try ThreemaIdentity(identity: data.userIdentity)
        try restore(identity, from: data)

        self.identity = identity
    }

    func dataRestore(
        _ dataRestore: DataRestore,
        didReceiveStateUpdate update: libthreemaSwift.DataBackupRestoreStateUpdate
    ) {
        // Nothing of the backup is read in this pass, so there is no progress to report
    }

    // MARK: - Private methods

    private func restore(_ identity: ThreemaIdentity, from data: libthreemaSwift.IdentityData) throws {
        let semaphore = DispatchSemaphore(value: 0)
        var restoreError: Error?

        myIdentityStore.restore(fromBackup: identity.rawValue, withSecretKey: data.clientKey) {
            semaphore.signal()
        } onError: { error in
            restoreError = error
            semaphore.signal()
        }

        semaphore.wait()

        if let restoreError {
            throw restoreError
        }

        myIdentityStore.serverGroup = data.cspServerGroup
    }
}
