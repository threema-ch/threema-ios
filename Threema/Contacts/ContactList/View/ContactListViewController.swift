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
import Foundation
import SwiftUI
import ThreemaFramework

@objc class ContactListViewController: ThemedTableViewController {
    private lazy var provider = ContactListProvider()
    
    private lazy var dataSource: ContactListDataSource = .init(
        provider: provider,
        cellProvider: ContactListCellProvider(),
        in: tableView
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = dataSource
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let id = dataSource.itemIdentifier(for: indexPath), let contact = provider.entity(for: id) else {
            return
        }
        show(SingleDetailsViewController(for: contact, displayStyle: .default), sender: self)
    }
}

@objc class WorkContactListViewController: ThemedTableViewController {
    private lazy var provider = WorkContactListProvider()
    
    private lazy var dataSource: ContactListDataSource = .init(
        provider: provider,
        cellProvider: ContactListCellProvider(),
        in: tableView
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = dataSource
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let id = dataSource.itemIdentifier(for: indexPath), let contact = provider.entity(for: id) else {
            return
        }
        show(SingleDetailsViewController(for: contact, displayStyle: .default), sender: self)
    }
}

@objc class GroupListViewController: ThemedTableViewController {
    private lazy var provider = GroupListProvider()
    
    private lazy var dataSource: ContactListDataSource = .init(
        provider: GroupListProvider(),
        cellProvider: GroupListCellProvider(),
        in: tableView,
        sectionIndexEnabled: false
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = dataSource
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let id = dataSource.itemIdentifier(for: indexPath), let group = provider.entity(for: id) else {
            return
        }
        show(GroupDetailsViewController(for: group, displayStyle: .default), sender: self)
    }
}
