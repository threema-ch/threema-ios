//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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
import UIKit

protocol ContactListDataSourceDelegate: AnyObject {
    func performFetch()
}

extension ContactListDataSource {
    typealias Section = Hashable
    typealias Row = Hashable
}

class ContactListDataSource<
    CellType: ContactListCellProviderProtocol.ContactListCellType,
    BusinessEntity: NSObject,
    Provider: ContactListDataSourceProviderProtocol<NSManagedObjectID, BusinessEntity>,
    CellProvider: ContactListCellProviderProtocol<CellType, BusinessEntity>
>: UITableViewDiffableDataSource<String, Provider.ID> {
    
    private var snapshotSubscription: Cancellable?
    private var sectionTitles: [String] { ThreemaLocalizedIndexedCollation.sectionIndexTitles }
    private var contentProvider: (CellProvider, Provider) -> ContactListDataSource
        .CellProvider = { cellProvider, provider in
            { tableView, indexPath, itemIdentifier in
                cellProvider.dequeueCell(
                    for: indexPath,
                    and: provider.entity(for: itemIdentifier),
                    in: tableView
                )
            }
        }
    
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
    
    init(
        provider: Provider,
        cellProvider: CellProvider,
        in tableView: UITableView,
        sectionIndexEnabled: Bool = true,
        contentUnavailableConfiguration: ThreemaTableContentUnavailableView.Configuration? = nil
    ) {
        self.sectionIndexEnabled = sectionIndexEnabled
        cellProvider.registerCells(in: tableView)
        super.init(
            tableView: tableView,
            cellProvider: contentProvider(cellProvider, provider)
        )
        
        if let contentUnavailableConfiguration {
            self.contentUnavailable = tableView
                .setupContentUnavailableView(configuration: contentUnavailableConfiguration)
        }
        
        subscribe(to: provider)
    }
    
    deinit {
        snapshotSubscription?.cancel()
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sectionIndexEnabled ? tableIndexTitles[section] : nil
    }

    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        sectionIndexEnabled ? sectionTitles : nil
    }
    
    override func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        tableIndexTitles.firstIndex(of: title) ?? 0
    }
    
    private func subscribe(to provider: Provider) {
        snapshotSubscription = provider.currentSnapshot.sink { [weak self] snapshot in
            guard let self else {
                return
            }
            apply(snapshot)
            didUpdate(snapshot: snapshot)
        }
    }
    
    private func didUpdate(snapshot: Provider.ContactListSnapshot) {
        (snapshot.itemIdentifiers.count <= 0 ? contentUnavailable?.show : contentUnavailable?.hide)?()
    }
}
