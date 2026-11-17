import DataBackup
import FileUtility
import Foundation
import ThreemaEssentials
@testable import ThreemaFramework

/// An empty device for one backup round trip, thrown away with it.
///
/// Stands in for everything the app keeps on the device, so a restore or a backup changes nothing of the app the tests
/// run in:
///
/// - The database is a ``TestDatabase``.
/// - The identity, which the app keeps in the keychain, is a ``MyIdentityStoreMock``.
/// - The settings and push settings, which the app keeps in the user defaults, are a ``UserSettingsMock``.
/// - The contact store is a ``ContactStoreMock``. Like the app's, it adds the Work contacts to these settings, where
///   the backup reads them from.
/// - The work availability status and the record of the last backup are in a user defaults suite of its own.
/// - The backup is written to the documents directory under the name libthreema gives it, like the app's, and moved
///   out to where the round trip expects it right after.
///
/// Everything on top of this storage is the app's own code: the restore and backup managers, the providers, the profile
/// store and the push setting manager.
///
/// Deliberately not on the main actor: the restore and the backup call into the providers built here from their own
/// threads.
final class BackupTestEnvironment {

    let database = TestDatabase()
    let myIdentityStore = MyIdentityStoreMock()
    let userSettings = UserSettingsMock()
    let contactStore = ContactStoreMock()

    // MARK: - Private properties

    private let defaultsSuiteName: String
    private let defaults: UserDefaults

    // MARK: - Lifecycle

    init() {
        let name = "BackupTestEnvironment-\(UUID().uuidString)"

        self.defaultsSuiteName = name
        // Only `nil` for the name of a global domain.
        self.defaults = UserDefaults(suiteName: name)!

        // A new device has no identity yet. The restore puts the one of the backup here.
        myIdentityStore.identity = nil
        myIdentityStore.clientKey = nil
        myIdentityStore.publicKey = nil

        contactStore.userSettings = userSettings
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: defaultsSuiteName)
    }

    // MARK: - Internal methods

    /// Restores the backup at `url` the way the app does: first the identity, then the data.
    func restore(from url: URL, password: String) async throws {
        let identityManager = BackupRestoreIdentityManager(
            myIdentityStore: myIdentityStore,
            fileUtility: FileUtility()
        )
        _ = try await identityManager.restoreIdentity(from: url, password: password)

        let dataManager = BackupRestoreDataManager(
            myIdentityStore: myIdentityStore,
            providersFactory: makeProvidersFactory(),
            entityManager: database.backgroundEntityManager,
            fileUtility: FileUtility()
        )
        for try await _ in dataManager.restore(url: url, password: password) { }
    }

    /// Backs up what is on this device the way the app does, into the file at `url`. An existing file is replaced, a
    /// failed backup leaves no file behind.
    func backup(to url: URL, password: String) async throws {
        // Removed first, so a failed backup does not leave the file of an earlier run behind.
        FileUtility().deleteIfExists(at: url)

        // Without a host app the documents directory is the simulator's own, which a newly erased simulator does not
        // have yet. The backup cannot create its file without it.
        try FileUtility().mkDir(at: .documentsDirectory, withIntermediateDirectories: true, attributes: nil)

        let createManager = BackupCreateManager(
            myIdentityStore: myIdentityStore,
            providersFactory: makeProvidersFactory(),
            fileUtility: FileUtility(),
            encryptionKeyService: NoRecoveryKeyService(),
            userDefaults: defaults,
            dateProvider: Date.init
        )
        for try await _ in createManager.create(password: password) { }

        // Recorded like the app does, because only the record tells where libthreema named the file. It goes to the
        // user defaults suite of this environment, which has no earlier backup the record would delete.
        try createManager.recordSuccessfulBackup()
        guard let backupURL = createManager.backupURL else {
            throw BackupCreateManagerError.missingBackupFile
        }
        try FileUtility().move(from: backupURL, to: url)
    }

    // MARK: - Private methods

    /// The providers the app restores into and backs up from, built on the storage of this environment.
    private func makeProvidersFactory() -> DataBackupProvidersFactory {
        let pushSettingManager = PushSettingManager(
            userSettings: userSettings,
            groupManager: GroupManagerMock(myIdentityStore),
            entityManager: database.backgroundEntityManager,
            markupParser: MarkupParser(),
            taskManager: TaskManagerMock(),
            isWorkApp: false
        )

        return DataBackupProvidersFactory(
            makeProfileStore: { [myIdentityStore, contactStore, userSettings, defaults] identity in
                ProfileStore(
                    serverConnector: ServerConnectorMock(),
                    myIdentity: identity,
                    myIdentityStore: myIdentityStore,
                    contactStore: contactStore,
                    userSettings: userSettings,
                    taskManager: nil,
                    workAvailabilityStatusManager: WorkAvailabilityStatusManager(defaults: defaults),
                    workPropertiesUpdateManager: nil
                )
            },
            userSettings: userSettings,
            entityManager: database.backgroundEntityManager,
            makeContactStore: { [contactStore] in contactStore },
            makePushSettingManager: { pushSettingManager }
        )
    }
}

// MARK: - NoRecoveryKeyService

/// The recovery key the app keeps in the keychain is not part of a round trip: a backup is encrypted with the password
/// it is created with.
private final class NoRecoveryKeyService: BackupEncryptionKeyServiceProtocol {

    var currentKey: BackupEncryptionKey {
        .none
    }

    func renewKey() throws { }

    func deleteKey() throws { }

    func markKeyAsDefault() throws { }
}
