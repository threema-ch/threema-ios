//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2025 Threema GmbH
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
import XCTest
@testable import ThreemaFramework

public class DatabasePersistentContext {
    // The CD in memory persistent store doesn't support derived attributes:
    // "Core Data provided atomic stores do not support derived properties (NSInvalidArgumentException)"
    // Thus the function to create one was removed.

    public static var modelURL: URL? = BundleUtil.url(
        forResource: DatabaseManager.databaseModelName,
        withExtension: "momd"
    )

    /// Context in memory, doesn't work with NSBatch... commands (use devNullContext)
    ///
    /// - Returns:
    ///    DB context for testing
    static func inMemoryContext() -> ThreemaManagedObjectContext {
        let modelURL = BundleUtil.url(
            forResource: DatabaseManager.databaseModelName,
            withExtension: "momd"
        )
        let managedObjectContext = NSManagedObjectModel(contentsOf: modelURL!)
        let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectContext!)
        do {
            try persistentStoreCoordinator.addPersistentStore(
                ofType: NSInMemoryStoreType,
                configurationName: nil,
                at: nil,
                options: nil
            )
        }
        catch {
            fatalError("Adding in memory persistent store failed")
        }

        let context = ThreemaManagedObjectContext(
            concurrencyType: NSManagedObjectContextConcurrencyType
                .mainQueueConcurrencyType
        )
        context.persistentStoreCoordinator = persistentStoreCoordinator

        return context
    }

    /// Context stored data to /dev/null, works with NSBatch... commands
    /// - Parameters:
    ///   - withChildContextForBackgroundProcess: Whether to add a child context, `false` by default
    ///   - isRemoteSecretEnabled: Whether to use the encrypted DB model, `false` by default
    ///  - Returns:
    ///   DB context for testing
    public static func devNullContext(
        withChildContextForBackgroundProcess: Bool = false,
        isRemoteSecretEnabled: Bool = false
    ) -> (
        persistentStoreCoordinator: NSPersistentStoreCoordinator,
        mainContext: ThreemaManagedObjectContext,
        childContext: ThreemaManagedObjectContext?
    ) {
        let modelName = isRemoteSecretEnabled ? DatabaseManager.databaseEncryptedModelName : DatabaseManager
            .databaseModelName
        var modelURL = BundleUtil.url(
            forResource: modelName,
            withExtension: "momd"
        )
        // Hack, because of could not load omo file?!?!
        modelURL = modelURL?.appendingPathComponent("ThreemaDataV\(DatabaseManager.databaseModelVersion).mom")
        let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL!)
        let container = NSPersistentContainer(name: "TestData", managedObjectModel: managedObjectModel!)
        container.persistentStoreDescriptions[0].url = URL(fileURLWithPath: "/dev/null")
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }

        let mainContext = ThreemaManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        mainContext.persistentStoreCoordinator = container.persistentStoreCoordinator

        var childContext: ThreemaManagedObjectContext?
        if withChildContextForBackgroundProcess {
            childContext = ThreemaManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            childContext?.parent = mainContext
        }

        return (container.persistentStoreCoordinator, mainContext, childContext)
    }
}
