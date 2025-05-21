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

import Foundation
import ThreemaMacros

class ContactListContainerViewController: UIViewController {
    
    // MARK: - Properties

    private var currentViewController: UIViewController?
    
    private lazy var contacts = ContactListViewController(itemsDelegate: self)
    private lazy var groups = GroupListViewController(itemsDelegate: self)
    private lazy var distributionList = DistributionListViewController(itemsDelegate: self)
    
    private lazy var work = WorkContactListViewController(itemsDelegate: self)
    
    private var workContactsEnabled = false
    
    private lazy var internalNavItem = ContactListNavigationItem(delegate: self)
    
    override var navigationItem: ContactListNavigationItem { internalNavItem }
    
    private lazy var searchController: UISearchController = {
        var controller = UISearchController(searchResultsController: contactListSearchResultsController)
        controller.delegate = contactListSearchResultsController
        controller.searchResultsUpdater = contactListSearchResultsController
        controller.obscuresBackgroundDuringPresentation = false
        controller.searchBar.placeholder = #localize("contact_list_search_bar_placeholder")
        controller.searchBar.searchTextField.allowsCopyingTokens = false
        return controller
    }()
    
    private lazy var contactListSearchResultsController =
        ContactListSearchResultsViewController(businessInjector: BusinessInjector.ui)
    
    var viewControllers: [UIViewController] {
        if TargetManager.isWork {
            [contacts, groups, distributionList, work]
        }
        else if TargetManager.isOnPrem {
            [work, groups, distributionList]
        }
        else {
            [contacts, groups, distributionList]
        }
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.searchController = searchController
        contactListSearchResultsController.setSearchController(searchController)

        switchToViewController(at: ContactListFilterItem.contacts.rawValue)
       
        NotificationCenter.default.addObserver(
            forName: Notification.Name(kNotificationColorThemeChanged),
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self else {
                return
            }
            contacts.refresh()
            groups.refresh()
            distributionList.refresh()
            if TargetManager.isBusinessApp {
                work.refresh()
            }
        }
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Private functions
    
    func switchToViewController(at index: Int) {
        currentViewController?.willMove(toParent: nil)
        currentViewController?.view.removeFromSuperview()
        currentViewController?.removeFromParent()
        addChild(viewControllers[index])
        view.addSubview(viewControllers[index].view)
        viewControllers[index].didMove(toParent: self)
        currentViewController = viewControllers[index]
        viewControllers[index].view.frame = view.bounds
    }
}

// MARK: - ContactListActionDelegate

extension ContactListContainerViewController: ContactListActionDelegate {
    func add(_ item: ContactListAddItem) {
        {
            switch item {
            case .contacts:
                AppDelegate
                    .getMainStoryboard()
                    .instantiateViewController(withIdentifier: "AddContactNavigationController")
            case .groups:
                UIStoryboard(name: "CreateGroup", bundle: nil).instantiateInitialViewController()
            case .distributionLists:
                UINavigationController(rootViewController: DistributionListCreateEditViewController())
            }
        }().map { present($0, animated: true) }
    }
    
    func filterChanged(_ item: ContactListFilterItem) {
        if TargetManager.isWork {
            
            navigationItem.shouldShowWorkButton = item == .contacts
            
            guard let workIndex = viewControllers.firstIndex(of: work), workContactsEnabled, item == .contacts else {
                return switchToViewController(at: item.rawValue)
            }
            switchToViewController(at: workIndex)
        }
        else {
            switchToViewController(at: item.rawValue)
        }
    }
    
    func didToggleWorkContacts(_ isTurnedOn: Bool) {
        workContactsEnabled = isTurnedOn
        switchToViewController(
            at: isTurnedOn ? ContactListFilterItem.allCases.count : ContactListFilterItem.contacts
                .rawValue
        )
    }
}
