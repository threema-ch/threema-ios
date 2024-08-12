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
import Foundation

class CoreDataContactListProvider<Entity: NSObject, BusinessEntity: NSObject>: NSObject,
    ContactListDataSourceProviderProtocol,
    NSFetchedResultsControllerDelegate {
    
    typealias ID = NSManagedObjectID
    typealias _Entity = Entity
    
    var currentSnapshot: AnyPublisher<ContactListSnapshot, Never> { snapshotSubject.eraseToAnyPublisher() }
    private var snapshotSubject: CurrentValueSubject<ContactListSnapshot, Never>

    private let entityResolver: (Entity) -> BusinessEntity?
    private let entityFetcher: EntityFetcher
    private let fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>
    
    init(
        entityFetcher: EntityFetcher = BusinessInjector().entityManager.entityFetcher,
        fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>,
        entityResolver: @escaping (Entity) -> BusinessEntity?
    ) {
        self.entityFetcher = entityFetcher
        self.entityResolver = entityResolver
        self.fetchedResultsController = fetchedResultsController
        self.snapshotSubject = .init(ContactListSnapshot())
        super.init()
        fetchedResultsController.delegate = self
        try? fetchedResultsController.performFetch()
    }
    
    func entity(for id: NSManagedObjectID) -> BusinessEntity? {
        guard let entity = entityFetcher.getManagedObject(by: id) as? Entity else {
            return nil
        }
        
        return entityResolver(entity)
    }
    
    private func convert(_ snapshot: NSDiffableDataSourceSnapshotReference) -> ContactListSnapshot {
        snapshot as ContactListSnapshot
    }
    
    // MARK: - NSFetchedResultsControllerDelegate
    
    func controller(
        _ controller: NSFetchedResultsController<any NSFetchRequestResult>,
        didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference
    ) {
        snapshotSubject.send(convert(snapshot))
    }
}
