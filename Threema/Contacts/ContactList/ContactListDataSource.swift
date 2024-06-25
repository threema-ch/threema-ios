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
import ThreemaFramework
import UIKit

protocol ContactListDataSourceDelegate: AnyObject {
    func performFetch()
}

extension ContactListDataSource {
    typealias ContactListSnapshot = NSDiffableDataSourceSnapshot<Section, Row>
    
    enum Section: Hashable {
        case main
    }
    
    enum Row: Hashable {
        case contact(contactID: ContactID)
    }
}

class ContactListDataSource<
    ContactID: ContactObjectID,
    ContactProvider: ContactListDataSourceContactProviderProtocol<ContactID>
>: UITableViewDiffableDataSource<String, NSManagedObjectID> {
    
    private weak var contactProvider: ContactProvider?
    private weak var delegate: ContactListDataSourceDelegate?
    private var subscriptions = Set<AnyCancellable>()
    private let snapshotProviderQueue = DispatchQueue(
        label: "ch.threema.contactSnapshotProviderQueue",
        qos: .userInteractive,
        attributes: [],
        autoreleaseFrequency: .inherit,
        target: nil
    )
    
    init(
        in tableView: UITableView,
        contactProvider: ContactProvider,
        delegate: ContactListDataSourceDelegate
    ) {
        ContactListCellProvider.registerCells(in: tableView)
        self.contactProvider = contactProvider
        self.delegate = delegate
        
        super.init(tableView: tableView) { tableView, indexPath, itemIdentifier in
//            switch itemIdentifier {
//            case let .contact(contactID):
            ContactListCellProvider.dequeueContactCell(
                for: indexPath,
                and: contactProvider.contact(for: itemIdentifier as! ContactID),
                in: tableView
            )
//            }
        }
    
        createSnapshot(for: contactProvider.contacts() as! [NSManagedObjectID])
        contactProvider.currentSnapshot
//            .receive(on: snapshotProviderQueue)
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                guard let self else {
                    return
                }
                // .map { Row.contact(contactID: $0 as! ContactID)}
                apply(snapshot)
            }
            .store(in: &subscriptions)
    }
    
    deinit {
        subscriptions.removeAll()
    }
    
    func createSnapshot(for ids: [NSManagedObjectID], animated: Bool = true) {
//        var snapshot = ContactListSnapshot()
        var snapshot = NSDiffableDataSourceSnapshot<String, NSManagedObjectID>()
//        snapshot.appendSections([.main])
        snapshot.appendSections([""])
        
        defer {
            apply(snapshot, animatingDifferences: animated)
        }
        
        snapshot.appendItems(
            //            ids.map { Row.contact(contactID: $0 as! ContactID)},
            ids,
            toSection: ""
        )
    }
}
