import CocoaLumberjackSwift
import Coordinator
import Foundation
import SwiftUI
import ThreemaFramework
import ThreemaMacros

final class AppCoordinator: NSObject, Coordinator {
    
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
            conversationListViewControllerFactory: ConversationListViewControllerFactory(
                isRegularSizeClass: { [weak self] in
                    self?.splitViewController.isCollapsed == false
                }(),
                /// Using `UIApplication.shared` here until we have the app state component.
                isLoadedInBackground: UIApplication.shared.applicationState == .background,
                isAppInBackground: UIApplication.shared.applicationState == .background
            ),
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
    
    /// Due to maintaining the two flows while in development,
    /// we need it to be optional, so in the old flow it's nil,
    /// but set on the new flow.
    private var appContainer: AppDependencyContainer?
    
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
    
    convenience init(
        window: UIWindow,
        appContainer: AppDependencyContainer
    ) {
        self.init(window: window)
        self.appContainer = appContainer
        self.businessInjector = appContainer.businessInjector
    }

    func start() {
        configureSplitViewController()
        
        window.rootViewController = splitViewController
        window.makeKeyAndVisible()
        
        if appContainer != nil {
            performPostStartSetup()
        }
        
        observeNotifications()
        
        launchModalManager.checkLaunchModals()
        
        checkForJailBreak()
    }
    
    // MARK: - Post-Start Setup
    
    private func performPostStartSetup() {
        configureThreemaCallSettings()
        updateIdentityInfo()
        connectWCSessions()
        setupConnection()
        acceptPrivacyPolicyIfNeeded()
        resetGallerySettingsIfNeeded()
        performSafeLaunchChecks()
    }
    
    private func configureThreemaCallSettings() {
        let userSettings = businessInjector.userSettings
        if ProcessInfoHelper.isRunningForScreenshots {
            userSettings.enableThreemaCall = true
        }
        else {
            if ThreemaEnvironment.supportsCallKit() == false {
                userSettings.enableThreemaCall = false
            }
        }
    }
    
    private func updateIdentityInfo() {
        let identityStore = businessInjector.myIdentityStore
        
        guard identityStore.identity != nil,
              identityStore.privateIdentityInfoLastUpdate == nil else {
            return
        }
        
        DDLogInfo("Missing private identity info; fetching from server")
        let apiConnector = ServerAPIConnector()
        apiConnector.update(
            identityStore,
            onCompletion: {
                identityStore.privateIdentityInfoLastUpdate = Date()
            },
            onError: { error in
                DDLogError("Private identity info update failed: \(String(describing: error))")
            }
        )
    }
    
    private func connectWCSessions() {
        guard let wcSessionManager = appContainer?.wcSessionManager else {
            return
        }
        
        if wcSessionManager.isRunningWCSession {
            DDLogNotice("[Threema Web] AppCoordinator --> connect all running sessions")
        }
        wcSessionManager.connectAllRunningSessions()
    }
    
    private func setupConnection() {
        let serverConnector = businessInjector.serverConnector
        
        if UIApplication.shared.applicationState != .background {
            serverConnector.isAppInBackground = false
            
            let connectionState = serverConnector.connectionState
            if connectionState == .disconnecting || connectionState == .disconnected {
                serverConnector.connect(initiator: .app, completionHandler: nil)
            }
        }
        
        Task {
            FeatureMask.updateLocal()
        }
        
        // TODO: We should inject this
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(
            options: [.sound, .alert, .badge, .providesAppNotificationSettings]
        ) { granted, error in
            if !granted {
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    serverConnector.removePushToken()
                }
                return
            }
            
            if error == nil {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                
                let provider = NotificationActionProvider()
                let categories = provider.defaultCategories
                center.setNotificationCategories(categories)
            }
        }
    }
    
    private func acceptPrivacyPolicyIfNeeded() {
        // acceptedPrivacyPolicyDate / acceptedPrivacyPolicyVariant are on the
        // concrete UserSettings class, not on UserSettingsProtocol.
        guard let userSettings = businessInjector.userSettings as? UserSettings else {
            return
        }
        
        if userSettings.acceptedPrivacyPolicyDate == nil {
            userSettings.acceptedPrivacyPolicyDate = Date()
            userSettings.acceptedPrivacyPolicyVariant = .update
        }
    }
    
    private func resetGallerySettingsIfNeeded() {
        // openPlusIconInChat is on the concrete UserSettings class,
        // not on UserSettingsProtocol.
        guard let userSettings = businessInjector.userSettings as? UserSettings else {
            return
        }
        
        if userSettings.openPlusIconInChat {
            userSettings.openPlusIconInChat = false
            userSettings.showGalleryPreview = false
        }
    }
    
    private func performSafeLaunchChecks() {
        guard !ProcessInfoHelper.isRunningForScreenshots else {
            return
        }

        let safeManager = SafeManager(groupManager: businessInjector.groupManager)
        safeManager.performThreemaSafeLaunchChecks()
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
        let userSettings = businessInjector.userSettings
        
        let lastLaunchedVersionChanged =
            AppLaunchTasks.lastLaunchedVersionChanged
        
        guard
            lastLaunchedVersionChanged || userSettings.jbDetectionDismissed == false,
            JBDetector().detectJB()
        else {
            return
        }
        
        UIAlertTemplate.showAlert(
            owner: splitViewController,
            title: #localize("alert_jb_detected_title"),
            message: #localize("alert_jb_detected_message"),
            titleOk: #localize("push_reminder_not_now"),
            actionOk: { [userSettings] _ in
                userSettings.jbDetectionDismissed = true
            },
            titleCancel: #localize("Dismiss"),
            actionCancel: nil
        )
    }
}
