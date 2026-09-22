import CocoaLumberjackSwift
import Coordinator
import Foundation
import SwiftUI
import ThreemaEssentials
import ThreemaFramework

final class ContactListCoordinator: NSObject, Coordinator {
    // MARK: - Internal destination

    enum InternalDestination: Hashable {
        case contact(NSManagedObjectID)
        case workContact(NSManagedObjectID)
        /// Payload is the group's conversation `NSManagedObjectID`
        case group(NSManagedObjectID)
        case distributionList(NSManagedObjectID)
    }

    // MARK: - Coordinator

    var childCoordinators: [any Coordinator] = []
    var rootViewController: UIViewController {
        rootNavigationController
    }

    private let router = NavigationRouter()

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
        super.init()

        router.delegate = self
        router.forwardDelegate = self
    }

    // MARK: - Presentation

    func start() {
        /// Due to this coordinator's rootViewController being part of a
        /// `UITabViewController`, it's not needed to present anything here.
        /// The rootViewController is added by to the `UITabViewController`'s
        /// viewControllers in ``AppCoordinator``'s `configureSplitViewController` method.
        rootNavigationController.setViewControllers(
            [contactListViewController],
            animated: false
        )
    }

    func finish() {
        router.unbind()
        for child in childCoordinators {
            child.finish()
        }
        childCoordinators.removeAll()
    }

    func show(_ destination: InternalDestination) {
        setPath([destination], animated: true)
    }

    func resetSelection() {
        setPath([], animated: false)
    }

    // MARK: - Router binding

    /// Hooks for `ThreemaSplitViewNavigationManager` to activate/deactivate this
    /// tab's router when tab selection or the size class changes.
    var routerHandle: RouterManagedTabHandle {
        RouterManagedTabHandle(
            deactivate: { [weak self] in
                self?.router.unbind()
            },
            activateCompact: { [weak self] in
                self?.bindCompact()
            },
            activateRegular: { [weak self] navigationController in
                self?.bindRegular(into: navigationController)
            },
            // No passcode-protected destinations in this tab.
            reauthenticateProtectedDestinations: { },
            releaseMaterializedScreens: { [weak self] in
                guard
                    let self,
                    !router.isBound
                else {
                    return
                }
                router.releaseMaterializedScreens()
                // The tab's own navigation controller retains the compact stack
                // even while inactive — reset it to the root; the next
                // activation re-materializes the stack from the path.
                rootNavigationController.setViewControllers(
                    [contactListViewController],
                    animated: false
                )
            }
        )
    }

    /// Collapsed width: the whole stack lives in the tab's own navigation
    /// controller, rooted in the contact list.
    private func bindCompact() {
        router.bind(
            to: rootNavigationController,
            rootViewController: contactListViewController
        ) { [weak self] destination in
            self?.makeScreen(destination)
        }

        scheduleSelectionSync()
    }

    /// Regular width: the stack renders in the secondary column, rooted in a
    /// placeholder (the contact list stays in the primary column). An empty path
    /// shows just the placeholder.
    private func bindRegular(into navigationController: UINavigationController) {
        router.bind(
            to: navigationController,
            rootViewController: ThreemaLogoViewController(rootView: ThreemaLogoView()),
            rootMode: .placeholder
        ) { [weak self] destination in
            self?.makeScreen(destination)
        }

        scheduleSelectionSync()
    }

    /// While the collapse/expand transition that triggered a (re)bind is running,
    /// the size class still reports the old value and the appearance callbacks
    /// fired during it clear the list selection. Re-derive the selection once the
    /// transition has settled.
    private func scheduleSelectionSync() {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            contactListViewController.updateSelection(for: path.last)
        }
    }

    private func makeScreen(_ destination: AnyHashable) -> UIViewController? {
        guard let destination = destination as? InternalDestination else {
            return nil
        }
        return viewControllerForDestination(destination)
    }
}

// MARK: - PathCoordinator

extension ContactListCoordinator: PathCoordinator {

    /// Derived from the router — there is no separate state to keep in sync.
    var path: [InternalDestination] {
        router.path.compactMap { $0 as? InternalDestination }
    }

    func setPath(_ path: [InternalDestination], animated: Bool) {
        router.setPath(path.map { AnyHashable($0) }, animated: animated)
        // Read back: the router may have truncated the path (e.g. deleted entity).
        contactListViewController.updateSelection(for: self.path.last)
    }
}

// MARK: - NavigationRouterDelegate

extension ContactListCoordinator: NavigationRouterDelegate {

    /// The user popped (back button, swipe, tab re-tap pop-to-root): the path is
    /// already trimmed, only the list highlight needs a refresh.
    func router(_ router: NavigationRouter, didPopTo path: [AnyHashable]) {
        contactListViewController.updateSelection(for: self.path.last)
    }
}

// MARK: - UINavigationControllerDelegate

extension ContactListCoordinator: UINavigationControllerDelegate {

    /// Forwarded by the router (which owns the delegate slot while bound) to keep
    /// the status navigation bar content up to date.
    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        (navigationController as? StatusNavigationController)?.updateNavigationBarContent()
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
            show(.contact(contactEntity.objectID))
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
                    acquaintanceLevel: .direct,
                    workAvailabilityStatus: directoryContact.workAvailabilityStatus
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
                self?.show(.contact(contactEntity.objectID))
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
