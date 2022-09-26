//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2021 Threema GmbH
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

class DatabasePersistentContext {
    
    /// Context in memory, doesn't work with NSBatch... commands (use devNullContext)
    ///
    /// - Returns:
    ///    DB context for testing
    static func inMemoryContext() -> TMAManagedObjectContext {
        let modelURL = BundleUtil.url(forResource: "ThreemaData", withExtension: "momd")
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
        
        let context = TMAManagedObjectContext(
            concurrencyType: NSManagedObjectContextConcurrencyType
                .mainQueueConcurrencyType
        )
        context.persistentStoreCoordinator = persistentStoreCoordinator
        
        return context
    }
    
    ///  Context stored data to /dev/null, works with NSBatch... commands
    ///
    /// - Returns:
    ///    DB context for testing
    static func devNullContext()
        -> (
            persistentStoreCoordinator: NSPersistentStoreCoordinator,
            mainContext: TMAManagedObjectContext,
            backgroundContext: NSManagedObjectContext
        ) {
        var modelURL = BundleUtil.url(forResource: "ThreemaData", withExtension: "momd")
        let coreDataModelVersion = BundleUtil.object(forInfoDictionaryKey: "ThreemaCoreDataVersion") as! String
        modelURL = modelURL?
            .appendingPathComponent("ThreemaDataV\(coreDataModelVersion).mom") // Hack, because of could not load omo file?!?!
        let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL!)
        let container = NSPersistentContainer(name: "TestData", managedObjectModel: managedObjectModel!)
        container.persistentStoreDescriptions[0].url = URL(fileURLWithPath: "/dev/null")
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }
            
        let cont = TMAManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        cont.persistentStoreCoordinator = container.persistentStoreCoordinator

        return (container.persistentStoreCoordinator, cont, container.newBackgroundContext())
    }
}
