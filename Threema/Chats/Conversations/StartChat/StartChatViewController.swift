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

import SwiftUI
import ThreemaMacros
import UIKit

protocol StartChatContactSelectionHandler: ContactListSearchResultSelectionHandler { }

final class StartChatViewController: ThemedViewController {
    
    // MARK: - Private properties

    private lazy var provider = ContactListProvider()
    private lazy var cellProvider = ContactListCellProvider()
    private lazy var tableViewController = StartChatContactListTableViewController(
        cellProvider: cellProvider,
        provider: provider,
        businessInjector: BusinessInjector.ui,
        style: .insetGrouped
    )
    private lazy var searchController: UISearchController = {
        var controller = UISearchController(searchResultsController: contactListSearchResultsController)
        controller.searchResultsUpdater = contactListSearchResultsController
        controller.obscuresBackgroundDuringPresentation = false
        controller.searchBar.placeholder = #localize("contact_list_search_bar_placeholder")
        return controller
    }()

    private lazy var contactListSearchResultsController = {
        let controller = ContactListSearchResultViewController(
            businessInjector: BusinessInjector.ui,
            cellProvider: cellProvider,
            provider: provider,
            allowsMultiSelect: false
        )
        controller.delegate = self
        
        return controller
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = #localize("start_chat_title")
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: #localize("cancel"),
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        
        setupViews()
    }

    // MARK: - Configuration
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    private func setupViews() {
        tableViewController.delegate = self
        tableViewController.view.translatesAutoresizingMaskIntoConstraints = false
        
        addChild(tableViewController)
        view.addSubview(tableViewController.view)
        view.backgroundColor = .systemGroupedBackground
        
        NSLayoutConstraint.activate([
            tableViewController.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableViewController.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableViewController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        tableViewController.didMove(toParent: self)
    }
    
    override func updateColors() {
        super.updateColors()
        
        view.backgroundColor = Colors.backgroundGroupedViewController
    }
}

// MARK: - StartChatContactSelectionHandler

extension StartChatViewController: StartChatContactSelectionHandler {
    func didSelect(item contact: Contact) {
        presentingViewController?.dismiss(animated: true) {
            let entity = BusinessInjector.ui.entityManager.entityFetcher.contactEntity(for: contact.identity.rawValue)
            
            let info: [String: Any] = [
                kKeyContact: entity as Any,
                kKeyForceCompose: true,
            ]

            NotificationCenter.default.post(
                name: Notification.Name(kNotificationShowConversation),
                object: nil,
                userInfo: info
            )
        }
    }
    
    func didDeselect(item: Contact) {
        // no-op, not multiselect
    }
    
    func selectionFor(item: Contact) -> Bool {
        false
    }
}
