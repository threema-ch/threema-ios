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
            let testDatabase = TestDatabase()

            let databaseContext = DatabaseContext(
                persistentStoreCoordinator: testDatabase.databaseManagerMock
                    .persistentStoreCoordinator
            )

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
            let testDatabase = TestDatabase()

            let databaseContext = DatabaseContext(
                persistentStoreCoordinator: testDatabase.databaseManagerMock.persistentStoreCoordinator,
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
            let testDatabase = TestDatabase()

            let databaseContext = DatabaseContext(
                persistentStoreCoordinator: testDatabase.databaseManagerMock.persistentStoreCoordinator,
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
            let testDatabase = TestDatabase()

            // Initially there should be no direct context
            let mainDatabaseContext = DatabaseContext(
                persistentStoreCoordinator: testDatabase.databaseManagerMock
                    .persistentStoreCoordinator
            )
            #expect(mainDatabaseContext.directContexts.isEmpty)
            
            // Add direct context and validate that there is no parent
            let directManagedObjectContext = DatabaseContext
                .directBackgroundContext(with: testDatabase.databaseManagerMock.persistentStoreCoordinator)
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
