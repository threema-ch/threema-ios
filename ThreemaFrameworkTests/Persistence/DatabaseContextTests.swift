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
import Testing
@testable import ThreemaFramework

// These might fail. For some inspiration on how to fix them see
// https://forums.swift.org/t/swift-testing-core-data-setup-teardown/75203
@Suite(
    "Database Context",
    .disabled(
        "When executed in the full test suite there seems to be a race condition leading to unexpected results. Running them on their own should work."
    )
)
struct DatabaseContextTests {
    
    @Suite("Database Context Initialization")
    struct DatabaseContextInitialization {
        @Test("Basic main initialization")
        func basicMainInit() async throws {
            let (persistentCoordinator, _, _) = DatabasePersistentContext.devNullContext()
            
            let databaseContext = DatabaseContext(persistentStoreCoordinator: persistentCoordinator)
            
            try checkInitializedMainContext(databaseContext)
            
            #expect(databaseContext.main == databaseContext.current)
        }
        
        func checkInitializedMainContext(_ databaseContext: DatabaseContext) throws {
            #expect(databaseContext.main.concurrencyType == .mainQueueConcurrencyType)
            #expect(databaseContext.main.automaticallyMergesChangesFromParent == true)
            let mainMergePolicy = try #require(databaseContext.main.mergePolicy as? NSMergePolicy)
            #expect(mainMergePolicy.mergeType == .overwriteMergePolicyType)
        }
        
        @Test("Basic background child context initialization")
        func basicChildInit() async throws {
            let (persistentCoordinator, _, _) = DatabasePersistentContext.devNullContext()
            
            let databaseContext = DatabaseContext(
                persistentStoreCoordinator: persistentCoordinator,
                withChildContextInBackground: true
            )
            
            try checkInitializedMainContext(databaseContext)
            
            #expect(databaseContext.current != databaseContext.main)
            #expect(databaseContext.current.concurrencyType == .privateQueueConcurrencyType)
            let mergePolicy = try #require(databaseContext.current.mergePolicy as? NSMergePolicy)
            #expect(mergePolicy.mergeType == .mergeByPropertyStoreTrumpMergePolicyType)
            #expect(databaseContext.current.parent == databaseContext.main)
            #expect(databaseContext.current.automaticallyMergesChangesFromParent == true)
        }
        
        @Test("Basic main child context initialization")
        func basicMainChildInit() async throws {
            let (persistentCoordinator, _, _) = DatabasePersistentContext.devNullContext()
            
            let databaseContext = DatabaseContext(
                persistentStoreCoordinator: persistentCoordinator,
                withChildContextInBackground: false
            )
            
            try checkInitializedMainContext(databaseContext)
            
            #expect(databaseContext.current != databaseContext.main)
            #expect(databaseContext.current.concurrencyType == .mainQueueConcurrencyType)
            let mergePolicy = try #require(databaseContext.current.mergePolicy as? NSMergePolicy)
            #expect(mergePolicy.mergeType == .mergeByPropertyStoreTrumpMergePolicyType)
            #expect(databaseContext.current.parent == databaseContext.main)
            #expect(databaseContext.current.automaticallyMergesChangesFromParent == true)
        }
    }
    
    @Suite("Database Context Direct Contexts")
    struct DatabaseContextDirectContexts {
        
        @Test("Direct contexts")
        func fullDirectContexts() throws {
            let (persistentCoordinator, _, _) = DatabasePersistentContext.devNullContext()

            // Initially there should be no direct context
            let mainDatabaseContext = DatabaseContext(persistentStoreCoordinator: persistentCoordinator)
            #expect(mainDatabaseContext.directContexts.isEmpty)
            
            // Add direct context and validate that there is no parent
            let directManagedObjectContext = DatabaseContext.directBackgroundContext(with: persistentCoordinator)
            #expect(directManagedObjectContext.concurrencyType == .privateQueueConcurrencyType)
            #expect(directManagedObjectContext.parent == nil)
            
            // No there should be one direct context
            try #require(mainDatabaseContext.directContexts.count == 1)
            #expect(mainDatabaseContext.directContexts.contains(directManagedObjectContext))
            
            // Remove. Now there should be no more direct context left
            DatabaseContext.removeDirectBackgroundContext(directManagedObjectContext)
            #expect(mainDatabaseContext.directContexts.isEmpty)
        }
    }
}
