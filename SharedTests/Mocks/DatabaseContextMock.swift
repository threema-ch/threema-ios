import CoreData
import XCTest
@testable import ThreemaFramework

final class DatabaseContextMock {

    private var mainContext: ThreemaManagedObjectContext!
    private var privateContext: ThreemaManagedObjectContext?

    init(
        inMemory: Bool = false,
        withChildContextForBackgroundProcess: Bool = false,
        isRemoteSecretEnabled: Bool = false
    ) {
        if inMemory {
            self.mainContext = Self.inMemoryContext()
        }
        else {
            let devNullDatabase = devNullContext(
                withChildContextForBackgroundProcess: withChildContextForBackgroundProcess,
                isRemoteSecretEnabled: isRemoteSecretEnabled
            )
            self.mainContext = devNullDatabase.mainContext
            self.privateContext = devNullDatabase.childContext
        }
    }

    /// Get new private database context for background process.
    /// - Parameter mainContext: Parent context for the new private context
    init(mainContext: ThreemaManagedObjectContext) {
        self.mainContext = mainContext
        self.privateContext = devNullChildContext(parent: self.mainContext)
    }

    // The CD in memory persistent store doesn't support derived attributes:
    // "Core Data provided atomic stores do not support derived properties (NSInvalidArgumentException)"
    // Thus the function to create one was removed.

    static var modelURL: URL? = BundleUtil.url(
        forResource: DatabaseManager.databaseModelName,
        withExtension: "momd"
    )

    /// Context in memory, doesn't work with NSBatch... commands (use devNullContext)
    ///
    /// - Returns: DB context for testing
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
    ///  - Returns: DB context for testing
    private func devNullContext(
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
        mainContext.mergePolicy = NSMergePolicy.overwrite
        mainContext.automaticallyMergesChangesFromParent = true

        let childContext: ThreemaManagedObjectContext? =
            if withChildContextForBackgroundProcess {
                devNullChildContext(parent: mainContext)
            }
            else {
                nil
            }

        return (container.persistentStoreCoordinator, mainContext, childContext)
    }

    private func devNullChildContext(parent mainContext: ThreemaManagedObjectContext)
        -> ThreemaManagedObjectContext? {
        let childContext = ThreemaManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        childContext.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump
        childContext.parent = mainContext
        childContext.automaticallyMergesChangesFromParent = true
        return childContext
    }
}

// MARK: - DatabaseContextProtocol

extension DatabaseContextMock: DatabaseContextProtocol {
    public var main: ThreemaManagedObjectContext {
        mainContext
    }

    public var current: ThreemaManagedObjectContext {
        privateContext ?? mainContext
    }
}
