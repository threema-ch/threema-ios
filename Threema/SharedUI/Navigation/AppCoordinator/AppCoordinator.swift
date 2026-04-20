import Coordinator
import Foundation
import SwiftUI
import ThreemaMacros

@objc final class AppCoordinator: NSObject, Coordinator {
    
    // MARK: - Coordinator
    
    weak var parentCoordinator: (any Coordinator)?
    var childCoordinators: [any Coordinator] = []
    var rootViewController: UIViewController {
        splitViewController
    }

    private var window: UIWindow
    
    // MARK: - Routers
    
    private lazy var shareActivityRouter: any ShareActivityRouterProtocol = ShareActivityRouter(
        rootViewController: rootViewController
    )
    private lazy var modalRouter: any ModalRouterProtocol = ModalRouter(
        rootViewController: rootViewController
    )
    private lazy var passcodeRouter: any PasscodeRouterProtocol = PasscodeRouter(
        lockScreen: LockScreen(isLockScreenController: false),
        isPasscodeRequired: self.isPasscodeRequired,
        rootViewController: self.rootViewController
    )
    
    // MARK: - Views
    
    private(set) lazy var splitViewController = ThreemaSplitViewController()
    
    /// Once Objective-C is removed, `tabBarController` should be made `private`.
    @objc var tabBarController: ThreemaTabBarController {
        splitViewController.threemaTabBarController
    }
    
    @objc var presentedViewController: UIViewController? {
        splitViewController.presentedViewController
    }
    
    // MARK: - Tabs
    
    private(set) lazy var contactListCoordinator: ContactListCoordinator = {
        let coordinator = ContactListCoordinator(
            presentingViewController: splitViewController,
            businessInjector: businessInjector,
            contactListContainerFactory: ContactListContainerViewControllerFactory(
                businessInjector: businessInjector,
                currentDestinationFetcher: { [weak self] in
                    self?.contactListCoordinator.currentDestination
                }(),
                shouldAllowAutoDeselection: { [weak self] in
                    let traitCollection = self?.rootViewController.traitCollection
                    return traitCollection?.horizontalSizeClass == .compact
                }()
            ),
            viewControllerForItem: { item in
                switch item {
                case .contacts:
                    UIHostingController(rootView: AddContactView())
                case .groups:
                    UINavigationController(rootViewController: SelectContactListViewController(
                        contentSelectionMode: .group(.create(data: .empty))
                    ))
                case .distributionLists:
                    UINavigationController(rootViewController: SelectContactListViewController(
                        contentSelectionMode: .distributionList(.create(data: .empty))
                    ))
                }
            },
            viewControllerForDestination: { [weak self] destination in
                guard let self else {
                    return nil
                }
                
                switch destination {
                case let .contact(objectID: objectID):
                    guard let objectID else {
                        return nil
                    }
                    
                    let em = businessInjector.entityManager
                    let contactEntity = em.performAndWait {
                        em.entityFetcher.existingObject(with: objectID) as? ContactEntity
                    }
                    
                    guard let contactEntity else {
                        return nil
                    }
                    
                    return SingleDetailsViewController(
                        for: Contact(contactEntity: contactEntity),
                        displayStyle: .default
                    )
                case let .groupFromID(objectID):
                    guard let objectID else {
                        return nil
                    }
                    
                    let em = businessInjector.entityManager
                    let conversationEntity = em.performAndWait {
                        em.entityFetcher.existingObject(with: objectID) as? ConversationEntity
                    }
                    
                    guard let conversationEntity,
                          let group = businessInjector.groupManager.getGroup(conversation: conversationEntity) else {
                        return nil
                    }
                    
                    return GroupDetailsViewController(for: group, displayStyle: .default)
                case let .group(group):
                    return GroupDetailsViewController(for: group, displayStyle: .default)
                case let .distributionList(objectID: objectID):
                    guard let objectID else {
                        return nil
                    }
                    
                    let em = businessInjector.entityManager
                    let distributionListEntity = em.performAndWait {
                        em.entityFetcher.existingObject(with: objectID) as? DistributionListEntity
                    }
                    
                    guard let distributionListEntity else {
                        return nil
                    }
                    
                    return DistributionListDetailsViewController(
                        for: DistributionList(distributionListEntity: distributionListEntity),
                        displayStyle: .default
                    )
                case .workContact:
                    return nil
                }
            },
            isWork: TargetManager.isWork
        )
        childCoordinators.append(coordinator)
        coordinator.start()
        return coordinator
    }()
    
    private(set) lazy var conversationListCoordinator: ConversationListCoordinator = {
        let coordinator = ConversationListCoordinator(
            presentingViewController: splitViewController,
            viewControllerForDestination: { destination in
                switch destination {
                case let .conversation(conversation, information),
                     let .archivedConversation(conversation, information):
                    ChatViewController(
                        for: conversation,
                        isRegularSizeClass: { self.splitViewController.isCollapsed == false },
                        initialUnreadCount: self.businessInjector.unreadMessages.totalCount(),
                        showConversationInformation: information
                    )
                case .archivedConversationList:
                    ArchivedConversationListViewController(
                        delegate: self.conversationListCoordinator,
                        isRegularSizeClass: self.splitViewController.isCollapsed == false,
                        didDisappear: { [weak self] in
                            self?.conversationListCoordinator.resetCurrentDestination()
                        }
                    )
                }
            },
            isPasscodeRequired: self.isPasscodeRequired
        )
        childCoordinators.append(coordinator)
        coordinator.start()
        return coordinator
    }()
    
    private(set) lazy var profileCoordinator: ProfileCoordinator = {
        let coordinator = ProfileCoordinator(
            presentingViewController: splitViewController,
            businessInjector: businessInjector,
            shareActivityRouter: shareActivityRouter,
            modalRouter: modalRouter,
            passcodeRouter: passcodeRouter
        )
        childCoordinators.append(coordinator)
        coordinator.start()
        return coordinator
    }()
    
    private lazy var settingsCoordinator: SettingsCoordinator = {
        let coordinator = SettingsCoordinator(
            presentingViewController: splitViewController,
            shareActivityRouter: shareActivityRouter,
            passcodeRouter: passcodeRouter
        )
        childCoordinators.append(coordinator)
        coordinator.start()
        return coordinator
    }()
    
    // MARK: - Properties
    
    private lazy var businessInjector: BusinessInjectorProtocol = BusinessInjector.ui
    private lazy var launchModalManager = LaunchModalManager.shared
    
    // swiftformat:disable:next redundantType
    private lazy var passcodeLock: KKPasscodeLock = KKPasscodeLock.shared()
    private var isPasscodeRequired: Bool {
        passcodeLock.isPasscodeRequired()
    }
    
    private lazy var notificationHandler = AppCoordinatorNotificationHandler(
        appCoordinator: self,
        notificationCenter: NotificationCenter.default,
        mdmSetup: MDMSetup()
    )
    
    // MARK: - Lifecycle

    @objc init(window: UIWindow) {
        self.window = window
        
        super.init()
        
        /// Because this is init from Objective-C,
        /// `start()` method is called upon init.

        start()
    }

    func start() {
        configureSplitViewController()
        
        window.rootViewController = splitViewController
        window.makeKeyAndVisible()
        
        observeNotifications()
        
        launchModalManager.checkLaunchModals()
        
        checkForJailBreak()
    }
    
    @objc func reset() {
        dismissModal { [weak self] in
            self?.tabBarController.viewControllers = []
            self?.splitViewController.viewControllers = []
            self?.window.rootViewController = nil
        }
    }
    
    /// Dismisses `presentedViewController` and switches tab
    func switchTabIfNeeded(to tab: ThreemaTab) {
        dismissModal { [splitViewController] in
            splitViewController.switchTabIfNeeded(to: tab)
        }
    }
    
    // MARK: - Layout management
    
    private func configureSplitViewController() {
        let navigationThreemaLogoViewController = ThreemaLogoViewControllerFactory.threemaLogoNavigationController()
        
        splitViewController.viewControllers = [
            tabBarController,
            navigationThreemaLogoViewController,
        ]
        
        /// For now we keep as is. Ideally, the navigation would already be
        /// part of the rootViewController.
        let viewControllers: [UIViewController] = [
            contactListCoordinator.rootViewController,
            conversationListCoordinator.rootViewController,
            profileCoordinator.rootViewController,
            settingsCoordinator.rootViewController,
        ]
        
        tabBarController.viewControllers = viewControllers
        // We must set the conversations tab as the default. This is because, by default, the selectedIndex is 0, which
        // corresponds to the contact tab.
        switchTabIfNeeded(to: .conversations)
    }

    private func observeNotifications() {
        notificationHandler.startObserving()
    }
    
    @objc func dismissModal(
        animated: Bool = true,
        completion: @escaping () -> Void
    ) {
        guard let presentedViewController = splitViewController.presentedViewController else {
            completion()
            return
        }
        
        if let navigationController = presentedViewController as? UINavigationController {
            dismissNavigationController(
                navigationController,
                animated: animated,
                completion: completion
            )
        }
        else {
            presentedViewController.dismiss(
                animated: animated,
                completion: completion
            )
        }
    }
    
    private func dismissNavigationController(
        _ navigationController: UINavigationController,
        animated: Bool = true,
        completion: @escaping () -> Void
    ) {
        guard let topViewController = navigationController.topViewController else {
            completion()
            return
        }
        
        switch topViewController {
        case is MWPhotoBrowser, is DKAssetGroupDetailVC, is MediaPreviewViewController:
            topViewController.dismiss(
                animated: animated
            ) { [navigationController] in
                navigationController.dismiss(
                    animated: animated,
                    completion: completion
                )
            }
            
        case is SingleDetailsViewController, is GroupDetailsViewController:
            topViewController.dismiss(
                animated: animated,
                completion: completion
            )
            
        default:
            navigationController.dismiss(
                animated: animated,
                completion: completion
            )
        }
    }
    
    // MARK: - Helpers
    
    func showModal(for viewController: UIViewController) {
        modalRouter.present(viewController, animated: true)
    }
    
    func showThreemaSafe() {
        let index = ThreemaTab.profile.rawValue
        tabBarController.selectedIndex = index
        
        profileCoordinator.navigateToThreemaSafe()
    }
    
    @objc func showNotificationSettings() {
        let index = ThreemaTab.settings.rawValue
        tabBarController.selectedIndex = index
        
        settingsCoordinator.show(.notifications)
    }
    
    @objc func canDisplayNotificationToast(for message: BaseMessageEntity) -> Bool {
        guard
            let navigationController = splitViewController.navigationController(
                for: tabBarController.selectedThreemaTab
            ),
            let chatViewController = navigationController.topViewController as? ChatViewController,
            let contact = message.conversation.contact,
            chatViewController.isChat(for: contact)
        else {
            return true
        }
        
        return false
    }
    
    private func checkForJailBreak() {
        let lastLaunchedVersionChanged =
            AppLaunchTasks.lastLaunchedVersionChanged
        let jbDetectionDismissed = UserSettings.shared().jbDetectionDismissed
        
        guard
            lastLaunchedVersionChanged || jbDetectionDismissed == false,
            JBDetector().detectJB()
        else {
            return
        }
        
        UIAlertTemplate.showAlert(
            owner: splitViewController,
            title: #localize("alert_jb_detected_title"),
            message: #localize("alert_jb_detected_message"),
            titleOk: #localize("push_reminder_not_now"),
            actionOk: { _ in
                UserSettings.shared().jbDetectionDismissed = true
            },
            titleCancel: #localize("Dismiss"),
            actionCancel: nil
        )
    }
}
