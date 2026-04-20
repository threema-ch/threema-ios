import CocoaLumberjackSwift
import Coordinator
import Foundation
import SwiftUI
import ThreemaEssentials
import ThreemaFramework

final class ContactListCoordinator: NSObject, Coordinator, CurrentDestinationHolderProtocol {
    // MARK: - Internal destination
    
    enum InternalDestination: Equatable {
        case contact(objectID: NSManagedObjectID?)
        case workContact(objectID: NSManagedObjectID?)
        case groupFromID(_ objectID: NSManagedObjectID?)
        case group(ThreemaFramework.Group)
        case distributionList(objectID: NSManagedObjectID?)
        
        static func == (lhs: InternalDestination, rhs: InternalDestination) -> Bool {
            switch (lhs, rhs) {
            case let (.contact(lhsContactID), .contact(rhsContactID)):
                lhsContactID == rhsContactID
                
            case let (.workContact(lhsWorkContactID), .workContact(rhsWorkContactID)):
                lhsWorkContactID == rhsWorkContactID
                
            case let (.groupFromID(lhsGroupID), .groupFromID(rhsGroupID)):
                lhsGroupID == rhsGroupID
                
            case let (.group(lhsGroup), .group(rhsGroup)):
                lhsGroup.groupID == rhsGroup.groupID
                
            case let (.distributionList(lhsDistributionListID), .distributionList(rhsDistributionListID)):
                lhsDistributionListID == rhsDistributionListID
                
            default:
                false
            }
        }
    }
    
    // MARK: - Coordinator
    
    var childCoordinators: [any Coordinator] = []
    var rootViewController: UIViewController {
        rootNavigationController
    }
    
    var currentDestination: InternalDestination?
    
    private(set) lazy var contactListViewController: ContactListContainerViewController = {
        let viewController = contactListContainerFactory.make(
            contactListActionDelegate: self,
            contactListSearchResultsDelegate: self
        )
        
        let tab = ThreemaTab(.contacts)
        viewController.tabBarItem = tab.tabBarItem
        viewController.title = tab.title
        
        return viewController
    }()
    
    private lazy var rootNavigationController = StatusNavigationController(
        shouldAllowBranding: false
    )
    
    private lazy var navigationDestinationResetter = NavigationDestinationResetter(
        rootViewController: contactListViewController,
        splitViewController: presentingViewController,
        destinationHolder: self.eraseToAnyDestinationHolder()
    )
    
    // MARK: - Private properties
    
    private weak var presentingViewController: ThreemaSplitViewController?
    private let businessInjector: BusinessInjectorProtocol
    private let contactListContainerFactory: ContactListContainerViewControllerFactory
    private let viewControllerForItem: (ContactListAddItem) -> UIViewController
    private let viewControllerForDestination: (InternalDestination) -> UIViewController?
    private let isWork: () -> Bool
    
    // MARK: - Lifecycle

    init(
        presentingViewController: ThreemaSplitViewController,
        businessInjector: BusinessInjectorProtocol,
        contactListContainerFactory: ContactListContainerViewControllerFactory,
        viewControllerForItem: @escaping (ContactListAddItem) -> UIViewController,
        viewControllerForDestination: @escaping (InternalDestination) -> UIViewController?,
        isWork: @autoclosure @escaping () -> Bool
    ) {
        self.presentingViewController = presentingViewController
        self.businessInjector = businessInjector
        self.contactListContainerFactory = contactListContainerFactory
        self.viewControllerForItem = viewControllerForItem
        self.viewControllerForDestination = viewControllerForDestination
        self.isWork = isWork
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
        
        guard let viewController = viewControllerForDestination(
            destination
        ) else {
            return
        }
        
        presentingViewController?.show(viewController, sender: self)
        
        contactListViewController.updateSelection(for: destination)
    }
    
    func resetSelection() {
        resetCurrentDestination()
        contactListViewController.updateSelection(for: .contact(objectID: nil))
        presentingViewController?.setViewControllers([], for: .contacts)
    }
}

// MARK: - ContactListActionDelegate

extension ContactListCoordinator: ContactListActionDelegate {
    func didSelect(_ destination: ContactListCoordinator.InternalDestination) {
        show(destination)
    }
    
    func add(_ item: ContactListAddItem) {
        let viewController = viewControllerForItem(item)
        rootViewController.present(viewController, animated: true)
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

extension ContactListCoordinator: ContactListSearchResultsDelegate {
    func present(for destination: ContactListCoordinator.InternalDestination) {
        show(destination)
    }
    
    func handleDirectoryContact(
        _ directoryContact: CompanyDirectoryContact
    ) async {
        let contactStore = businessInjector.contactStore
        let entityManager = businessInjector.entityManager
        
        if let (_, contactEntity) = contactStore.updateAcquaintanceLevelToDirect(
            for: ThreemaIdentity(directoryContact.id),
            entityManager: entityManager
        ) {
            show(.contact(objectID: contactEntity.objectID))
            return
        }
        
        do {
            let addedContactEntity = try await withCheckedThrowingContinuation {
                [contactStore] (continuation: CheckedContinuation<Any, Error>) in
                contactStore.addWorkContact(
                    with: directoryContact.id,
                    publicKey: directoryContact.pk,
                    firstname: directoryContact.first,
                    lastname: directoryContact.last,
                    csi: directoryContact.csi,
                    jobTitle: directoryContact.jobTitle,
                    department: directoryContact.department,
                    acquaintanceLevel: .direct
                ) { addedContactEntity in
                    continuation.resume(returning: addedContactEntity)
                } onError: { error in
                    continuation.resume(throwing: error)
                }
            }
            
            guard let contactEntity = addedContactEntity as? ContactEntity else {
                DDLogError("Add work contact failed")
                return
            }
            
            Task { @MainActor [weak self, contactEntity] in
                self?.show(.contact(objectID: contactEntity.objectID))
            }
        }
        catch {
            DDLogError("Add work contact failed \(error)")
            return
        }
    }
    
    func isDirectoryContactAvailable(for id: String) -> Bool {
        let entityManager = businessInjector.entityManager
        let entityFetcher = entityManager.entityFetcher
        
        return entityManager.performAndWait { [entityFetcher] in
            entityFetcher.contactEntity(for: id)
        } != nil
    }
}
