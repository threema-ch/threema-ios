//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import CoreData
import FileUtility
@testable import ThreemaFramework

public class DatabaseManagerMock: DatabaseManagerProtocol {

    private let _persistentStoreCoordinator: NSPersistentStoreCoordinator
    private let _databaseContext: DatabaseContext

    public required init(
        persistentStoreCoordinator: NSPersistentStoreCoordinator,
        databaseContext: DatabaseContext
    ) {
        self._persistentStoreCoordinator = persistentStoreCoordinator
        self._databaseContext = databaseContext
    }

    public var persistentStoreCoordinator: NSPersistentStoreCoordinator {
        _persistentStoreCoordinator
    }

    public func databaseContext() -> DatabaseContext {
        _databaseContext
    }

    public func databaseContext(withChildContextForBackgroundProcess: Bool) -> DatabaseContext {
        _databaseContext
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
