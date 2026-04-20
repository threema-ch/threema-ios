import CoreData
import FileUtility
import FileUtilityTestHelper
import RemoteSecretProtocolTestHelper
import Testing
@testable import ThreemaFramework

@Suite("Database Manager", .serialized)
/// Note that the DB must be craete in a real physical path, because Core Data is not mocked.
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

    @Test("Require migration with database not exists")
    func storeRequiresMigrationNoneDatabaseNotExists() {
        let fileUtilityMock = FileUtilityMock()
        fileUtilityMock.appDataDirectory = URL(string: "/data/")
        fileUtilityMock.appDocumentsDirectory = URL(string: "/documents/")

        let databaseManager = DatabaseManager(
            appGroupID: appGroupID,
            fileUtility: fileUtilityMock,
            remoteSecretManager: RemoteSecretManagerMock()
        )

        #expect(databaseManager.storeRequiresMigration() == .none)
    }

    @Test("Require migration with database exists")
    func storeRequiresMigrationNoneDatabaseExists() {
        // Config
        createTestDB(forMigration: true)
        let storeURL = appDataDirectoryURL.appendingPathComponent(DatabaseManager.databaseFileName)

        let fileUtilityMock = FileUtilityMock()
        fileUtilityMock.appDataDirectory = appDataDirectoryURL
        fileUtilityMock.appDocumentsDirectory = URL(string: "/documents/")
        fileUtilityMock.content.append(storeURL)

        // Act
        let databaseManager = DatabaseManager(
            appGroupID: appGroupID,
            fileUtility: fileUtilityMock,
            remoteSecretManager: RemoteSecretManagerMock()
        )

        // Test
        #expect(databaseManager.storeRequiresMigration() == .required)
    }

    @Test("None migration required. Test migration of old external storage backup")
    func persistentStoreCoordinatorMigrationNone() throws {
        // Config
        let urlToExternalStorage = appDataDirectoryURL.appendingPathComponent(
            DatabaseManager.databaseExternalStoragePath,
            isDirectory: true
        )
        let tmpURLToExternalStorage = appDataDirectoryURL.appendingPathComponent(
            DatabaseManager.databaseTemporaryExternalStoragePath,
            isDirectory: true
        )

        let fileUtilityMock = FileUtilityMock(content: [
            tmpURLToExternalStorage,
        ])
        fileUtilityMock.appDataDirectory = appDataDirectoryURL
        fileUtilityMock.appDocumentsDirectory = URL(string: "/documents/")

        // Act
        _ = try DatabaseManager(
            appGroupID: appGroupID,
            fileUtility: fileUtilityMock,
            remoteSecretManager: RemoteSecretManagerMock()
        )
        .persistentStoreCoordinator

        // Test
        #expect(fileUtilityMock.isExistsCalledWithFileURL.contains(tmpURLToExternalStorage) == true)
        #expect(
            fileUtilityMock.mergeContentsOfPathCalledWithFromTo
                .count(where: { $0.0 == tmpURLToExternalStorage && $0.1 == urlToExternalStorage
                }) == 1
        )
        #expect(fileUtilityMock.deleteIfExistsCalledWithSourceURL.contains(tmpURLToExternalStorage) == true)
        #expect(
            fileUtilityMock.isExistsCalledWithFileURL
                .contains(
                    where: { url in
                        url.lastPathComponent.hasPrefix("\(DatabaseManager.databaseFileName).bak")
                    }
                ) == true
        )
    }

    @Test("Migration required. Test backup of the database files and the clean up")
    func persistentStoreCoordinatorMigrationReqired() throws {
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

        let fileUtilityMock = FileUtilityMock(content: [storeURL, urlToExternalStorage])
        fileUtilityMock.appDataDirectory = appDataDirectoryURL
        fileUtilityMock.appDocumentsDirectory = URL(string: "/documents/")

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
            fileUtilityMock.copyCalledWithFromTo
                .count(
                    where: {
                        $0.0 == storeURL && $0.1.lastPathComponent
                            .hasPrefix(tmpURLToBackupStorePrefix.lastPathComponent)
                    }
                ) == 1,
            "Copy of store to tmp backup file"
        )
        #expect(
            fileUtilityMock.moveCalledWithFromTo
                .count(
                    where: {
                        $0.0.lastPathComponent.hasPrefix(tmpURLToBackupStorePrefix.lastPathComponent) && $0.1
                            .lastPathComponent.hasPrefix(urlToBackupStorePrefix.lastPathComponent)
                    }
                ) == 1,
            "Move of store tmp backup file to backup file"
        )

        #expect(
            fileUtilityMock.copyCalledWithFromTo
                .count(
                    where: {
                        $0.0 == walURL && $0.1.lastPathComponent.hasPrefix(tmpURLToBackupWalPrefix.lastPathComponent)
                    }
                ) == 1,
            "Copy of wal to tmp backup file"
        )
        #expect(
            fileUtilityMock.moveCalledWithFromTo
                .count(
                    where: {
                        $0.0.lastPathComponent.hasPrefix(tmpURLToBackupWalPrefix.lastPathComponent) && $0.1
                            .lastPathComponent.hasPrefix(urlToBackupWalPrefix.lastPathComponent)
                    }
                ) == 1,
            "Move of wal tmp backup file to backup file"
        )

        #expect(
            fileUtilityMock.copyCalledWithFromTo
                .count(
                    where: {
                        $0.0 == shmURL && $0.1.lastPathComponent.hasPrefix(tmpURLToBackupShmPrefix.lastPathComponent)
                    }
                ) == 1,
            "Copy of shm to tmp backup file"
        )
        #expect(
            fileUtilityMock.moveCalledWithFromTo
                .count(
                    where: {
                        $0.0.lastPathComponent.hasPrefix(tmpURLToBackupShmPrefix.lastPathComponent) && $0.1
                            .lastPathComponent.hasPrefix(urlToBackupShmPrefix.lastPathComponent)
                    }
                ) == 1,
            "Move of shm tmp backup file to backup file"
        )

        // Extrenal Storage merge and remove after migration
        #expect(fileUtilityMock.isExistsCalledWithFileURL.count(where: { $0 == urlToExternalStorage }) == 1)

        #expect(fileUtilityMock.isExistsCalledWithFileURL.count(where: { $0 == tmpURLToExternalStorage }) == 1)

        #expect(
            fileUtilityMock.moveCalledWithFromTo
                .count(where: { $0.0 == urlToExternalStorage && $0.1 == tmpURLToExternalStorage }) == 1,
            "Move of external storage to backup dictionary"
        )

        #expect(
            fileUtilityMock.mergeContentsOfPathCalledWithFromTo
                .count(where: { $0.0 == tmpURLToExternalStorage && $0.1 == urlToExternalStorage }) == 1,
            "Merge of tmp backup directory to external storage"
        )

        #expect(
            fileUtilityMock.deleteIfExistsCalledWithSourceURL.count(where: { $0 == tmpURLToExternalStorage }) == 1,
            "Delete of tmp backup directory, after migration"
        )

        #expect(
            fileUtilityMock.isExistsCalledWithFileURL
                .contains(
                    where: { url in
                        url.lastPathComponent.hasPrefix("\(DatabaseManager.databaseFileName).bak")
                    }
                ) == true
        )

        #expect(
            fileUtilityMock.dirCalledWithSourceURL.count(where: { $0 == appDataDirectoryURL }) == 2,
            "Called from `removeMigrationLeftover` function 2 times, before and after migration"
        )
    }

    @Test("Erase existing database")
    func eraseDB() throws {
        // Config
        createTestDB()

        let storeURL = appDataDirectoryURL.appendingPathComponent(DatabaseManager.databaseFileName)
        let fileUtilityMock = FileUtilityMock()
        fileUtilityMock.appDataDirectory = appDataDirectoryURL
        fileUtilityMock.appDocumentsDirectory = URL(string: "/documents/")
        fileUtilityMock.content.append(storeURL)

        // Act
        let databaseManager = DatabaseManager(
            appGroupID: appGroupID,
            fileUtility: fileUtilityMock,
            remoteSecretManager: RemoteSecretManagerMock()
        )
        try databaseManager.eraseDB()

        // Test
        #expect(fileUtilityMock.isExistsCalledWithFileURL.contains(storeURL) == true)
        #expect(fileUtilityMock.deleteCalledWithSourceURL.contains(storeURL) == true)
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
