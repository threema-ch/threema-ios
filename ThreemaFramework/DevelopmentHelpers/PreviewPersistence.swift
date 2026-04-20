#if DEBUG

    import CoreData
    import ThreemaEssentials

    /// Create an in-memory Core Data stack, used for working with sample data in Swift UI Previews.
    struct PreviewPersistence {

        let persistenceContainer: NSPersistentContainer = {
            let modelName = "ThreemaData"
            let modelURL = BundleUtil.url(forResource: modelName, withExtension: "momd")!
            let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)!
            let container = NSPersistentContainer(name: modelName, managedObjectModel: managedObjectModel)
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
            container.loadPersistentStores { _, error in
                if let error {
                    assertionFailure(error.localizedDescription)
                }
            }
            container.viewContext.automaticallyMergesChangesFromParent = true
            container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            return container
        }()

        var context: NSManagedObjectContext { persistenceContainer.viewContext }
    }

#endif
