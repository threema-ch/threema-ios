import CoreData
import FileUtility
import FileUtilityTestHelper
import RemoteSecretProtocolTestHelper
import Testing
@testable import ThreemaFramework

/// Note that the DB must be created in a real physical path, because Core Data is not mocked.
@MainActor
@Suite("Database Manager", .serialized)
final class DatabaseManagerTests {
    let appGroupID = "group.ch.threema"
    var appDataDirectoryURL: URL!

    enum DatabaseManagerTestsError: Error {
        case appDataDirectoryNotFound
    }

    init() throws {
        FileUtility.updateSharedInstance(with: FileUtility())

        self.appDataDirectoryURL = FileUtility.shared.appDataDirectory(appGroupID: appGroupID)?
            .appendingPathComponent("unit-test")

        guard let appDataDirectoryURL else {
            throw DatabaseManagerTestsError.appDataDirectoryNotFound
        }

        print(appDataDirectoryURL)
        try FileUtility.shared.mkDir(
            at: appDataDirectoryURL,
            withIntermediateDirectories: false,
            attributes: nil
        )
    }

    deinit {
        DatabaseManager.localPersistentStoreCoordinator?.persistentStores.forEach { store in
            do {
                try DatabaseManager.localPersistentStoreCoordinator?.remove(store)
            }
            catch {
                print(error)
            }
        }
        DatabaseManager.localPersistentStoreCoordinator = nil

        [
            appDataDirectoryURL.appendingPathComponent("ThreemaData.sqlite"),
            appDataDirectoryURL.appendingPathComponent("ThreemaData.sqlite-shm"),
            appDataDirectoryURL.appendingPathComponent("ThreemaData.sqlite-wal"),
            appDataDirectoryURL,
        ].forEach { url in
            FileUtility.shared.deleteIfExists(at: url)
        }
    }

    @Test func `Require migration with database not exists`() {
        let fileUtilityMock = FileUtilityMock()
        fileUtilityMock.mockAppDataDirectory = { _ in URL(string: "/data/") }
        fileUtilityMock.appDocumentsDirectory = URL(string: "/documents/")

        let databaseManager = DatabaseManager(
            appGroupID: appGroupID,
            fileUtility: fileUtilityMock,
            remoteSecretManager: RemoteSecretManagerMock()
        )

        #expect(databaseManager.storeRequiresMigration() == .none)
    }

    @Test func `Require migration with database exists`() {
        // Config
        createTestDB(forMigration: true)
        let storeURL = appDataDirectoryURL.appendingPathComponent(DatabaseManager.databaseFileName)

        let fileUtilityMock = FileUtilityMock()
        fileUtilityMock.mockAppDataDirectory = { _ in self.appDataDirectoryURL }
        fileUtilityMock.appDocumentsDirectory = URL(string: "/documents/")
        fileUtilityMock.mockFileExistsAtURL = { $0 == storeURL }

        // Act
        let databaseManager = DatabaseManager(
            appGroupID: appGroupID,
            fileUtility: fileUtilityMock,
            remoteSecretManager: RemoteSecretManagerMock()
        )

        // Test
        #expect(databaseManager.storeRequiresMigration() == .required)
    }

    @Test func `None migration required. Test migration of old external storage backup`() throws {
        // Config
        let urlToExternalStorage = appDataDirectoryURL.appendingPathComponent(
            DatabaseManager.databaseExternalStoragePath,
            isDirectory: true
        )
        let tmpURLToExternalStorage = appDataDirectoryURL.appendingPathComponent(
            DatabaseManager.databaseTemporaryExternalStoragePath,
            isDirectory: true
        )

        let fileUtilityMock = FileUtilityMock()
        fileUtilityMock.mockAppDataDirectory = { _ in self.appDataDirectoryURL }
        fileUtilityMock.appDocumentsDirectory = URL(string: "/documents/")
        fileUtilityMock.mockFileExistsAtURL = { $0 == tmpURLToExternalStorage }

        // Act
        _ = try DatabaseManager(
            appGroupID: appGroupID,
            fileUtility: fileUtilityMock,
            remoteSecretManager: RemoteSecretManagerMock()
        )
        .persistentStoreCoordinator

        // Test
        #expect(fileUtilityMock.calls.contains(.fileExistsAtURL(tmpURLToExternalStorage)))
        #expect(
            fileUtilityMock.calls
                .count(where: { $0 == .mergeContentsOfPath(from: tmpURLToExternalStorage, to: urlToExternalStorage) })
                == 1
        )
        #expect(fileUtilityMock.calls.contains(.deleteIfExists(tmpURLToExternalStorage)))
        #expect(
            fileUtilityMock.calls.contains { call in
                guard case let .fileExistsAtURL(url) = call else {
                    return false
                }
                return url?.lastPathComponent.hasPrefix("\(DatabaseManager.databaseFileName).bak") ?? false
            }
        )
    }

    @Test func `Migration required. Test backup of the database files and the clean up`() throws {
        // Config
        createTestDB(forMigration: true)

        let urlToExternalStorage = appDataDirectoryURL.appendingPathComponent(
            DatabaseManager.databaseExternalStoragePath,
            isDirectory: true
        )
        let tmpURLToExternalStorage = appDataDirectoryURL.appendingPathComponent(
            DatabaseManager.databaseTemporaryExternalStoragePath,
            isDirectory: true
        )

        let storeURL = appDataDirectoryURL.appendingPathComponent(DatabaseManager.databaseFileName)
        let urlToBackupStorePrefix = URL(
            fileURLWithPath: storeURL.absoluteURL.path.appending(".bak.\(DatabaseManager.databaseModelVersion)"),
            isDirectory: false
        )
        let tmpURLToBackupStorePrefix = URL(
            fileURLWithPath: urlToBackupStorePrefix.absoluteURL.path.appending("."),
            isDirectory: false
        )

        let walURL = URL(fileURLWithPath: storeURL.absoluteURL.path.appending("-wal"), isDirectory: false)
        let urlToBackupWalPrefix = URL(
            fileURLWithPath: walURL.absoluteURL.path.appending(".bak.\(DatabaseManager.databaseModelVersion)"),
            isDirectory: false
        )
        let tmpURLToBackupWalPrefix = URL(
            fileURLWithPath: urlToBackupWalPrefix.absoluteURL.path.appending("."),
            isDirectory: false
        )

        let shmURL = URL(fileURLWithPath: storeURL.absoluteURL.path.appending("-shm"), isDirectory: false)
        let urlToBackupShmPrefix = URL(
            fileURLWithPath: shmURL.absoluteURL.path.appending(".bak.\(DatabaseManager.databaseModelVersion)"),
            isDirectory: false
        )
        let tmpURLToBackupShmPrefix = URL(
            fileURLWithPath: urlToBackupShmPrefix.absoluteURL.path.appending("."),
            isDirectory: false
        )

        let fileUtilityMock = FileUtilityMock()
        fileUtilityMock.mockAppDataDirectory = { _ in self.appDataDirectoryURL }
        fileUtilityMock.appDocumentsDirectory = URL(string: "/documents/")
        fileUtilityMock.mockFileExistsAtURL = { $0 == storeURL || $0 == urlToExternalStorage }

        // Act
        _ = try DatabaseManager(
            appGroupID: appGroupID,
            fileUtility: fileUtilityMock,
            remoteSecretManager: RemoteSecretManagerMock()
        )
        .persistentStoreCoordinator

        // Test

        // Backup Store before migration
        #expect(
            fileUtilityMock.calls.count(where: { call in
                guard case let .copy(from, to) = call else {
                    return false
                }
                return from == storeURL && to.lastPathComponent.hasPrefix(tmpURLToBackupStorePrefix.lastPathComponent)
            }) == 1,
            "Copy of store to tmp backup file"
        )
        #expect(
            fileUtilityMock.calls.count(where: { call in
                guard case let .moveURL(from, to) = call else {
                    return false
                }
                return from.lastPathComponent.hasPrefix(tmpURLToBackupStorePrefix.lastPathComponent)
                    && to.lastPathComponent.hasPrefix(urlToBackupStorePrefix.lastPathComponent)
            }) == 1,
            "Move of store tmp backup file to backup file"
        )

        #expect(
            fileUtilityMock.calls.count(where: { call in
                guard case let .copy(from, to) = call else {
                    return false
                }
                return from == walURL && to.lastPathComponent.hasPrefix(tmpURLToBackupWalPrefix.lastPathComponent)
            }) == 1,
            "Copy of wal to tmp backup file"
        )
        #expect(
            fileUtilityMock.calls.count(where: { call in
                guard case let .moveURL(from, to) = call else {
                    return false
                }
                return from.lastPathComponent.hasPrefix(tmpURLToBackupWalPrefix.lastPathComponent)
                    && to.lastPathComponent.hasPrefix(urlToBackupWalPrefix.lastPathComponent)
            }) == 1,
            "Move of wal tmp backup file to backup file"
        )

        #expect(
            fileUtilityMock.calls.count(where: { call in
                guard case let .copy(from, to) = call else {
                    return false
                }
                return from == shmURL && to.lastPathComponent.hasPrefix(tmpURLToBackupShmPrefix.lastPathComponent)
            }) == 1,
            "Copy of shm to tmp backup file"
        )
        #expect(
            fileUtilityMock.calls.count(where: { call in
                guard case let .moveURL(from, to) = call else {
                    return false
                }
                return from.lastPathComponent.hasPrefix(tmpURLToBackupShmPrefix.lastPathComponent)
                    && to.lastPathComponent.hasPrefix(urlToBackupShmPrefix.lastPathComponent)
            }) == 1,
            "Move of shm tmp backup file to backup file"
        )

        // Extrenal Storage merge and remove after migration
        #expect(fileUtilityMock.calls.count(where: { $0 == .fileExistsAtURL(urlToExternalStorage) }) == 1)

        #expect(fileUtilityMock.calls.count(where: { $0 == .fileExistsAtURL(tmpURLToExternalStorage) }) == 1)

        #expect(
            fileUtilityMock.calls
                .count(where: { $0 == .moveURL(from: urlToExternalStorage, to: tmpURLToExternalStorage) }) == 1,
            "Move of external storage to backup dictionary"
        )

        #expect(
            fileUtilityMock.calls
                .count(where: { $0 == .mergeContentsOfPath(from: tmpURLToExternalStorage, to: urlToExternalStorage) })
                == 1,
            "Merge of tmp backup directory to external storage"
        )

        #expect(
            fileUtilityMock.calls.count(where: { $0 == .deleteIfExists(tmpURLToExternalStorage) }) == 1,
            "Delete of tmp backup directory, after migration"
        )

        #expect(
            fileUtilityMock.calls.contains { call in
                guard case let .fileExistsAtURL(url) = call else {
                    return false
                }
                return url?.lastPathComponent.hasPrefix("\(DatabaseManager.databaseFileName).bak") ?? false
            }
        )

        #expect(
            fileUtilityMock.calls.count(where: { $0 == .dir(at: appDataDirectoryURL) }) == 2,
            "Called from `removeMigrationLeftover` function 2 times, before and after migration"
        )
    }

    @Test func `Erase existing database`() throws {
        // Config
        createTestDB()

        let storeURL = appDataDirectoryURL.appendingPathComponent(DatabaseManager.databaseFileName)
        let fileUtilityMock = FileUtilityMock()
        fileUtilityMock.mockAppDataDirectory = { _ in self.appDataDirectoryURL }
        fileUtilityMock.appDocumentsDirectory = URL(string: "/documents/")
        fileUtilityMock.mockFileExistsAtURL = { $0 == storeURL }

        let databaseManager = DatabaseManager(
            appGroupID: appGroupID,
            fileUtility: fileUtilityMock,
            remoteSecretManager: RemoteSecretManagerMock()
        )

        // Sanity: opening the coordinator registers the SQLite store created by the createTestDB() method
        let coordinator = try databaseManager.persistentStoreCoordinator
        #expect(coordinator.persistentStores.contains(where: { $0.url == storeURL }) == true)

        // Act
        try databaseManager.eraseDB()

        // Test
        #expect(coordinator.persistentStores.isEmpty == true)
        #expect(DatabaseManager.localPersistentStoreCoordinator == nil)

        #expect(fileUtilityMock.calls.contains(.deleteIfExists(storeURL)))
        #expect(
            fileUtilityMock.calls.contains(.deleteIfExists(
                URL(fileURLWithPath: storeURL.path.appending("-wal"))
            ))
        )
        #expect(
            fileUtilityMock.calls.contains(.deleteIfExists(
                URL(fileURLWithPath: storeURL.path.appending("-shm"))
            ))
        )
    }

    /// Creates a physical ThreemaData database for testing.
    /// - Parameter forMigration: True causes a dynamically change of the model to force a migration
    private func createTestDB(forMigration: Bool = false) {
        guard let objectModelURL = DatabaseContextMock.modelURL else {
            fatalError("Could not find Managed Object Model")
        }

        // Load copied Object Model to modify dynamically
        guard let objectModel = NSManagedObjectModel(contentsOf: objectModelURL)?.copy() as? NSManagedObjectModel else {
            fatalError("Could not load Managed Object Model")
        }

        let databaseFilePathURL = appDataDirectoryURL.appendingPathComponent(DatabaseManager.databaseFileName)

        do {
            // Modify Object Model dynamically to force migration for testing
            if forMigration, let contactEntity = objectModel.entitiesByName["Contact"] {
                contactEntity.uniquenessConstraints = [["identity"]]
            }

            let dbOptions = [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true,
                NSSQLiteManualVacuumOption: "INCREMENTAL",
            ] as [String: Any]

            // If database file exists, than check for migration
            if FileUtility.shared.fileExists(at: databaseFilePathURL) {

                let hasDbChanged = try !objectModel.isConfiguration(
                    withName: nil,
                    compatibleWithStoreMetadata:
                    NSPersistentStoreCoordinator.metadataForPersistentStore(
                        ofType: NSSQLiteStoreType,
                        at: databaseFilePathURL,
                        options: dbOptions
                    )
                )

                if hasDbChanged {
                    let storeCoordinator = NSPersistentStoreCoordinator(managedObjectModel: objectModel)
                    try storeCoordinator.addPersistentStore(
                        ofType: NSSQLiteStoreType,
                        configurationName: nil,
                        at: databaseFilePathURL,
                        options: dbOptions
                    )
                }
            }
            else {
                let storeCoordinator = NSPersistentStoreCoordinator(managedObjectModel: objectModel)
                try storeCoordinator.addPersistentStore(
                    ofType: NSSQLiteStoreType,
                    configurationName: nil,
                    at: databaseFilePathURL,
                    options: dbOptions
                )
                for store in storeCoordinator.persistentStores {
                    try? storeCoordinator.remove(store)
                }
            }
        }
        catch {
            print("\(error)")
            fatalError()
        }
    }
}
