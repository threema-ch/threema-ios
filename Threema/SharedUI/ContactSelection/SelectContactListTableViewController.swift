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

import ThreemaMacros

final class SelectContactListTableViewController: ThemedTableViewController {
    
    // MARK: - Public properties
    
    weak var delegate: ContactSelectionHandler?
    
    // MARK: - Private Properties
    
    private let coordinator: ContactsCoordinator?
    private let cellProvider: ContactListSelectionCellProvider
    private let provider: ContactListProvider
    private let businessInjector: BusinessInjectorProtocol
    private lazy var dataSource = SelectContactListDataSource(
        coordinator: coordinator,
        provider: provider,
        cellProvider: cellProvider,
        entityManager: businessInjector.entityManager,
        in: tableView,
        contentUnavailableConfiguration: unavailableConfiguration
    )
    
    private lazy var unavailableDescription = {
        let stringSyncON = #localize("no_contacts_syncon")
        let stringSyncOFF = #localize("no_contacts_syncoff")
        return UserSettings.shared().syncContacts ? stringSyncON : stringSyncOFF
    }()

    private var unavailableConfiguration: ThreemaTableContentUnavailableView.Configuration {
        ThreemaTableContentUnavailableView.Configuration(
            title: #localize("contact_list_contact_unavailable_title"),
            systemImage: "person.2.fill",
            description: unavailableDescription,
            actions: []
        )
    }
    
    // MARK: - Lifecycle
    
    init(
        coordinator: ContactsCoordinator?,
        cellProvider: ContactListSelectionCellProvider,
        provider: ContactListProvider,
        businessInjector: BusinessInjectorProtocol,
        style: UITableView.Style = .plain
    ) {
        self.coordinator = coordinator
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
        tableView.allowsMultipleSelection = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        dataSource.contentUnavailableConfiguration = unavailableConfiguration
    }
    
    // MARK: - TableView selection
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let contact = contact(for: indexPath) else {
            return
        }
        
        delegate?.didSelect(item: contact)
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard let contact = contact(for: indexPath) else {
            return
        }
        
        delegate?.didDeselect(item: contact)
    }
    
    func updateSelection() {
        let snapshot = dataSource.snapshot()
        for identifier in snapshot.itemIdentifiers {
            guard let indexPath = dataSource.indexPath(for: identifier),
                  let contact = contact(for: indexPath),
                  let isSelected = delegate?.selectionFor(item: contact) else {
                continue
            }
            
            if isSelected {
                tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
            }
            else {
                tableView.deselectRow(at: indexPath, animated: true)
            }
        }
    }
    
    // MARK: - Helper

    func contact(for indexPath: IndexPath) -> Contact? {
        guard
            let id = dataSource.itemIdentifier(for: indexPath),
            let contact = provider.entity(for: id) else {
            return nil
        }
        
        return contact
    }
}
