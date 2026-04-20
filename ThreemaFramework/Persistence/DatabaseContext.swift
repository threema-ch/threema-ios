import CoreData

@objc public protocol DatabaseContextProtocol {
    var main: ThreemaManagedObjectContext { get }
    var current: ThreemaManagedObjectContext { get }
}

/// Handle Core Data Contexts
public final class DatabaseContext: NSObject, DatabaseContextProtocol {

    /// Direct main context that runs on the main thread
    ///
    /// This is the same context as long as the app runs
    public var main: ThreemaManagedObjectContext {
        DatabaseContext.mainContext
    }
    
    /// Current context
    ///
    /// This is a main or background child context from `main` or `main` itself if no child context exists
    public var current: ThreemaManagedObjectContext {
        privateContext ?? main
    }
    
    /// All direct contexts created except `main`
    var directContexts: Set<NSManagedObjectContext> {
        DatabaseContext.directContextsQueue.sync {
            DatabaseContext.directContextsInternal
        }
    }
    
    // MARK: Private properties
    
    // This will only be `nil` if no initializer is called. However because this is private it is always non-nil when it
    // is accessed through `main`
    private static var mainContext: ThreemaManagedObjectContext!
    // Not a constant, because it needs to be overridden by the second initializer which first calls the first
    // initializer
    private var privateContext: ThreemaManagedObjectContext?
    private static var directContextsInternal = Set<NSManagedObjectContext>()
    
    // Needed to only initialize the `main` context once
    private static let mainContextQueue = DispatchQueue(label: "ch.threema.DatabaseContext.mainContextQueue")
    // Used to synchronize access to `directContextsInternal`
    // Apparently Swift value types are not thread safe:
    // https://forums.swift.org/t/understanding-swifts-value-type-thread-safety/41406/2
    private static let directContextsQueue = DispatchQueue(label: "ch.threema.DatabaseContext.directContextsQueue")

    // Notification if an error occured while processing (e.g. saving) managed objects
    public static let errorWhileProcessingManagedObject = Notification.Name("ThreemaErrorWhileProcessingManagedObject")
    public static let errorKey = "errorKey"

    // Notification after refresh dirty managed objects in database contexts
    @objc public static let changedManagedObjects = Notification.Name("ThreemaDBRefreshedDirtyObjects")
    public static let refreshedObjectIDsKey = "refreshedObjectIDsKey"

    // Notification after deletion of old messages
    public static let batchDeletedOldMessages = Notification.Name("ThreemaBatchDeletedOldMessages")

    // Notification after deletion of all messages in a conversation
    public static let batchDeletedAllConversationMessages = Notification
        .Name("ThreemaBatchDeletedAllConversationMessages")
    public static let conversationObjectIDKey = "conversationObjectIDKey"

    // MARK: - Lifecycle

    /// Create new instance
    ///
    /// If `main` is not already set it is created using the persistent store coordinator
    ///
    /// - Parameter persistentStoreCoordinator: Persistent store coordinator for `main` context, if `main` doesn't
    ///                                         already exist
    init(persistentStoreCoordinator: NSPersistentStoreCoordinator) {
        super.init()
        
        DatabaseContext.mainContextQueue.sync {
            if DatabaseContext.mainContext == nil {
                let newManagedObjectContext = ThreemaManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
                newManagedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
                newManagedObjectContext.mergePolicy = NSMergePolicy.overwrite
                newManagedObjectContext.automaticallyMergesChangesFromParent = true
                
                DatabaseContext.mainContext = newManagedObjectContext
            }
        }
    }
    
    /// Create new instance with a child context
    ///
    /// Creates a new child context in the background or on the main queue. If `main` is not already set it is created
    /// using the persistent store coordinator
    ///
    /// - Parameters:
    ///   - persistentStoreCoordinator: Persistent store coordinator for `main` context, if `main` doesn't already exist
    ///   - inBackground: Should child context run in the background?
    convenience init(
        persistentStoreCoordinator: NSPersistentStoreCoordinator,
        withChildContextInBackground inBackground: Bool
    ) {
        self.init(persistentStoreCoordinator: persistentStoreCoordinator)
        
        let childContext =
            if inBackground {
                ThreemaManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            }
            else {
                ThreemaManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
            }
        
        childContext.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump
        childContext.parent = main
        childContext.automaticallyMergesChangesFromParent = true
        
        self.privateContext = childContext
        
        // Listen to dirty object notifications to refresh private context
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(changedManagedObjects),
            name: DatabaseContext.changedManagedObjects,
            object: nil
        )
    }
    
    @available(*, unavailable)
    override init() {
        fatalError("\(#function) not implemented")
    }
    
    // MARK: - Direct background contexts
    
    /// Create a new direct background context
    ///
    /// - Note: Don't forget to remove the context again (using `removeDirectBackgroundContext(_:)`) if you don't use it
    ///         anymore (e.g. in `deinit`)
    ///
    /// - Parameter persistentStoreCoordinator: Persistent store coordinator to use
    /// - Returns: New direct background context that is also tracked in `directContexts`
    public static func directBackgroundContext(
        with persistentStoreCoordinator: NSPersistentStoreCoordinator
    ) -> ThreemaManagedObjectContext {
        
        let context = ThreemaManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = persistentStoreCoordinator
        
        _ = directContextsQueue.sync {
            directContextsInternal.insert(context)
        }
        
        return context
    }
    
    /// Remove direct background context from tracking list
    ///
    /// - Note: You should not use the context anymore after this
    ///
    /// - Parameter context: Direct background context to remove
    public static func removeDirectBackgroundContext(_ context: NSManagedObjectContext) {
        _ = directContextsQueue.sync {
            directContextsInternal.remove(context)
        }
    }

    private static func mergeChanges(_ changes: [AnyHashable: Any], into contexts: Set<NSManagedObjectContext>) {
        guard !changes.isEmpty, !contexts.isEmpty else {
            return
        }

        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: Array(contexts))
    }

    /// Merge changed Managed Objects into main context.
    /// - Parameter changes: Changed Managed Objects
    static func mergeChangesIntoMainContext(_ changes: [AnyHashable: Any]) {
        mergeChanges(changes, into: [mainContext])
    }

    /// Merge changed Managed Objects into all direct background contexts.
    /// - Parameter changes: Changed Managed Objects
    static func mergeChangesIntoDirectContexts(_ changes: [AnyHashable: Any]) {
        directContextsQueue.sync {
            mergeChanges(changes, into: directContextsInternal)
        }
    }

    // MARK: - Post notification about changed managed objects

    /// Post notification with changed managed objects, this will refresh all private background contexts.
    /// - Parameter objectIDs: Managed Objects that has changed
    static func changed(objectIDs: Set<NSManagedObjectID>) {
        guard !objectIDs.isEmpty else {
            return
        }

        let info = [refreshedObjectIDsKey: objectIDs]
        NotificationCenter.default.post(name: DatabaseContext.changedManagedObjects, object: self, userInfo: info)
    }

    // MARK: - Observer
    
    @objc private func changedManagedObjects(_ notification: Notification) {
        // This notification should only be observed when a private context exists, but we check anyway
        guard let privateContext else {
            return
        }
        
        guard let objectIDs = notification.userInfo?[DatabaseContext.refreshedObjectIDsKey] as? Set<NSManagedObjectID>
        else {
            return
        }
        
        for objectID in objectIDs {
            privateContext.perform {
                guard let object = try? privateContext.existingObject(with: objectID) else {
                    return
                }
                
                privateContext.refresh(object, mergeChanges: true)
            }
        }
    }
}
