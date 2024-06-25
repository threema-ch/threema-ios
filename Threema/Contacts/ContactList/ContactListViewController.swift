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
    #if THREEMA_WORK
        private lazy var switchWorkContacts = WorkButtonView(didToggleWorkContacts)
    #endif
    private lazy var contactAddMenu = ContactListAddMenu(add)
    private lazy var contactListFilter = ContactListFilterMenuView(filterChanged)
    
    private lazy var dataSource: ContactListDataSource<NSManagedObjectID, ContactListProvider> = .init(
        in: tableView,
        contactProvider: .init(),
        delegate: ContactListDataSourceDelegateTest()
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableViewSetup()
        navigationViewSetup()
    }
    
    private func tableViewSetup() {
        tableView.delegate = self
        tableView.dataSource = dataSource
    }
    
    private func navigationViewSetup() {
        navigationItem.titleView = contactListFilter.view
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .add, menu: contactAddMenu)
        #if THREEMA_WORK
            navigationItem.leftBarButtonItem = UIBarButtonItem(customView: switchWorkContacts.view)
        #endif
    }
}

extension ContactListViewController {
    // MARK: - WorkButtonView

    #if THREEMA_WORK
        private func didToggleWorkContacts(_ isTurnedOn: Bool) {
            print("\(#function): \(isTurnedOn)")
        }
    #endif
    
    // MARK: - ContactListFilterMenuView
    
    private func filterChanged(_ item: ContactListFilterItem) {
        print(#function)
        // change the datasource or other to switch the table
        switch item {
        case .contacts:
            print(item)
        case .groups:
            print(item)
        case .distributionLists:
            print(item)
        }
    }

    // MARK: - ContactListAddMenu
    
    private func add(_ item: ContactListAddItem) {
        print(#function)
        
        switch item {
        case .contacts:
            print(item)
        case .groups:
            print(item)
        case .distributionLists:
            print(item)
        }
    }
}

// extension ContactListViewController: NSFetchedResultsControllerDelegate {
//    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
//        dataSource.updateSnapshot()
//    }
// }
