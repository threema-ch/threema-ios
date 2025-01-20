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

class ContactListTableViewContainerViewController: ContainerViewController {
    
    private lazy var contacts = ContactListViewController(itemsDelegate: self)
    private lazy var groups = GroupListViewController(itemsDelegate: self)
    private lazy var distributionList = DistributionListViewController(itemsDelegate: self)
    
    #if THREEMA_WORK || THREEMA_ONPREM
        private lazy var work = WorkContactListViewController(itemsDelegate: self)
    #endif
    
    private lazy var internalNavItem = ContactListNavigationItem(delegate: self)
    
    private var workContactsEnabled = false
    
    override var navigationItem: ContactListNavigationItem { internalNavItem }
    
    override var viewControllers: [UIViewController] {
        #if THREEMA_WORK
            [contacts, groups, distributionList, work]
        #elseif THREEMA_ONPREM
            [work, groups, distributionList]
        #else
            [contacts, groups, distributionList]
        #endif
    }
    
    init() {
        super.init()
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
            #if THREEMA_WORK || THREEMA_ONPREM
                work.refresh()
            #endif
        }
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - ContactListActionDelegate

extension ContactListTableViewContainerViewController: ContactListActionDelegate {
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
        #if THREEMA_WORK
            navigationItem.shouldShowWorkButton = item == .contacts
            guard let workIndex = viewControllers.firstIndex(of: work), workContactsEnabled, item == .contacts else {
                return switchToViewController(at: item.rawValue)
            }
            switchToViewController(at: workIndex)
        #else
            switchToViewController(at: item.rawValue)
        #endif
    }
    
    func didToggleWorkContacts(_ isTurnedOn: Bool) {
        workContactsEnabled = isTurnedOn
        switchToViewController(
            at: isTurnedOn ? ContactListFilterItem.allCases.count : ContactListFilterItem.contacts
                .rawValue
        )
    }
}
