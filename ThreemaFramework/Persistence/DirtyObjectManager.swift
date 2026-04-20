import CocoaLumberjackSwift
import CoreData
import RemoteSecretProtocol

public final class DirtyObjectManager: NSObject {

    private let databaseManager: DatabaseManagerProtocol
    private let userDefaults: UserDefaults
    private let databaseMainContext: ThreemaManagedObjectContext

    private let dirtyObjectsQueue = DispatchQueue(label: "ch.threema.DirtyObjectManager.dirtyObjectsQueue")

    private let dirtyObjectsKey = "DBDirtyObjectsKey"
    private let didUpdateExternalDataProtectionKey = "DBDidUpdateExternalDataProtectionNewKey"

    required init(
        databaseManager: DatabaseManagerProtocol,
        userDefaults: UserDefaults
    ) {
        self.databaseManager = databaseManager
        self.userDefaults = userDefaults

        self.databaseMainContext = databaseManager.databaseContext(withChildContextForBackgroundProcess: false).main
        super.init()
    }

    convenience init(
        userDefaults: UserDefaults,
        appGroupID: String,
        remoteSecretManager: RemoteSecretManagerProtocol
    ) {
        self.init(
            databaseManager: DatabaseManager(
                appGroupID: appGroupID,
                remoteSecretManager: remoteSecretManager
            ),
            userDefaults: userDefaults
        )
    }

    /// Mark as dirty for refreshing the object in the app process.
    /// Used for changes in Notification/Share Extension.
    /// - Parameters:
    ///   - objectID: Managed Object ID for refreshing
    ///   - notify: Closure is called after object is marked as dirty
    public func markAsDirty(objectID: NSManagedObjectID, notify: (() -> Void)? = nil) {
        dirtyObjectsQueue.sync {
            var dirtyObjects: [String] = userDefaults.array(forKey: dirtyObjectsKey) as? [String] ?? [String]()

            let objectURI = objectID.uriRepresentation().absoluteString

            if !dirtyObjects.contains(objectURI) {
                dirtyObjects.append(objectURI)

                userDefaults.set(dirtyObjects, forKey: dirtyObjectsKey)

                DDLogInfo("[dirty-objects] Object ID \(objectID) added")
            }
            else {
                DDLogInfo("[dirty-objects] Object ID \(objectID) already added")
            }
        }

        notify?()
    }

    /// Refresh all objects on main context.
    public func refreshAllObjects() {
        DDLogInfo("[dirty-objects] Refresh all objects on main context")

        databaseMainContext.performAndWait {
            let stalenessInterval = databaseMainContext.stalenessInterval
            databaseMainContext.stalenessInterval = 0.0
            databaseMainContext.refreshAllObjects()
            databaseMainContext.stalenessInterval = stalenessInterval
        }
    }

    /// Refresh dirty and all related objects on main context.
    /// Is used within the app to apply changes from Notification/Share Extension.
    /// - Parameter clearMarkedObjects: Is true all objects marked as dirty are deleted from the cache
    @objc public func refreshDirtyObjects(reset clearMarkedObjects: Bool) {
        DDLogInfo("[dirty-objects] Refresh dirty objects")

        dirtyObjectsQueue.sync {
            do {
                let localPersistentStoreCoordinator = try databaseManager.persistentStoreCoordinator

                let dirtyObjects: Set<String> = Set(
                    userDefaults
                        .array(forKey: dirtyObjectsKey) as? [String] ?? [String]()
                )

                guard !dirtyObjects.isEmpty else {
                    return
                }

                let stalenessInterval = databaseMainContext.stalenessInterval
                databaseMainContext.stalenessInterval = 0.0

                var refreshedObjectIDs = Set<NSManagedObjectID>()

                for dirtyObjectURI in dirtyObjects {
                    guard let dirtyObjectURL = URL(string: dirtyObjectURI),
                          let objectID = localPersistentStoreCoordinator
                          .managedObjectID(forURIRepresentation: dirtyObjectURL),
                          let object = try? databaseMainContext.existingObject(with: objectID) else {
                        continue
                    }

                    refreshDirtyObject(object, refreshedObjectIDs: &refreshedObjectIDs)
                }

                databaseMainContext.stalenessInterval = stalenessInterval

                if !refreshedObjectIDs.isEmpty {
                    // Note that all objects will be merged even it is updated, inserted or deleted
                    DatabaseContext
                        .mergeChangesIntoDirectContexts([NSUpdatedObjectsKey: Array(refreshedObjectIDs)])

                    DatabaseContext.changed(objectIDs: refreshedObjectIDs)
                }

                if clearMarkedObjects {
                    DDLogInfo("[dirty-objects] Remove array of dirty objects")
                    userDefaults.removeObject(forKey: dirtyObjectsKey)
                }
            }
            catch {
                DDLogError("Refresh of dirty objects failed: \(error)")
            }
        }
    }

    private func refreshDirtyObject(_ object: NSManagedObject, refreshedObjectIDs: inout Set<NSManagedObjectID>) {
        databaseMainContext.performAndWait {
            if let baseMessageEntity = object as? BaseMessageEntity {
                if let contactEntity = baseMessageEntity.conversation.contact {
                    refresh(contactEntity, &refreshedObjectIDs)
                }

                if let lastMessage = baseMessageEntity.conversation.lastMessage {
                    refresh(lastMessage, &refreshedObjectIDs)
                }

                if let fileMessageEntity = (baseMessageEntity as? FileMessageEntity) {
                    if let thumbnail = fileMessageEntity.thumbnail {
                        refresh(thumbnail, &refreshedObjectIDs)
                    }
                    if let data = fileMessageEntity.data {
                        refresh(data, &refreshedObjectIDs)
                    }
                }

                refresh(baseMessageEntity.conversation, &refreshedObjectIDs)

                if let reactions = baseMessageEntity.reactions {
                    for reaction in reactions {
                        refresh(reaction, &refreshedObjectIDs)
                    }
                }

                if let editHistoryEntries = baseMessageEntity.historyEntries {
                    for historyEntry in editHistoryEntries {
                        refresh(historyEntry, &refreshedObjectIDs)
                    }
                }

                if let ballotMessageEntity = baseMessageEntity as? BallotMessageEntity,
                   let ballotEntity = ballotMessageEntity.ballot {
                    refreshDirtyObject(ballotEntity: ballotEntity, refreshedObjectIDs: &refreshedObjectIDs)
                }

                refresh(baseMessageEntity, &refreshedObjectIDs)
            }
            else if let ballotEntity = object as? BallotEntity {
                refreshDirtyObject(ballotEntity: ballotEntity, refreshedObjectIDs: &refreshedObjectIDs)
            }
            else {
                refresh(object, &refreshedObjectIDs)
            }
        }
    }

    private func refreshDirtyObject(ballotEntity: BallotEntity, refreshedObjectIDs: inout Set<NSManagedObjectID>) {
        if let choices = ballotEntity.choices {
            for choice in choices {
                refresh(choice, &refreshedObjectIDs)
            }
        }

        refresh(ballotEntity, &refreshedObjectIDs)
    }

    private func refresh(_ object: NSManagedObject, _ refreshedObjectIDs: inout Set<NSManagedObjectID>) {
        databaseMainContext.refresh(object, mergeChanges: true)
        refreshedObjectIDs.insert(object.objectID)
    }
}
