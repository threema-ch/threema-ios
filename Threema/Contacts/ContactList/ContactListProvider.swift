//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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

import CocoaLumberjackSwift
import Combine
import CoreData
import Foundation
import ThreemaFramework

protocol ContactListItem: TMAManagedObject {
    static var entityName: String? { get }
}

extension ContactListItem {
    static var entityName: String? {
        Self.entity().name
    }
}

// MARK: - ContactEntity + ContactListItem

extension ContactEntity: ContactListItem { }

enum ContactListEntity {
    case contact
    case work
    case group
    case distributionList
}

// This will be moved to ThreemaFramework when implementing the other FetchedResultControllers
extension ContactListEntity {
    func makeFetchController<ListItem>(_ ctx: NSManagedObjectContext) -> NSFetchedResultsController<ListItem>
        where ListItem: ContactListItem {
        switch self {
        case .contact:
            NSFetchedResultsController(
                fetchRequest: fetchRequest(),
                managedObjectContext: ctx,
                sectionNameKeyPath: nil,
                cacheName: nil
            )
        default:
            NSFetchedResultsController()
        }
    }
    
    private func fetchRequest<ListItem>() -> NSFetchRequest<ListItem> where ListItem: ContactListItem {
        guard let entityName = ListItem.entityName else {
            return NSFetchRequest<ListItem>()
        }
        
        return NSFetchRequest<ListItem>(entityName: entityName).then {
            $0.fetchBatchSize = 100
            $0.sortDescriptors = sortDescriptors
        }
    }
 
    private var sortDescriptors: [NSSortDescriptor] {
        switch self {
        case .contact:
            let sortOrderFirstName = UserSettings.shared().sortOrderFirstName
            return [
                NSSortDescriptor(key: "sortIndex", ascending: true),
                NSSortDescriptor(
                    key: sortOrderFirstName ? "firstName" : "lastName",
                    ascending: true,
                    selector: #selector(NSString.localizedStandardCompare(_:))
                ),
                NSSortDescriptor(
                    key: sortOrderFirstName ? "lastName" : "firstName",
                    ascending: true,
                    selector: #selector(NSString.localizedStandardCompare(_:))
                ),
                NSSortDescriptor(
                    key: "publicNickname",
                    ascending: true,
                    selector: #selector(NSString.localizedStandardCompare(_:))
                ),
            ]
        default:
            return []
        }
    }
}

final class ContactListProvider: NSObject, ContactListDataSourceContactProviderProtocol {
    typealias ContactID = NSManagedObjectID
    typealias Snapshot = ContactListDataSource<NSManagedObjectID, ContactListProvider>.ContactListSnapshot
    
    private let managedObjectContext: NSManagedObjectContext
    private let fetchedResultsController: NSFetchedResultsController<ContactEntity>

    private let currentSnapshotSubject: PassthroughSubject<
        NSDiffableDataSourceSnapshot<String, NSManagedObjectID>,
        Never
    > = .init()
    var currentSnapshot: AnyPublisher<NSDiffableDataSourceSnapshot<String, NSManagedObjectID>, Never> {
        currentSnapshotSubject.eraseToAnyPublisher()
    }
    
    init(_ entity: ContactListEntity = .contact) {
        self.managedObjectContext = BusinessInjector().entityManager.entityFetcher.managedObjectContext
        self.fetchedResultsController = entity.makeFetchController(managedObjectContext)
        super.init()
        fetchedResultsController.delegate = self
        fetch()
    }
    
    func contact(for id: NSManagedObjectID) -> Contact? {
        do {
            guard let entity = try managedObjectContext.existingObject(with: id) as? ContactEntity else {
                return nil
            }
            return Contact(contactEntity: entity)
        }
        catch {
            DDLogInfo("Error fetching contact with ID \(id): \(error)")
            return nil
        }
    }
    
    func contacts() -> [NSManagedObjectID] {
        fetchedResultsController.fetchedObjects?.map(\.objectID) ?? []
    }
    
    private func fetch() {
        do {
            try fetchedResultsController.performFetch()
        }
        catch {
            DDLogError("Failed to initialize fetchedResultsController: \(error)")
        }
    }
    
    public func refetch() {
        DDLogVerbose("\(#function)")
        do {
            try fetchedResultsController.managedObjectContext.performAndWait {
                try self.fetchedResultsController.performFetch()
            }
        }
        catch {
            DDLogError("An error occurred when refetching the current snapshot.")
        }
    }
}

// MARK: - NSFetchedResultsControllerDelegate

extension ContactListProvider: NSFetchedResultsControllerDelegate {
    func controller(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference
    ) {
        currentSnapshotSubject.send(snapshot as NSDiffableDataSourceSnapshot<String, NSManagedObjectID>)
    }
}

class ContactListDataSourceDelegateTest: ContactListDataSourceDelegate {
    func performFetch() { }
}
