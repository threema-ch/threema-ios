//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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
import Foundation

class EntityObserver: NSObject {

    static let shared = EntityObserver()

    typealias EntityChangedAction = (NSManagedObject?, EntityChangedReason) -> Void

    enum EntityChangedReason {
        case updated
        case deleted
    }
    
    private let queue = DispatchQueue(label: "ch.threema.EntityObserver.queue")

    private struct Subscriber: Hashable {
        static func == (lhs: EntityObserver.Subscriber, rhs: EntityObserver.Subscriber) -> Bool {
            lhs.uuid == rhs.uuid
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(uuid)
        }

        let uuid: UUID
        var managedObjectFetchPermanentID: NSFetchedResultsController<NSManagedObject>?
        let managedObjectID: NSManagedObjectID? // Is nullable because maybe Core Data set it to null
        let entityChangedReason: [EntityChangedReason]
        let entityChangedAction: EntityChangedAction
    }

    private var subscribersForDelete = Set<Subscriber>()
    private var subscribersForUpdate = Set<Subscriber>()

    override private init() {
        super.init()
        initializeObserver()
    }

    /// Subscribe managed object to get changes.
    /// - Parameters:
    ///     - managedObjectID: Subscription for managed object
    ///     - for: Reason of DB changes
    ///     - do: Action when managed object did change
    /// - Returns: Token to unsubscribe
    func subscribe(
        managedObject: NSManagedObject,
        for entityChangedReason: [EntityChangedReason] = [.deleted, .updated],
        do entityChangedAction: @escaping EntityChangedAction
    ) -> SubscriptionToken {
        assert(isEntityTypeAllowed(managedObject))

        let subscriber = Subscriber(
            uuid: UUID(),
            managedObjectFetchPermanentID: managedObject.objectID
                .isTemporaryID ? fetchPermanentID(of: managedObject) : nil,
            managedObjectID: managedObject.objectID,
            entityChangedReason: entityChangedReason,
            entityChangedAction: entityChangedAction
        )

        queue.sync {
            try? subscriber.managedObjectFetchPermanentID?.performFetch()

            if entityChangedReason.contains(.deleted) {
                subscribersForDelete.insert(subscriber)
            }
            if entityChangedReason.contains(.updated) {
                subscribersForUpdate.insert(subscriber)
            }
        }
        return SubscriptionToken {
            self.queue.sync {
                self.subscribersForDelete.remove(subscriber)
                self.subscribersForUpdate.remove(subscriber)
            }
        }
    }

    /// Initialize observer to get Core Data changes.
    private func initializeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(managedObjectContextObjectsDidChange),
            name: .NSManagedObjectContextObjectsDidChange,
            object: nil
        )
    }

    /// Called when managed object has changed.
    /// - Parameter notification: Notification with changed managed objects
    @objc private func managedObjectContextObjectsDidChange(notification: NSNotification) {
        if let allDeletedObjects = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> {
            let allowedDeletedObjects = allDeletedObjects.filter { isEntityTypeAllowed($0) }
            if !allowedDeletedObjects.isEmpty {
                let deletedObjectIDs = Set<NSManagedObjectID>(allowedDeletedObjects.map(\.objectID))
                informSubscribers(
                    updatedObjectIDs: deletedObjectIDs,
                    updatedObjects: allowedDeletedObjects,
                    subscribers: subscribersForDelete,
                    reason: .deleted
                )
            }
        }

        if let allUpdatedObjects = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> {
            let allowedUpdatedObjects = allUpdatedObjects.filter { isEntityTypeAllowed($0) }

            if !allowedUpdatedObjects.isEmpty {
                let updatedObjectIDs = Set<NSManagedObjectID>(allowedUpdatedObjects.map(\.objectID))
                informSubscribers(
                    updatedObjectIDs: updatedObjectIDs,
                    updatedObjects: allowedUpdatedObjects,
                    subscribers: subscribersForUpdate,
                    reason: .updated
                )
            }
        }
    }

    private func informSubscribers(
        updatedObjectIDs: Set<NSManagedObjectID?>,
        updatedObjects: Set<NSManagedObject>?,
        subscribers: Set<Subscriber>,
        reason: EntityChangedReason
    ) {
        let subscribersForObjectIDs = Set<NSManagedObjectID?>(
            subscribers
                .map { subscriber in
                    subscriber.managedObjectID
                }
        )

        let intersection = Set<NSManagedObjectID?>(updatedObjectIDs.intersection(subscribersForObjectIDs))

        for subscriber in subscribers.filter({ intersection.contains($0.managedObjectID) }) {
            subscriber.entityChangedAction(
                updatedObjects?
                    .first(where: { $0.objectID == subscriber.managedObjectID }),
                reason
            )
        }
    }

    private func isEntityTypeAllowed(_ managedObject: NSManagedObject) -> Bool {
        managedObject is ContactEntity || managedObject is Conversation || managedObject is GroupEntity
    }

    // MARK: Subscription token

    /// Token handed out when registering an subscription closure
    class SubscriptionToken {
        private var closure: (() -> Void)?

        init(closure: @escaping () -> Void) {
            self.closure = closure
        }

        deinit {
            cancel()
        }

        /// Remove registered closure. (Automatically called when token is deallocated.)
        func cancel() {
            closure?()
            closure = nil
        }
    }

    private func fetchPermanentID<T: NSManagedObject>(of managedObject: T) -> NSFetchedResultsController<T> {
        let fetchRequest = NSFetchRequest<T>()
        fetchRequest.entity = managedObject.entity
        fetchRequest.fetchBatchSize = 1
        fetchRequest.predicate = NSPredicate(format: "self == %@", argumentArray: [managedObject])
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "objectID", ascending: true)]
        let fetchController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: managedObject.managedObjectContext!,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        fetchController.delegate = self
        return fetchController
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension EntityObserver: NSFetchedResultsControllerDelegate {

    /// Get changes of Core Data managed objects. Has temporary object ID changed to a permanent object ID, than replace the subscription.
    func controller(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChangeContentWith diff: CollectionDifference<NSManagedObjectID>
    ) {
        struct ObjectIDPosition {
            let objectID: NSManagedObjectID
            let index: Int
        }

        var temporaryIDs = [ObjectIDPosition]()
        var tempraryIDIndex = 0
        var permanentIDs = [ObjectIDPosition]()
        var permanentIDIndex = 0

        for removal in diff.removals {
            switch removal {
            case .insert(offset: _, element: _, associatedWith: .some(_)):
                break
            case .insert(offset: _, element: _, associatedWith: .none):
                break
            case .remove(offset: _, element: let element, associatedWith: _):
                if element.isTemporaryID {
                    temporaryIDs.append(ObjectIDPosition(objectID: element, index: tempraryIDIndex))
                }
            }
            tempraryIDIndex += 1
        }

        if !temporaryIDs.isEmpty {
            for insertion in diff.insertions {
                switch insertion {
                case .insert(offset: _, element: let element, associatedWith: .some(_)):
                    if temporaryIDs.first(where: { $0.index == permanentIDIndex }) != nil {
                        permanentIDs.append(ObjectIDPosition(objectID: element, index: permanentIDIndex))
                    }
                case .insert(offset: _, element: _, associatedWith: .none):
                    break
                case .remove(offset: _, element: _, associatedWith: _):
                    break
                }
                permanentIDIndex += 1
            }

            if temporaryIDs.count == permanentIDs.count {
                queue.async {
                    for index in 0..<temporaryIDs.count {
                        if let subscriber = self.subscribersForUpdate.first(where: { subscriber in
                            subscriber.managedObjectID == temporaryIDs[index].objectID
                        }) {
                            // Replace subscription with temporary objectID, with subscription with permanent objectID
                            self.subscribersForUpdate.insert(
                                Subscriber(
                                    uuid: UUID(),
                                    managedObjectFetchPermanentID: nil,
                                    managedObjectID: permanentIDs[index].objectID,
                                    entityChangedReason: subscriber.entityChangedReason,
                                    entityChangedAction: subscriber.entityChangedAction
                                )
                            )
                            self.subscribersForUpdate.remove(subscriber)
                        }
                    }
                }
            }
        }
    }
}
