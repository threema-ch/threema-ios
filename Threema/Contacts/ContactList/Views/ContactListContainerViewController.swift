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

    private var observers: [any NSObjectProtocol] = []

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
        
        /// Needed to make the search bar appear the first time without scrolling
        navigationItem.hidesSearchBarWhenScrolling = false
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        
        /// Resetting to the correct value, since it has already appeared
        navigationItem.hidesSearchBarWhenScrolling = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.searchController = searchController
        contactListSearchResultsController.setSearchController(searchController)

        switchToViewController(at: ContactListFilterItem.contacts.rawValue)
       
        let observer = NotificationCenter.default.addObserver(
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

        observers.append(observer)
    }
    
    // MARK: - Updates
    
    public func updateSelection(for destination: ContactListCoordinator.InternalDestination) {

        // Don't switch the underlying tab when search is active.
        // The search results overlay hides the child VC anyway, and switching it
        // causes a mismatch: when search is dismissed, the wrong list is shown
        // while the header still reflects the pre-search tab.
        guard !searchController.isActive else {
            return
        }

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

        case .group, .groupFromID:
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
