import CoreData
import FileUtility
@testable import ThreemaFramework

public final class DatabaseManagerMock: DatabaseManagerProtocol {

    private let _persistentStoreCoordinator: NSPersistentStoreCoordinator
    private let _databaseContext: DatabaseContextProtocol
    private let _backgroundDatabaseContext: DatabaseContextProtocol

    public required init(
        persistentStoreCoordinator: NSPersistentStoreCoordinator,
        databaseContext: DatabaseContextProtocol,
        backgroundDatabaseContext: DatabaseContextProtocol
    ) {
        self._persistentStoreCoordinator = persistentStoreCoordinator
        self._databaseContext = databaseContext
        self._backgroundDatabaseContext = backgroundDatabaseContext
    }

    public var persistentStoreCoordinator: NSPersistentStoreCoordinator {
        _persistentStoreCoordinator
    }

    public func databaseContext() -> DatabaseContextProtocol {
        _databaseContext
    }

    public func databaseContext(withChildContextForBackgroundProcess: Bool) -> DatabaseContextProtocol {
        if withChildContextForBackgroundProcess {
            _backgroundDatabaseContext
        }
        else {
            databaseContext()
        }
    }

    public static func storeRequiresImport(fileUtility: FileUtilityProtocol) -> Bool {
        false
    }

    public func checkFreeDiskSpaceForDatabaseMigration() throws {
        // no-op
    }

    public static func dbExists(appGroupID: String, fileUtility: any FileUtilityProtocol) -> Bool {
        false
    }

    public func storeRequiresMigration() -> ThreemaFramework.DatabaseManager.StoreRequiresMigration {
        .none
    }

    public func migrateDB() throws {
        // no-op
    }

    public func importOldVersionDatabase() throws -> Bool {
        false
    }

    public func importRepairedDatabase() throws {
        // no-op
    }

    public func eraseDB() throws {
        // no-op
    }
}
