import CocoaLumberjackSwift
import Coordinator
import Foundation
import Keychain
import SwiftUI
import ThreemaFramework
import ThreemaMacros
import UserNotifications

// NSObject is still needed for `EnterLicenseDelegate` conformance
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
    var tabBarController: ThreemaTabBarController {
        splitViewController.threemaTabBarController
    }
    
    private var presentedViewController: UIViewController? {
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
                case let .contact(objectID):
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
                case let .group(objectID):
                    let em = businessInjector.entityManager
                    let conversationEntity = em.performAndWait {
                        em.entityFetcher.existingObject(with: objectID) as? ConversationEntity
                    }

                    guard let conversationEntity,
                          let group = businessInjector.groupManager.getGroup(conversation: conversationEntity) else {
                        return nil
                    }

                    return GroupDetailsViewController(for: group, displayStyle: .default)
                case let .distributionList(objectID):
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
            viewControllerForDestination: { [weak self] destination, information in
                guard let self else {
                    return nil
                }

                switch destination {
                case let .conversation(objectID):
                    let em = businessInjector.entityManager
                    let conversation = em.performAndWait {
                        em.entityFetcher.existingObject(with: objectID) as? ConversationEntity
                    }

                    guard let conversation else {
                        return nil
                    }

                    let chatVC = ChatViewController(
                        for: conversation,
                        isRegularSizeClass: { [weak self] in self?.splitViewController.isCollapsed == false },
                        initialUnreadCount: businessInjector.unreadMessages.totalCount(),
                        showConversationInformation: information
                    )
                    chatVC.conversationDeletedDelegate = self.conversationListCoordinator
                    return chatVC
                case .archivedConversationList:
                    return ArchivedConversationListViewController(
                        delegate: conversationListCoordinator,
                        isRegularSizeClass: splitViewController.isCollapsed == false,
                        // Pops are reconciled by the coordinator's NavigationRouter;
                        // nothing to reset here anymore.
                        didDisappear: { }
                    )
                }
            },
            isPasscodeRequired: self.isPasscodeRequired
        )
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
        return coordinator
    }()
    
    private lazy var settingsCoordinator: SettingsCoordinator = {
        let coordinator = SettingsCoordinator(
            presentingViewController: splitViewController,
            shareActivityRouter: shareActivityRouter,
            passcodeRouter: passcodeRouter
        )
        return coordinator
    }()
    
    // MARK: - Properties
    
    public let appContainer: AppDependencyContainer
    
    private let businessInjector: BusinessInjectorProtocol
    private let backupFilesManager: any BackupFilesManagerProtocol
    private let launchModalManager: any LaunchModalManagerProtocol

    private var isPasscodeRequired: Bool {
        appContainer.passcodeLock.isPasscodeRequired()
    }
    
    private lazy var notificationHandler = AppCoordinatorNotificationHandler(
        appCoordinator: self,
        notificationCenter: NotificationCenter.default,
        mdmSetup: MDMSetup()
    )
    
    // MARK: - Lifecycle
    
    init(
        window: UIWindow,
        appContainer: AppDependencyContainer,
        launchModalManager: any LaunchModalManagerProtocol,
        backupFilesManager: any BackupFilesManagerProtocol = BackupFilesManager()
    ) {
        self.window = window
        self.appContainer = appContainer
        self.businessInjector = appContainer.businessInjector
        self.launchModalManager = launchModalManager
        self.backupFilesManager = backupFilesManager

        super.init()
    }

    func start() {
        configureSplitViewController()

        window.rootViewController = splitViewController
        // Anchor the theme override on the root view controller as well as the window, so iPadOS tab-switch
        // transitions (rendered outside the window's trait environment) resolve the app theme instead of the
        // system appearance. See `Colors.update(rootViewController:)`.
        Colors.update(rootViewController: splitViewController)
        window.makeKeyAndVisible()

        performPostStartSetup()

        observeNotifications()

        launchModalManager.checkLaunchModals()

        checkForJailBreak()
    }
    
    func willEnterForeground() {
        
        // Take over as the active process. This also clears a stale "notification
        // extension active" flag (extension killed mid-processing), which otherwise
        // makes `ServerConnector.connect` back off and retry forever.
        AppGroup.setMeActiveUnlessIPC(userSettings: businessInjector.userSettings)

        let serverConnector = businessInjector.serverConnector
        serverConnector.isAppInBackground = false

        // Cancel the disconnect task scheduled on backgrounding (see
        // `handleSceneDidEnterBackground`). We're returning to the foreground and want to
        // keep the connection, so its scheduled teardown must not fire.
        // `SceneDelegate.isAppInBackground` is already false at this point, so ending the
        // task won't disconnect (see `BackgroundTaskManager.endBackgroundTaskWithDisconnect`).
        appContainer.backgroundTaskManager.cancelBackgroundTask(key: kAppClosedByUserBackgroundTask)

        // Resume any running Threema Web sessions (reconnects `.threemaWeb`), same as the
        // pre-coordinator `applicationWillEnterForeground`. Must run on every foreground,
        // not just launch, so a session paused on backgrounding comes back.
        connectWCSessions()

        // Always register the initiator, the connection state is handled in `ServerConnector`
        serverConnector.connect(initiator: .app, completionHandler: nil)

        // Refresh the local feature mask, e.g. a contact may have enabled a feature while we
        // were backgrounded.
        FeatureMask.updateLocal()
        
        appContainer.notificationPresenter.dismissAllPresentedNotifications()

        let globalGroupCallManager = appContainer.globalGroupCallManager
        Task {
            await globalGroupCallManager.handleAppWillEnterForeground()
            // Reload persisted group calls: the notification extension may have written new
            // group call entities to the DB while we were backgrounded/suspended, and the
            // singleton otherwise only loads from the DB once at its init.
            await globalGroupCallManager.loadCallsFromDB()
        }
    }
    
    func didBecomeActive() {
        appContainer.userNotificationCenter.removeAllDeliveredNotifications()
        
        appContainer.businessInjector.contactStore.synchronizeAddressBook(
            forceFullSync: false,
            ignoreMinimumInterval: false,
            onCompletion: nil,
            onError: nil
        )
        
        Task {
            try? await appContainer.businessInjector.workDataFetcher.checkUpdateWorkData(
                force: false,
                forceSendMDM: false
            )
        }
        
        GatewayProfilePictureManager().refresh()
        
        appContainer.safeManager.initTrigger()
        
        // Clean PushImages directory
        if let cachesDir = appContainer.fileUtility.appCachesDirectory {
            let pushImagesPath = cachesDir.appendingPathComponent("PushImages").path
            try? appContainer.fileUtility.delete(atPath: pushImagesPath)
        }
    }
    
    // MARK: - Post-Start Setup
    
    private func performPostStartSetup() {
        runCleanupTasks()
        initializeServices()
        applyMDMSettings()
        configureThreemaCallSettings()
        updateIdentityInfo()
        connectWCSessions()
        
        do {
            try reloadIdentityFromKeychain()
        }
        catch {
            assertionFailure("We should never end up here, identity should be set up at this point")

            // TODO: We need to revisit if this is the correct place for it.
            if KeychainManager.isKeychainLocked {
                NotificationManager.showNoAccessToDatabaseNotification(completionHandler: {
                    exit(EXIT_SUCCESS)
                })
            }
            else {
                ErrorHandler.abort(with: error)
            }
        }
        
        setupConnection()
        acceptPrivacyPolicyIfNeeded()
        resetGallerySettingsIfNeeded()
        performSafeLaunchChecks()
    }

    private func applyMDMSettings() {
        let mdmSetup = MDMSetup()
        mdmSetup?.applyCompanyMDMWithCachedThreemaMDM(sendForce: false)

        // Delete Threema-ID-Backup when backup is blocked from MDM
        if mdmSetup?.disableBackups() ?? false
            || mdmSetup?.disableIDExport() ?? false
            || mdmSetup?.disableSystemBackups() ?? false {
            do {
                try IdentityBackupStore.deleteIdentityBackup()
            }
            catch {
                appContainer.notificationPresenter.present(type: .deleteIdentityBackupFailed)
            }
        }

        // Prevent or release iOS iCloud backup
        backupFilesManager.setIsExcludedFromBackup(
            exclude: mdmSetup?.disableBackups() ?? false || mdmSetup?.disableSystemBackups() ?? false
        )

        // Make sure private key is this device only
        if mdmSetup?.disableIOSSystemBackupsIDKeyInclusion() ?? false
            || mdmSetup?.disableBackups() ?? false
            || mdmSetup?.disableSystemBackups() ?? false {
            changeIdentityAccessibility(thisDeviceOnly: true)
        }
        else if mdmSetup?.existsMdmKey(MDM_KEY_DISABLE_IOS_SYSTEM_BACKUPS_ID_KEY_INCLUSION) ?? false,
                !(mdmSetup?.disableIOSSystemBackupsIDKeyInclusion() ?? false) {
            changeIdentityAccessibility(thisDeviceOnly: false)
        }
    }
    
    private func changeIdentityAccessibility(thisDeviceOnly: Bool) {
        let keychainManager = appContainer.keychainManager
        
        do {
            try keychainManager.changeIdentityAccessibility(thisDeviceOnly: thisDeviceOnly)
        }
        catch {
            DDLogError("Failed to change identity accessibility to this device only (\(thisDeviceOnly)): \(error)")
        }
    }
    
    private func runCleanupTasks() {
        appContainer.fileUtility.cleanTemporaryDirectory()
        CallHistoryManager.removeCallsOlderThanChatServerTimeout(businessInjector: appContainer.businessInjector)
    }

    private func initializeServices() {
        // Off the main thread: this checks every pending user notification against
        // the notification center with synchronous waits. On a cold start from a
        // push tap, pending records exist and the response delivery is still open,
        // so waiting here on the main thread freezes the app before the first
        // frame of the UI is ever rendered (stuck on the launch screen).
        let incomingMessageManager = appContainer.incomingMessageManager
        DispatchQueue.global(qos: .utility).async {
            incomingMessageManager.showIsNotPending()
        }

        appContainer.passcodeLock.setDefaultSettings()
        appContainer.passcodeLock.upgradeAccessibility()
        appContainer.passcodeLock.attemptsAllowed = 10

        appContainer.typingIndicatorManager.startObserving()

        IdentityBackupStore.syncKeychainWithFile()
        TipKitManager.configureTips()
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
        let wcSessionManager = appContainer.wcSessionManager
        
        if wcSessionManager.isRunningWCSession {
            DDLogNotice("[Threema Web] AppCoordinator --> connect all running sessions")
        }
        wcSessionManager.connectAllRunningSessions()
    }
    
    /// Reloads the complete identity from keychain into the shared MyIdentityStore
    /// singleton. Ensures clientKey/publicKey/serverGroup are all populated before
    /// ServerConnector.connect runs. Centralizes the identity setup so both onboarding
    /// and existing-user paths hit it exactly once.
    private func reloadIdentityFromKeychain() throws {
        try MyIdentityStoreHelper.reloadIdentity(from: appContainer.keychainManager)
    }
    
    func setupConnection() {
        let serverConnector = businessInjector.serverConnector

        if UIApplication.shared.applicationState != .background {
            // Clear stale extension "active" flags before connecting (an extension
            // killed mid-processing leaves its flag set, and `ServerConnector.connect`
            // then backs off and retries forever — the app never gets past
            // "connecting" after a cold start).
            AppGroup.setMeActiveUnlessIPC(userSettings: businessInjector.userSettings)

            serverConnector.isAppInBackground = false

            // Always register the initiator, the connection state is handled in `ServerConnector`
            serverConnector.connect(initiator: .app, completionHandler: nil)
        }

        Task {
            FeatureMask.updateLocal()
        }
        
        let center = appContainer.userNotificationCenter
        center.requestAuthorization(
            options: [.sound, .alert, .badge, .providesAppNotificationSettings]
        ) { granted, _ in
            guard !granted else {
                return
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                serverConnector.removePushToken()
            }
        }
    }
    
    // MARK: - Scene lifecycle (connection)

    /// Counterpart of the pre-coordinator `applicationDidEnterBackground` connection
    /// teardown: schedule a background task whose expiry disconnects from the chat
    /// server (see `BackgroundTaskManager`). Without the disconnect the server keeps
    /// treating the suspended app as the connected client and the notification
    /// extension refuses to take over - pushes are never delivered while the app is in
    /// the background.
    func handleSceneDidEnterBackground() {
        businessInjector.serverConnector.isAppInBackground = true

        // Safety net: a registered initiator without an active call would prevent every disconnect of the app
        if !appContainer.voIPCallStateManager.currentCallState().active {
            businessInjector.serverConnector.disconnect(initiator: .threemaCall)
        }

        Task {
            await appContainer.globalGroupCallManager.handleAppDidEnterBackground()
        }

        // Always schedule a `kAppClosedByUserBackgroundTask`. Its expiry releases *only*
        // the `.app` connection initiator (see `BackgroundTaskManager`). The chat
        // server / mediator socket is reference-counted by initiator in `ServerConnector`,
        // so it stays up while any other reason to be connected is still active — an
        // ongoing call (`.threemaCall`), a Threema Web session (`.threemaWeb`) or a
        // notification reply (`.notificationHandler`), each of which owns its own
        // background task and releases its own initiator on expiry. Only once *all*
        // execution-extension tasks have expired does the socket actually close, letting
        // the notification extension take over push processing.
        //
        // Only the timeout varies with what else is in flight; the key is always
        // `kAppClosedByUserBackgroundTask` because the app was sent to the background
        // (matching the pre-coordinator `applicationDidEnterBackground`).
        let timeout: Int =
            if appContainer.voIPCallStateManager.currentCallState().active {
                // A call is active: its VoIP background tasks keep the socket alive via the
                // `.threemaCall` initiator until the call ends. We still schedule the `.app`
                // release (with the longer call timeout) — otherwise `.app` would linger and
                // the socket would never close after the call, so pushes would stop arriving
                // while backgrounded.
                Int(kAppVoIPIncomingCallBackgroundTaskTime)
            }
            else if appContainer.wcSessionManager.isRunningWCSession {
                // A Threema Web session is running: grant the longer Web timeout so app and
                // Web keep syncing for as long as we have background execution time. When
                // the task ends, the sessions are paused and `.threemaWeb` is released
                // together with `.app` (see `BackgroundTaskManager`).
                Int(kAppWCBackgroundTaskTime)
            }
            else if appContainer.blobManager.hasActiveSyncs() || !TaskManager.isEmpty() {
                // Outgoing work is still in flight: active blob syncs or a non-empty task
                // queue. Unlike calls, Web, Safe backups and notification replies — each of
                // which starts its own background task when that work begins — the generic
                // outgoing queue has no task of its own, so backgrounding is the only point
                // where it can request extra execution time. Grant the longer sending timeout
                // so the queue can flush before we release `.app`.
                Int(kAppSendingBackgroundTaskTime)
            }
            else {
                Int(kAppClosedByUserBackgroundTaskTime)
            }

        appContainer.backgroundTaskManager.newBackgroundTask(
            key: kAppClosedByUserBackgroundTask,
            timeout: timeout,
            completionHandler: nil
        )
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

        appContainer.safeManager.performThreemaSafeLaunchChecks()
    }
    
    func reset() {
        DDLogNotice("[AppCoordinator] Reset called")
        dismissModal { [weak self] in
            guard let self else {
                return
            }

            // Tear down the coordinator tree (stops observers, unbinds routers)
            // before dropping the view hierarchy, so no stale instance keeps
            // reacting to navigation notifications afterwards.
            finish()

            tabBarController.viewControllers = []
            splitViewController.reset()
            window.rootViewController = nil
        }
    }
    
    func show(
        conversation: ConversationEntity,
        information: ShowConversationInformation? = nil
    ) {
        let info = information ?? ShowConversationInformation(conversation: conversation)
        // Navigate only once a presented modal (e.g. a launch modal) is fully
        // dismissed — a path change during the dismissal transition would be
        // deferred by the router behind a transition that produces no navigation
        // callbacks. Same structure as `navigate(to:)`.
        dismissModal { [weak self] in
            guard let self else {
                return
            }
            splitViewController.switchTabIfNeeded(to: .conversations)
            conversationListCoordinator.show(conversation: conversation, information: info)
        }
    }

    /// Dismisses `presentedViewController` and switches tab
    func switchTabIfNeeded(to tab: ThreemaTab) {
        dismissModal { [splitViewController] in
            splitViewController.switchTabIfNeeded(to: tab)
        }
    }

    /// Typed cross-surface navigation: switch tab and replace its navigation
    /// stack in one call. This is the replacement for navigation via
    /// `NotificationCenter` posts — new code should call this directly.
    func navigate(to destination: Destination) {
        switch destination {
        case let .app(tab, path):
            dismissModal { [weak self] in
                guard let self else {
                    return
                }

                splitViewController.switchTabIfNeeded(to: ThreemaTab(tab))

                switch tab {
                case .contacts:
                    contactListCoordinator.setPath(
                        path.compactMap { $0 as? ContactListCoordinator.InternalDestination },
                        animated: true
                    )
                case .conversations:
                    conversationListCoordinator.setPath(
                        path.compactMap { $0 as? ConversationListCoordinator.InternalDestination },
                        animated: true
                    )
                case .profile:
                    profileCoordinator.setPath(
                        path.compactMap { $0 as? ProfileCoordinator.InternalDestination },
                        animated: true
                    )
                case .settings:
                    settingsCoordinator.setPath(
                        path.compactMap { $0 as? SettingsCoordinator.InternalDestination },
                        animated: true
                    )
                }
            }
        }
    }
    
    // MARK: - Layout management
    
    private func configureSplitViewController() {
        let navigationThreemaLogoViewController = ThreemaLogoViewControllerFactory.threemaLogoNavigationController()

        // The tab bar container's column placement is owned by `ThreemaSplitViewController`: it is installed in
        // the `.compact` column in `init()` (required so the split view collapses on compact width on first
        // launch) and moved to `.primary` for regular widths by `placeTabBarContainer(forCompact:)`. Setting
        // `.primary` here would pull the same instance back out of the `.compact` column — this runs after the
        // window is already key and visible — and reintroduce the empty-logo-on-launch bug.
        splitViewController.setViewController(
            navigationThreemaLogoViewController,
            for: .secondary
        )
        
        /// Create and start the tab coordinators explicitly — a lazy accessor with
        /// side effects would hide the ordering and allow accidental re-starts.
        let tabCoordinators: [any Coordinator] = [
            contactListCoordinator,
            conversationListCoordinator,
            profileCoordinator,
            settingsCoordinator,
        ]

        for coordinator in tabCoordinators {
            childCoordinators.append(coordinator)
            coordinator.start()
        }

        /// For now we keep as is. Ideally, the navigation would already be
        /// part of the rootViewController.
        let viewControllers: [UIViewController] = [
            contactListCoordinator.rootViewController,
            conversationListCoordinator.rootViewController,
            profileCoordinator.rootViewController,
            settingsCoordinator.rootViewController,
        ]
        
        tabBarController.viewControllers = viewControllers

        let navigationManager = splitViewController.navigationManager
        navigationManager.registerRouterManagedTab(
            .contacts,
            handle: contactListCoordinator.routerHandle
        )
        navigationManager.registerRouterManagedTab(
            .conversations,
            handle: conversationListCoordinator.routerHandle
        )
        navigationManager.registerRouterManagedTab(
            .profile,
            handle: profileCoordinator.routerHandle
        )
        navigationManager.registerRouterManagedTab(
            .settings,
            handle: settingsCoordinator.routerHandle
        )

        // We must set the conversations tab as the default. This is because, by default, the selectedIndex is 0, which
        // corresponds to the contact tab.
        switchTabIfNeeded(to: .conversations)
    }

    private func observeNotifications() {
        notificationHandler.startObserving()
    }

    /// Tears this coordinator down so it can be discarded by its parent.
    ///
    /// A `RootCoordinator` may create a new `AppCoordinator` after this one (e.g. ID erase →
    /// onboarding → relaunch). This instance must stop observing notifications before that
    /// happens, otherwise both instances react to posted navigation notifications and the
    /// stale one operates on a detached view hierarchy.
    func finish() {
        notificationHandler.stopObserving()
        for child in childCoordinators {
            child.finish()
        }
        childCoordinators.removeAll()
    }
    
    func dismissModal(
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
        // Go through the split view controller so the profile tab's router is
        // activated by the store/restore cycle (a raw selectedIndex change is not).
        splitViewController.switchTabIfNeeded(to: .profile)

        profileCoordinator.navigateToThreemaSafe()
    }
    
    func showNotificationSettings() {
        // Go through the split view controller so the settings tab's router is
        // activated by the store/restore cycle (a raw selectedIndex change is not).
        splitViewController.switchTabIfNeeded(to: .settings)
        
        settingsCoordinator.show(.notifications)
    }
    
    func canDisplayNotificationToast(for message: BaseMessageEntity) -> Bool {
        guard
            let navigationController = splitViewController.navigationController(
                for: tabBarController.selectedThreemaTab
            ),
            let chatViewController = navigationController.topViewController as? ChatViewController,
            chatViewController.isDisplayingChat(for: message.conversation)
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
            titleCancel: #localize("dismiss"),
            actionCancel: nil
        )
    }
}

// MARK: - EnterLicenseDelegate

extension AppCoordinator: EnterLicenseDelegate {
    func licenseConfirmed() {
        splitViewController.dismiss(animated: true) { [weak self] in
            guard let self else {
                return
            }
            let serverConnector = businessInjector.serverConnector
            serverConnector.isAppInBackground = SceneDelegate.isAppInBackground
            serverConnector.connect(initiator: .app, completionHandler: nil)
        }
    }
}
