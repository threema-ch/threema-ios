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

protocol ContactSelectionHandler: AnyObject, ContactListSearchResultSelectionHandler {
    func didSelect(item: Contact)
    func didDeselect(item: Contact)
    func selectionFor(item: Contact) -> Bool
    func selectedItems() -> [Contact]
}

final class SelectContactListViewController: ThemedViewController {
    
    // MARK: - Private properties

    private var selectedContacts: [Contact] = []
    private var editData: EditData?
    private let contactSelectionMode: SelectContactListDisplayMode
    private let onSaveDisplayMode: OnSaveDisplayMode
    private let onEdit: (([Contact]) -> Void)?
    private lazy var provider = ContactListProvider()
    private lazy var cellProvider = ContactListSelectionCellProvider()
    private lazy var carouselView = {
        let headerView = SelectContactListHeaderView(
            collectionKind: contactSelectionMode.countLabelKind
        )
        headerView.setContentHuggingPriority(.required, for: .vertical)
        headerView.setContentCompressionResistancePriority(.required, for: .vertical)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.delegate = self
        return headerView
    }()

    private lazy var contentView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.distribution = .fill
        return stackView
    }()

    private lazy var tableViewController = SelectContactListTableViewController(
        coordinator: nil,
        cellProvider: cellProvider,
        provider: provider,
        businessInjector: BusinessInjector.ui,
        style: .insetGrouped
    )
    private lazy var searchController: UISearchController = {
        var controller = UISearchController(searchResultsController: contactListSearchResultsController)
        controller.delegate = self
        controller.searchResultsUpdater = contactListSearchResultsController
        controller.obscuresBackgroundDuringPresentation = false
        controller.searchBar.placeholder = #localize("contact_list_search_bar_placeholder")
        controller.searchBar.setValue(#localize("Done"), forKey: "cancelButtonText")
        return controller
    }()

    private lazy var contactListSearchResultsController = {
        let controller = ContactListSearchResultViewController(
            businessInjector: BusinessInjector.ui,
            cellProvider: cellProvider,
            provider: provider,
            allowsMultiSelect: true
        )
        controller.delegate = self
        
        return controller
    }()

    // MARK: - Lifecycle

    init(
        contentSelectionMode: SelectContactListDisplayMode,
        onSaveDisplayMode: OnSaveDisplayMode = .showDetails,
        onEdit: (([Contact]) -> Void)? = nil
    ) {
        self.onEdit = onEdit
        self.contactSelectionMode = contentSelectionMode
        self.onSaveDisplayMode = onSaveDisplayMode
        super.init(nibName: nil, bundle: nil)
    }
    
    @objc convenience init(
        forGroupCreation selectedContacts: [Contact],
        onSaveDisplayMode: OnSaveDisplayMode = .showDetails
    ) {
        self.init(
            contentSelectionMode: .group(.create(data: .init(contacts: selectedContacts))),
            onSaveDisplayMode: onSaveDisplayMode
        )
    }

    @objc convenience init(
        forListCreation selectedContacts: [Contact],
        onSaveDisplayMode: OnSaveDisplayMode = .showDetails
    ) {
        self.init(
            contentSelectionMode: .distributionList(.create(data: .init(contacts: selectedContacts))),
            onSaveDisplayMode: onSaveDisplayMode
        )
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = contactSelectionMode.title
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: #localize("cancel"),
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        
        navigationItem.searchController = searchController
        
        preFillData()
        updateNextButton()
        setupViews()
        addObservers()
        tableViewController.updateSelection()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        carouselView.configure()
    }

    // MARK: - Configuration
    
    private func updateNextButton() {
        
        let title =
            if contactSelectionMode.isEdit {
                #localize("Done")
            }
            else {
                selectedContacts.isEmpty ? #localize("skip") : #localize("next")
            }
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: title,
            style: .done,
            target: self,
            action: #selector(nextTapped)
        )
        
        if selectedContacts.count > Group.maxGroupMembers {
            navigationItem.rightBarButtonItem?.isEnabled = false
        }
    }

    private func preFillData() {
        selectedContacts = contactSelectionMode.selectedContacts
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func nextTapped() {
        if contactSelectionMode.isEdit {
            onEdit?(selectedContacts)
            dismiss(animated: true)
        }
        else {
            let data = EditData(
                name: editData?.name,
                profilePicture: editData?.profilePicture,
                contacts: selectedContacts
            )
            let config: CreateEditGroupDistributionListDisplayMode

            switch contactSelectionMode {
            case .group(.create):
                config = .group(.create(data: data))
                
            case .distributionList(.create):
                config = .distributionList(.create(data: data))
                
            case let .group(.clone(group)):
                config = .group(.clone(group: group, data: data))

            default:
                fatalError("Unsupported contact selection mode for this flow")
            }

            let controller = CreateEditGroupDistributionViewController(
                for: config,
                onSaveDisplayMode: onSaveDisplayMode
            ) { [weak self] editData in
                self?.editData = editData
                self?.selectedContacts = editData.contacts
                self?.updateNextButton()
                self?.carouselView.configure()
                self?.tableViewController.updateSelection()
            }

            navigationController?.pushViewController(controller, animated: true)
        }
    }

    private func addObservers() {
        // Dynamic type
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
    }

    private func setupViews() {
        tableViewController.delegate = self
        
        addChild(tableViewController)
        view.addSubview(contentView)
        view.backgroundColor = .systemGroupedBackground
        
        contentView.addArrangedSubview(carouselView)
        contentView.addArrangedSubview(tableViewController.view)
        contentView.setCustomSpacing(8, after: carouselView)
        
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        tableViewController.didMove(toParent: self)
        
        carouselView.configure()
    }
    
    override func updateColors() {
        super.updateColors()
        
        view.backgroundColor = Colors.backgroundGroupedViewController
    }
    
    // MARK: - Notification

    @objc func contentSizeCategoryDidChange() {
        carouselView.contentSizeCategoryDidChange()
        tableViewController.updateSelection()
    }
}

// MARK: - ContactSelectionHandler

extension SelectContactListViewController: ContactSelectionHandler {
    func selectedItems() -> [Contact] {
        selectedContacts
    }
    
    func didSelect(item: Contact) {
        guard !selectedContacts.contains(where: { $0.identity == item.identity }) else {
            return
        }
        carouselView.isHidden = false
        selectedContacts.append(item)
        updateNextButton()
        carouselView.configure()
    }
    
    func didDeselect(item: Contact) {
        selectedContacts.removeAll { $0.identity == item.identity }
        updateNextButton()
        carouselView.configure()
        tableViewController.updateSelection()
        
        carouselView.isHidden = selectedContacts.isEmpty
    }
    
    func selectionFor(item: Contact) -> Bool {
        selectedContacts.contains { $0.identity == item.identity }
    }
}

// MARK: - UISearchControllerDelegate

extension SelectContactListViewController: UISearchControllerDelegate {
    func didDismissSearchController(_ searchController: UISearchController) {
        tableViewController.updateSelection()
        carouselView.configure()
    }
}

// MARK: - SelectContactListHeaderViewDelegate

extension SelectContactListViewController: SelectContactListHeaderViewDelegate {
    func header(
        _ header: SelectContactListHeaderView,
        itemForIndexPath indexPath: IndexPath
    ) -> Contact {
        selectedContacts[indexPath.row]
    }
}
