#if DEBUG

    import CoreData
    import ThreemaEssentials

    /// Create an in-memory Core Data stack, used for working with sample data in Swift UI Previews.
    public struct PreviewPersistence {
        public let persistenceContainer: NSPersistentContainer
        public let entityManager: EntityManager
        public let context: NSManagedObjectContext

        public init() {
            let modelName = "ThreemaData"
            let modelURL = BundleUtil.url(forResource: modelName, withExtension: "momd")!
            let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)!
            persistenceContainer = NSPersistentContainer(name: modelName, managedObjectModel: managedObjectModel)
            persistenceContainer.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
            persistenceContainer.loadPersistentStores { _, error in
                if let error {
                    assertionFailure(error.localizedDescription)
                }
            }
            persistenceContainer.viewContext.automaticallyMergesChangesFromParent = true
            persistenceContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

            context = persistenceContainer.viewContext
            entityManager = EntityManager(
                databaseContext: DatabaseContext(
                    persistentStoreCoordinator: persistenceContainer.persistentStoreCoordinator
                ),
                isRemoteSecretEnabled: false
            )
        }
    }

#endif
