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

import Coordinator
import Foundation
import SwiftUI
import ThreemaMacros

final class ContactsCoordinator: NSObject, Coordinator, CurrentDestinationHolding {
    // MARK: - Internal destination
    
    enum InternalDestination: Equatable {
        case contact(objectID: NSManagedObjectID?)
        case workContact(objectID: NSManagedObjectID?)
        case group(objectID: NSManagedObjectID?)
        case distributionList(objectID: NSManagedObjectID?)
    }
    
    // MARK: - Coordinator
    
    var childCoordinators: [any Coordinator] = []
    var rootViewController: UIViewController {
        rootNavigationController
    }
    
    var currentDestination: InternalDestination?
    
    private lazy var contactListViewController: ContactListContainerViewController = {
        let viewController = makeContactListContainerViewController()
        
        let tabBarItem = ThreemaTabBarController.TabBarItem(.contacts)
        viewController.tabBarItem = tabBarItem.uiTabBarItem
        viewController.title = tabBarItem.title
        
        return viewController
    }()
    
    private lazy var rootNavigationController = UINavigationController()
    
    private lazy var navigationDestinationResetter = NavigationDestinationResetter(
        rootViewController: contactListViewController,
        destinationHolder: self.eraseToAnyDestinationHolder()
    )
    
    // MARK: - Private properties
    
    private weak var presentingViewController: UIViewController?
    private var businessInjector = BusinessInjector.ui
    
    // MARK: - Lifecycle

    init(presentingViewController: UIViewController) {
        self.presentingViewController = presentingViewController
    }
    
    // MARK: - Presentation
    
    func start() {
        rootNavigationController.delegate = navigationDestinationResetter
        
        /// Due to this coordinator's rootViewController being part of a
        /// `UITabViewController`, it's not needed to present anything here.
        /// The rootViewController is added by to the `UITabViewController`'s
        /// viewControllers in ``AppCoordinator``'s `configureSplitViewController` method.
        rootNavigationController.setViewControllers(
            [contactListViewController],
            animated: false
        )
    }
    
    func show(_ destination: InternalDestination) {
        guard currentDestination != destination else {
            return
        }
        currentDestination = destination

        switch destination {
        case let .contact(objectID):
            showContact(for: objectID)
            
        case let .workContact(objectID):
            showContact(for: objectID)
            
        case let .group(objectID):
            showGroup(for: objectID)
            
        case let .distributionList(objectID):
            showDistributionList(for: objectID)
        }
        
        contactListViewController.updateSelection(for: destination)
    }
    
    // MARK: - Private functions
    
    private func makeContactListContainerViewController() -> ContactListContainerViewController {
        let currentDestinationFetcher = { [weak self] in
            self?.currentDestination
        }
        
        let shouldAllowAutoDeselection = { [weak self] in
            let traitCollection = self?.presentingViewController?.traitCollection
            return traitCollection?.horizontalSizeClass == .compact
        }
        
        return ContactListContainerViewController(
            contactListViewController: { [weak self] in
                ContactListViewController(
                    currentDestinationFetcher: currentDestinationFetcher,
                    shouldAllowAutoDeselection: shouldAllowAutoDeselection,
                    itemsDelegate: self
                )
            },
            groupListViewController: { [weak self] in
                GroupListViewController(
                    currentDestinationFetcher: currentDestinationFetcher,
                    shouldAllowAutoDeselection: shouldAllowAutoDeselection,
                    itemsDelegate: self
                )
            },
            distributionListViewController: { [weak self] in
                DistributionListViewController(
                    currentDestinationFetcher: currentDestinationFetcher,
                    shouldAllowAutoDeselection: shouldAllowAutoDeselection,
                    itemsDelegate: self
                )
            },
            workContactListViewController: { [weak self] in
                WorkContactListViewController(
                    currentDestinationFetcher: currentDestinationFetcher,
                    shouldAllowAutoDeselection: shouldAllowAutoDeselection,
                    itemsDelegate: self
                )
            },
            searchResultsController: { [weak self] in
                ContactListSearchResultsViewController(
                    businessInjector: BusinessInjector.ui,
                    delegate: self
                )
            },
            navigationItem: ContactListNavigationItem(delegate: self)
        )
    }

    private func showContact(for objectID: NSManagedObjectID?) {
        guard let objectID else {
            return
        }
        
        let em = businessInjector.entityManager
        let contactEntity = em.performAndWait {
            em.entityFetcher.existingObject(with: objectID) as? ContactEntity
        }
        
        guard let contactEntity else {
            return
        }
        
        let vc = SingleDetailsViewController(for: Contact(contactEntity: contactEntity), displayStyle: .default)
        presentingViewController?.show(vc, sender: self)
    }
    
    private func showGroup(for objectID: NSManagedObjectID?) {
        guard let objectID else {
            return
        }
        
        let em = businessInjector.entityManager
        let conversationEntity = em.performAndWait {
            em.entityFetcher.existingObject(with: objectID) as? ConversationEntity
        }
        guard let conversationEntity,
              let group = businessInjector.groupManager.getGroup(conversation: conversationEntity) else {
            return
        }
        
        let vc = GroupDetailsViewController(for: group, displayStyle: .default)
        presentingViewController?.show(vc, sender: self)
    }
    
    private func showDistributionList(for objectID: NSManagedObjectID?) {
        guard let objectID else {
            return
        }
        
        let em = businessInjector.entityManager
        let distributionListEntity = em.performAndWait {
            em.entityFetcher.existingObject(with: objectID) as? DistributionListEntity
        }
        guard let distributionListEntity else {
            return
        }
        
        let vc = DistributionListDetailsViewController(
            for: DistributionList(distributionListEntity: distributionListEntity),
            displayStyle: .default
        )
        presentingViewController?.show(vc, sender: self)
    }
}

// MARK: - ContactListActionDelegate

extension ContactsCoordinator: ContactListActionDelegate {
    func didSelect(_ destination: ContactsCoordinator.InternalDestination) {
        show(destination)
    }
    
    func add(_ item: ContactListAddItem) {
        let controller: UIViewController =
            switch item {
            case .contacts:
                UIHostingController(rootView: AddContactView())
            case .groups:
                UINavigationController(
                    rootViewController: SelectContactListViewController(
                        contentSelectionMode: .group(.create(data: .empty))
                    )
                )
            case .distributionLists:
                UINavigationController(
                    rootViewController: SelectContactListViewController(
                        contentSelectionMode: .distributionList(.create(data: .empty))
                    )
                )
            }
        
        rootViewController.present(controller, animated: true)
    }
    
    func filterChanged(_ item: ContactListFilterItem) {
        if TargetManager.isWork {
            
            contactListViewController.navigationItem.shouldShowWorkButton = item == .contacts
            
            let viewControllers = contactListViewController.viewControllers
            guard let workIndex = viewControllers.firstIndex(of: contactListViewController.work),
                  contactListViewController.workContactsEnabled, item == .contacts else {
                return contactListViewController.switchToViewController(at: item.rawValue)
            }
            contactListViewController.switchToViewController(at: workIndex)
        }
        else {
            contactListViewController.switchToViewController(at: item.rawValue)
        }
    }
    
    func didToggleWorkContacts(_ isTurnedOn: Bool) {
        contactListViewController.workContactsEnabled(isTurnedOn)
        let index = isTurnedOn
            ? ContactListFilterItem.allCases.count
            : ContactListFilterItem.contacts.rawValue
        contactListViewController.switchToViewController(at: index)
    }
}

// MARK: - ContactListSearchResultsDelegate

extension ContactsCoordinator: ContactListSearchResultsDelegate {
    func present(for destination: ContactsCoordinator.InternalDestination) {
        show(destination)
    }
}
