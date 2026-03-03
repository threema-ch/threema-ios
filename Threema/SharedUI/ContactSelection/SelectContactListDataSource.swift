//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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
import ThreemaFramework
import ThreemaMacros
import UIKit

final class SelectContactListDataSource: UITableViewDiffableDataSource<
    String,
    NSManagedObjectID
> {
    
    public var contentUnavailableConfiguration: ThreemaTableContentUnavailableView.Configuration {
        didSet {
            contentUnavailable = tableView?
                .setupContentUnavailableView(configuration: contentUnavailableConfiguration)
            snapshot().itemIdentifiers.isEmpty ? contentUnavailable?.show() : contentUnavailable?.hide()
        }
    }
    
    private weak var coordinator: ContactsCoordinator?
    private weak var tableView: UITableView?
    private var snapshotSubscription: Cancellable?
    private var sectionTitles: [String] { ThreemaLocalizedIndexedCollation.sectionIndexTitles }
    
    private var tableIndexTitles: [String] {
        (snapshot().sectionIdentifiers + [.broadcasts]).compactMap { str in
            guard let i = Int(str), i >= 0, i < sectionTitles.count else {
                return str
            }
            return sectionTitles[i]
        }
    }
    
    private let sectionIndexEnabled: Bool
    private var contentUnavailable: (show: () -> Void, hide: () -> Void)?
    
    // MARK: - Lifecycle
    
    init(
        coordinator: ContactsCoordinator?,
        provider: ContactListProvider,
        cellProvider: ContactListSelectionCellProvider,
        entityManager: EntityManager,
        in tableView: UITableView,
        sectionIndexEnabled: Bool = true,
        contentUnavailableConfiguration: ThreemaTableContentUnavailableView.Configuration
    ) {
        self.coordinator = coordinator
        self.tableView = tableView
        self.sectionIndexEnabled = sectionIndexEnabled
        self.contentUnavailableConfiguration = contentUnavailableConfiguration
        
        super.init(tableView: tableView) { tableView, indexPath, objectID in
            let contactEntity = entityManager.performAndWait {
                entityManager.entityFetcher.existingObject(with: objectID) as? ContactEntity
            }
            guard let contactEntity else {
                // TODO: (IOS-4536) Error
                fatalError()
            }
            
            return cellProvider.dequeueCell(for: indexPath, and: Contact(contactEntity: contactEntity), in: tableView)
        }
        
        cellProvider.registerCells(in: tableView)
        
        subscribe(to: provider)
    }
    
    deinit {
        snapshotSubscription?.cancel()
    }
    
    // MARK: - Overrides
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sectionIndexEnabled ? tableIndexTitles[section] : nil
    }

    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        sectionIndexEnabled ? sectionTitles : nil
    }
    
    override func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        tableIndexTitles.firstIndex(of: title) ?? 0
    }
    
    private func subscribe(to provider: ContactListProvider) {
        snapshotSubscription = provider.currentSnapshot.sink { [weak self] snapshot in
            guard let self else {
                return
            }
            apply(snapshot)
            didUpdate(snapshot: snapshot)
        }
    }

    // MARK: - Private functions
    
    private func didUpdate(snapshot: ContactListProvider.ContactListSnapshot) {
        guard snapshot.numberOfItems > 0 else {
            contentUnavailable?.show()
            return
        }
        
        contentUnavailable?.hide()
    }
}
