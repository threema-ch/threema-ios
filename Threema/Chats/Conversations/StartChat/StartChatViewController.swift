import SwiftUI
import ThreemaFramework
import ThreemaMacros
import UIKit

protocol StartChatContactSelectionHandler: ItemListSearchResultSelectionHandler { }

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
        navigationItem.leftBarButtonItem = UIBarButtonItem.cancelButton(target: self, selector: #selector(cancelTapped))
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
    func didSelect(id: ItemID) {
        presentingViewController?.dismiss(animated: true) {
            guard let entity = BusinessInjector.ui.entityManager.entityFetcher.contactEntity(with: id) else {
                assertionFailure("Contact entity not found.")
                return
            }

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
    
    func didDeselect(id: ItemID) {
        // no-op, not multiselect
    }
    
    func selectionFor(id: ItemID) -> Bool {
        false
    }
}
