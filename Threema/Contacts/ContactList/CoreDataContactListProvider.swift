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
    
    var currentSnapshot: AnyPublisher<ContactListSnapshot, Never> { snapshotSubject.eraseToAnyPublisher() }
    private var snapshotSubject: CurrentValueSubject<ContactListSnapshot, Never>
    private var subscriptions: Set<AnyCancellable> = .init()
    private let entityResolver: (Entity) -> BusinessEntity?
    private let entityFetcher: EntityFetcher
    private let fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>
    
    init(
        entityFetcher: EntityFetcher = BusinessInjector().entityManager.entityFetcher,
        at fetchedResultsControllerKeyPath: KeyPath<
            ContactListFetchManager,
            NSFetchedResultsController<NSFetchRequestResult>
        >,
        entityResolver: @escaping (Entity) -> BusinessEntity?
    ) {
        self.entityFetcher = entityFetcher
        self.entityResolver = entityResolver
        self.fetchedResultsController = entityFetcher[keyPath: fetchedResultsControllerKeyPath]
        self.snapshotSubject = .init(ContactListSnapshot())
        super.init()
        fetchedResultsController.delegate = self
        try? fetchedResultsController.performFetch()
        
        BusinessInjector()
            .settingsStore
            .blacklist
            .publisher
            .sink(receiveValue: { [weak self] _ in
                guard let self else {
                    return
                }
                try? fetchedResultsController.performFetch()
            })
            .store(in: &subscriptions)
        
        UserSettings.shared()
            .publisher(for: \.hideStaleContacts)
            .sink { [weak self] _ in
                guard let self else {
                    return
                }
                try? fetchedResultsController.performFetch()
            }
            .store(in: &subscriptions)
    }
    
    deinit {
        subscriptions.removeAll()
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
