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

final class StartChatContactListTableViewController: ThemedTableViewController {
    
    // MARK: - Public properties
    
    weak var delegate: StartChatContactSelectionHandler?
    
    // MARK: - Private Properties
    
    private let cellProvider: ContactListCellProvider
    private let provider: ContactListProvider
    private let businessInjector: BusinessInjectorProtocol
    private lazy var dataSource = StartChatContactListDataSource(
        provider: provider,
        cellProvider: cellProvider,
        entityManager: businessInjector.entityManager,
        in: tableView,
    )
    
    // MARK: - Lifecycle
    
    init(
        cellProvider: ContactListCellProvider,
        provider: ContactListProvider,
        businessInjector: BusinessInjectorProtocol,
        style: UITableView.Style = .plain
    ) {
        self.cellProvider = cellProvider
        self.provider = provider
        self.businessInjector = businessInjector
        super.init(style: style)
        
        // This fixes the inset for the footer
        additionalSafeAreaInsets.bottom = 0
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = dataSource
    }
    
    // MARK: - TableView selection
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch dataSource.itemIdentifier(for: indexPath) {
        case .addContact:
            addContact()
        
        case .addGroup:
            addGroup()
        
        case .addDistributionList:
            addDistributionList()
        
        default:
            guard let contact = contact(for: indexPath) else {
                return
            }
            
            delegate?.didSelect(item: contact)
        }
    }
    
    // MARK: - Helper

    private func contact(for indexPath: IndexPath) -> Contact? {
        guard
            let row = dataSource.itemIdentifier(for: indexPath),
            case let .contact(id) = row,
            let contact = provider.entity(for: id) else {
            return nil
        }
        
        return contact
    }
    
    // MARK: - Actions
    
    private func addContact() {
        let presentingVC = presentingViewController
        
        presentingVC?.dismiss(animated: true)
        presentingVC?.present(
            UIHostingController(rootView: AddContactView(onSaveDisplayMode: .showChat)),
            animated: true
        )
    }

    private func addGroup() {
        let presentingVC = presentingViewController
        
        presentingVC?.dismiss(animated: true)
        let viewController =
            UINavigationController(
                rootViewController: SelectContactListViewController(
                    forGroupCreation: [],
                    onSaveDisplayMode: .showChat
                )
            )
        presentingVC?.present(viewController, animated: true)
    }

    private func addDistributionList() {
        let presentingVC = presentingViewController
        
        presentingVC?.dismiss(animated: true)
        let viewController =
            UINavigationController(
                rootViewController: SelectContactListViewController(
                    forListCreation: [],
                    onSaveDisplayMode: .showChat
                )
            )
        presentingVC?.present(viewController, animated: true)
    }
}
