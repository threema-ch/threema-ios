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
import SwiftUI
import ThreemaMacros

final class ContactListContainerViewController: UIViewController {
    
    // MARK: - Properties

    private var currentViewController: ContactListBaseViewController?
    
    private let contactListViewController: () -> ContactListViewController
    private lazy var contacts = contactListViewController()

    private let groupListViewController: () -> GroupListViewController
    private lazy var groups = groupListViewController()
    
    private let distributionListViewController: () -> DistributionListViewController
    private lazy var distributionList = distributionListViewController()
    
    private let workContactListViewController: () -> WorkContactListViewController
    private(set) lazy var work = workContactListViewController()
    
    private(set) var workContactsEnabled = false
    
    private let contactListNavigationItem: ContactListNavigationItem
    override var navigationItem: ContactListNavigationItem { contactListNavigationItem }
    
    private lazy var searchController: UISearchController = {
        var controller = UISearchController(searchResultsController: contactListSearchResultsController)
        controller.delegate = contactListSearchResultsController
        controller.searchResultsUpdater = contactListSearchResultsController
        controller.obscuresBackgroundDuringPresentation = false
        controller.searchBar.placeholder = #localize("contact_list_search_bar_placeholder")
        controller.searchBar.searchTextField.allowsCopyingTokens = false
        return controller
    }()
    
    private let searchResultsController: () -> ContactListSearchResultsViewController
    private lazy var contactListSearchResultsController = searchResultsController()
    
    var viewControllers: [ContactListBaseViewController] {
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
    
    init(
        contactListViewController: @escaping () -> ContactListViewController,
        groupListViewController: @escaping () -> GroupListViewController,
        distributionListViewController: @escaping () -> DistributionListViewController,
        workContactListViewController: @escaping () -> WorkContactListViewController,
        searchResultsController: @escaping () -> ContactListSearchResultsViewController,
        navigationItem: ContactListNavigationItem
    ) {
        self.contactListViewController = contactListViewController
        self.groupListViewController = groupListViewController
        self.distributionListViewController = distributionListViewController
        self.workContactListViewController = workContactListViewController
        self.searchResultsController = searchResultsController
        self.contactListNavigationItem = navigationItem
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        /// Needed to make the search bar appear the first time without scrolling
        navigationItem.hidesSearchBarWhenScrolling = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        /// Resetting to the correct value, since it has already appeared
        navigationItem.hidesSearchBarWhenScrolling = true
    }
    
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
    
    // MARK: - Updates
    
    public func updateSelection(for destination: ContactsCoordinator.InternalDestination) {
        
        switch destination {
        case .contact:
            guard let index = viewControllers.firstIndex(where: {
                $0 is ContactListViewController
            }) else {
                break
            }
            switchToViewController(at: index)

        case .workContact:
            guard let index = viewControllers.firstIndex(where: {
                $0 is WorkContactListViewController
            }) else {
                break
            }
            switchToViewController(at: index)

        case .group:
            guard let index = viewControllers.firstIndex(where: {
                $0 is GroupListViewController
            }) else {
                break
            }
            switchToViewController(at: index)

        case .distributionList:
            guard let index = viewControllers.firstIndex(where: {
                $0 is DistributionListViewController
            }) else {
                break
            }
            switchToViewController(at: index)
        }
        
        currentViewController?.updateSelection()
    }
    
    // MARK: - Helpers
    
    func workContactsEnabled(_ enabled: Bool) {
        workContactsEnabled = enabled
    }

    func switchToViewController(at index: Int) {
        if let currentViewController, index == viewControllers.firstIndex(of: currentViewController) {
            return
        }
        
        let newViewController = viewControllers[index]
        currentViewController?.willMove(toParent: nil)
        currentViewController?.view.removeFromSuperview()
        currentViewController?.removeFromParent()
        addChild(newViewController)
        view.addSubview(newViewController.view)
        newViewController.didMove(toParent: self)
        currentViewController = newViewController
        newViewController.view.frame = view.bounds
    }
}
