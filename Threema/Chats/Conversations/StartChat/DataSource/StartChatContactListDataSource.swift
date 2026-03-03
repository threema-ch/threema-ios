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

import Combine
import Foundation
import ThreemaMacros
import UIKit

typealias StartChatContactListSnapshot = NSDiffableDataSourceSnapshot<
    StartChatContactListDataSource.Section,
    StartChatContactListDataSource.Section.Row
>
final class StartChatContactListDataSource: UITableViewDiffableDataSource<
    StartChatContactListDataSource.Section,
    StartChatContactListDataSource.Section.Row
> {
    
    // MARK: - Types
    
    enum Section: Hashable {
        case actions
        case contacts(String)
        
        enum Row: Hashable {
            case addContact
            case addGroup
            case addDistributionList
            case contact(NSManagedObjectID)
        }
    }

    // MARK: - Properties

    private var snapshotSubscription: Cancellable?
    private var sectionTitles: [String] { ThreemaLocalizedIndexedCollation.sectionIndexTitles }
    private var tableIndexTitles: [String?] {
        snapshot().sectionIdentifiers.map { section in
            switch section {
            case let .contacts(label):
                if let i = Int(label), i >= 0, i < sectionTitles.count {
                    sectionTitles[i]
                }
                else {
                    label
                }
            case .actions:
                nil
            }
        }
    }

    // MARK: - Lifecycle

    init(
        provider: ContactListProvider,
        cellProvider: ContactListCellProvider,
        entityManager: EntityManager,
        in tableView: UITableView,
    ) {
        super.init(tableView: tableView) { tableView, indexPath, row in
            switch row {
            case let .contact(objectID):
                let contactEntity = entityManager.performAndWait {
                    entityManager.entityFetcher.existingObject(with: objectID) as? ContactEntity
                }
                guard let contactEntity else {
                    // TODO: (IOS-4536) Error
                    fatalError()
                }

                return cellProvider.dequeueCell(
                    for: indexPath,
                    and: Contact(contactEntity: contactEntity),
                    in: tableView
                )

            case .addContact:
                let cell = tableView
                    .dequeueReusableCell(withIdentifier: StartChatAddItemCell.reuseIdentifier) as! StartChatAddItemCell
                cell.configure(with: .contact)
                
                return cell
                
            case .addGroup:
                let cell = tableView
                    .dequeueReusableCell(withIdentifier: StartChatAddItemCell.reuseIdentifier) as! StartChatAddItemCell
                cell.configure(with: .group)
                
                return cell

            case .addDistributionList:
                let cell = tableView
                    .dequeueReusableCell(withIdentifier: StartChatAddItemCell.reuseIdentifier) as! StartChatAddItemCell
                cell.configure(with: .distributionList)
                
                return cell
            }
        }

        registerCells(tableView, cellProvider: cellProvider)
        subscribe(to: provider)
    }

    deinit {
        snapshotSubscription?.cancel()
    }

    // MARK: - Overrides

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        tableIndexTitles[section]
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let kinds: [StartChatAddItemCell.AddItemKind] = [.contact, .group]
        guard section == 0,
              kinds.contains(where: { !$0.enabled }) else {
            return nil
        }
        return #localize("disabled_by_device_policy_feature")
    }

    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        sectionTitles
    }

    override func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        tableIndexTitles.firstIndex(of: title) ?? 0
    }

    private func subscribe(to provider: ContactListProvider) {
        snapshotSubscription = provider.currentSnapshot.sink { [weak self] contactSnapshot in
            guard let self else {
                return
            }
            
            var snapshot = NSDiffableDataSourceSnapshot<Section, Section.Row>()
            snapshot.appendSections([.actions])
            snapshot.appendItems(
                [
                    .addContact,
                    .addGroup,
                    StartChatAddItemCell.AddItemKind.distributionList.enabled ? .addDistributionList : nil,
                ].compactMap { $0 },
                toSection: .actions
            )

            let sectionIdentifiers = contactSnapshot.sectionIdentifiers
            for sectionID in sectionIdentifiers {
                let section = Section.contacts(sectionID)
                snapshot.appendSections([section])

                let items = contactSnapshot.itemIdentifiers(inSection: sectionID)
                let contactRows = items.map(Section.Row.contact)
                snapshot.appendItems(contactRows, toSection: section)
            }
            
            apply(snapshot)
        }
    }

    // MARK: - Helpers
    
    private func registerCells(_ tableView: UITableView, cellProvider: ContactListCellProvider) {
        cellProvider.registerCells(in: tableView)
        tableView.registerCell(StartChatAddItemCell.self)
    }
}
