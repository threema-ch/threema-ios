/// Handles navigation coordination for posted notification.
///
/// This class observes notifications and routes users to the appropriate
/// screens within the app.

import CocoaLumberjackSwift
import ThreemaFramework
import ThreemaMacros

@MainActor
final class AppCoordinatorNotificationHandler {
    private weak var coordinator: AppCoordinator!
    private let notificationCenter: any NotificationCenterProtocol
    private let mdmSetup: (any MDMSetupProtocol)?
    
    private var observers: [any NSObjectProtocol] = []
    
    private var contactListCoordinator: ContactListCoordinator {
        coordinator.contactListCoordinator
    }
    
    private var conversationListCoordinator: ConversationListCoordinator {
        coordinator.conversationListCoordinator
    }
    
    private var profileCoordinator: ProfileCoordinator {
        coordinator.profileCoordinator
    }
    
    private var splitViewController: ThreemaSplitViewController {
        coordinator.splitViewController
    }
    
    private var tabBarController: ThreemaTabBarController {
        coordinator.tabBarController
    }
    
    init(
        appCoordinator: AppCoordinator,
        notificationCenter: any NotificationCenterProtocol,
        mdmSetup: (any MDMSetupProtocol)?
    ) {
        self.coordinator = appCoordinator
        self.notificationCenter = notificationCenter
        self.mdmSetup = mdmSetup
    }

    deinit {
        observers.forEach { notificationCenter.removeObserver($0) }
        observers.removeAll()
    }

    func stopObserving() {
        observers.forEach { notificationCenter.removeObserver($0) }
        observers.removeAll()
    }

    func startObserving() {
        observeSafeBackUIRefreshNotification()
        
        observeShowConversationNotification()
        
        observeShowContactNotification()
        
        observeShowGroupNotification()
        
        observerShowDistributionListNotification()

        observeShowProfileNotification()
        
        observeDeletedConversationNotification()
        
        observeDeletedContactNotification()
        
        observeSafeSetupUINotification()
        
        observeMemoryWarningNotification()
        
        observeColorThemeChangedNotification()

        observeLicenseMissingNotification()

        observeCompanyMDMSafePasswordCheckNotification()
    }
    
    // MARK: - Private methods
    
    // MARK: Safe Backup UI Refresh
    
    private func observeSafeBackUIRefreshNotification() {
        observers.append(notificationCenter.addObserver(
            forName: Notification.Name(kSafeBackupUIRefresh),
            object: nil,
            queue: .main,
            using: { [weak self] _ in
                Task { @MainActor in
                    self?.handleSafeBackupUIRefreshNotification()
                    self?.handleCompanyMDMSafeEnableCheck()
                }
            }
        ))
    }
    
    private func handleSafeBackupUIRefreshNotification() {
        guard
            mdmSetup?.isSafeBackupDisable() == true,
            profileCoordinator.currentDestination == .backups
        else {
            return
        }
        
        profileCoordinator.popToRoot(animated: false)
    }
    
    // MARK: Company MDM Safe Enable Check

    private func handleCompanyMDMSafeEnableCheck() {
        guard
            AppSetup.isCompleted
        else {
            return
        }
        
        let groupManager = coordinator.appContainer.businessInjector.groupManager
        let safeManager = SafeManager(groupManager: groupManager)

        guard
            mdmSetup?.isSafeBackupDisable() == true,
            safeManager.isActivated
        else {
            return
        }
            
        safeManager.deactivate()
    }
    
    // MARK: Show Conversation Notification
    
    private func observeShowConversationNotification() {
        observers.append(notificationCenter.addObserver(
            forName: Notification.Name(kNotificationShowConversation),
            object: nil,
            queue: .main,
            using: { [weak self] notification in
                Task { @MainActor in
                    self?.handleShowConversationNotification(notification)
                }
            }
        ))
    }
    
    private func handleShowConversationNotification(
        _ notification: Notification
    ) {
        let information = ShowConversationInformation.createInfo(
            for: notification as NSNotification
        )

        guard let information else {
            return
        }
        coordinator.show(conversation: information.conversation, information: information)
    }
    
    // MARK: Show Contact Notification
    
    private func observeShowContactNotification() {
        observers.append(notificationCenter.addObserver(
            forName: Notification.Name(kNotificationShowContact),
            object: nil,
            queue: .main,
            using: { [weak self] notification in
                Task { @MainActor in
                    self?.handleShowContactNotification(notification)
                }
            }
        ))
    }
    
    private func handleShowContactNotification(
        _ notification: Notification
    ) {
        guard let contact = notification.userInfo?[
            kKeyContact
        ] as? ContactEntity else {
            return
        }
        
        coordinator.switchTabIfNeeded(to: .contacts)
        contactListCoordinator.show(.contact(contact.objectID))
    }
    
    // MARK: Show Group Notification
    
    private func observeShowGroupNotification() {
        observers.append(notificationCenter.addObserver(
            forName: Notification.Name(kNotificationShowGroup),
            object: nil,
            queue: .main,
            using: { [weak self] notification in
                Task { @MainActor in
                    self?.handleShowGroupNotification(notification)
                }
            }
        ))
    }
    
    private func handleShowGroupNotification(
        _ notification: Notification
    ) {
        guard let group = notification.userInfo?[
            kKeyGroup
        ] as? Group else {
            return
        }
            
        coordinator.switchTabIfNeeded(to: .contacts)
        contactListCoordinator.show(.group(group.conversationObjectID))
    }
    
    // MARK: Show Distribution List Notification
    
    private func observerShowDistributionListNotification() {
        observers.append(notificationCenter.addObserver(
            forName: Notification.Name(kNotificationShowDistributionList),
            object: nil,
            queue: .main,
            using: { [weak self] notification in
                Task { @MainActor in
                    self?.handleShowDistributionListNotification(notification)
                }
            }
        ))
    }
    
    private func handleShowDistributionListNotification(
        _ notification: Notification
    ) {
        guard let distributionList = notification.userInfo?[
            kKeyDistributionList
        ] as? DistributionListEntity else {
            return
        }
            
        coordinator.switchTabIfNeeded(to: .contacts)
        contactListCoordinator.show(.distributionList(distributionList.objectID))
    }
    
    // MARK: Show Profile Notification

    private func observeShowProfileNotification() {
        observers.append(notificationCenter.addObserver(
            forName: Notification.Name(kNotificationShowProfile),
            object: nil,
            queue: .main,
            using: { [weak self] _ in
                Task { @MainActor in
                    self?.handleShowProfileNotification()
                }
            }
        ))
    }
    
    private func handleShowProfileNotification() {
        coordinator.switchTabIfNeeded(to: .profile)
    }
    
    // MARK: Deleted Conversation Notification
    
    private func observeDeletedConversationNotification() {
        observers.append(notificationCenter.addObserver(
            forName: Notification.Name(kNotificationDeletedConversation),
            object: nil,
            queue: .main,
            using: { [weak self] notification in
                Task { @MainActor in
                    self?.handleDeletedConversationNotification(notification)
                }
            }
        ))
    }
    
    private func handleDeletedConversationNotification(
        _ notification: Notification
    ) {
        let deletedConversation = notification.userInfo?[
            kKeyConversation
        ] as? ConversationEntity
        
        let selectedConversation = conversationListCoordinator.selectedConversation
        
        guard
            splitViewController.isCollapsed == false,
            deletedConversation == selectedConversation,
            tabBarController.selectedThreemaTab == .conversations
        else {
            return
        }
        
        conversationListCoordinator.resetSelection()
    }
    
    // MARK: Deleted Contact Notification
    
    private func observeDeletedContactNotification() {
        observers.append(notificationCenter.addObserver(
            forName: Notification.Name(kNotificationDeletedContact),
            object: nil,
            queue: .main,
            using: { [weak self] notification in
                Task { @MainActor in
                    self?.handleDeletedContactNotification(notification)
                }
            }
        ))
    }
    
    func handleDeletedContactNotification(
        _ notification: Notification
    ) {
        guard
            splitViewController.isCollapsed == false,
            let deletedContact = notification.userInfo?[
                kKeyContact
            ] as? ContactEntity,
            tabBarController.selectedThreemaTab == .contacts
        else {
            return
        }
        
        switch contactListCoordinator.currentDestination {
        case
            let .contact(objectID)? where deletedContact.objectID == objectID,
            let .workContact(objectID)? where deletedContact.objectID == objectID,
            let .group(objectID)? where deletedContact.objectID == objectID,
            let .distributionList(objectID)? where deletedContact.objectID == objectID:
            contactListCoordinator.resetSelection()

        default:
            return
        }
    }
    
    // MARK: Safe Setup UI Notification
    
    private func observeSafeSetupUINotification() {
        observers.append(notificationCenter.addObserver(
            forName: Notification.Name(kSafeSetupUI),
            object: nil,
            queue: .main,
            using: { [weak self] _ in
                Task { @MainActor in
                    self?.handleSafeSetupUINotification()
                }
            }
        ))
    }
    
    private func handleSafeSetupUINotification() {
        coordinator.showThreemaSafe()
    }
    
    // MARK: Memory Warning Notification
    
    private func observeMemoryWarningNotification() {
        observers.append(notificationCenter.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main,
            using: { [weak self] _ in
                DDLogWarn("Received memory warning")
                Task { @MainActor in
                    self?.handleMemoryWarningNotification()
                }
            }
        ))
    }

    private func handleMemoryWarningNotification() {
        // Free the inactive tabs' materialized screens; they are re-created
        // from the tabs' paths on the next activation.
        splitViewController.navigationManager.releaseMaterializedScreens()
    }
    
    // MARK: Color Theme Changed Notification
    
    private func observeColorThemeChangedNotification() {
        observers.append(notificationCenter.addObserver(
            forName: Notification.Name(kNotificationColorThemeChanged),
            object: nil,
            queue: .main,
            using: { [weak self] _ in
                Task { @MainActor in
                    self?.handleColorThemeChangedNotification()
                }
            }
        ))
    }
    
    private func handleColorThemeChangedNotification() {
        DDLogInfo("Color theme changed, removing cached chat view controllers")
        
        SharedAppProvider.window
            .map(Colors.update(window:))

        Colors.update(rootViewController: splitViewController)

        Colors.update(tabBar: tabBarController.tabBar)
                
        splitViewController.setNeedsStatusBarAppearanceUpdate()
    }

    // MARK: License Missing Notification

    private func observeLicenseMissingNotification() {
        observers.append(notificationCenter.addObserver(
            forName: Notification.Name(rawValue: kNotificationLicenseMissing),
            object: nil,
            queue: .main,
            using: { [weak self] notification in
                Task { @MainActor in
                    self?.handleLicenseMissingNotification(notification)
                }
            }
        ))
    }
    
    private func handleLicenseMissingNotification(_ notification: Notification) {
        guard coordinator.appContainer.bootstrap.flavorService.isBusinessApp == true else {
            return
        }
        
        let errorMessage = notification.object as? String
        
        guard let viewController = EnterLicenseViewController.instantiate() else {
            return
        }
        viewController.modalPresentationStyle = .fullScreen
        viewController.delegate = coordinator

        coordinator.appContainer.wcSessionManager.stopAndForgetAllSessions()

        coordinator.dismissModal { [weak self] in
            self?.splitViewController.present(viewController, animated: false) {
                guard let errorMessage else {
                    return
                }
                
                viewController.showErrorMessage(errorMessage)
            }
        }
    }

    // MARK: Company MDM Safe Password Check

    private func observeCompanyMDMSafePasswordCheckNotification() {
        observers.append(notificationCenter.addObserver(
            forName: Notification.Name(kSafeBackupPasswordCheck),
            object: nil,
            queue: .main,
            using: { [weak self] _ in
                Task { @MainActor in
                    self?.handleCompanyMDMSafePasswordCheck()
                }
            }
        ))
    }

    private func handleCompanyMDMSafePasswordCheck() {
        guard
            AppSetup.isCompleted
        else {
            return
        }
        
        let groupManager = coordinator.appContainer.businessInjector.groupManager
        let safeManager = SafeManager(groupManager: groupManager)

        let mdmSafeEnabled = mdmSetup?.safeEnable()?.boolValue ?? false
        let wasSafeActive = safeManager.isActivated || mdmSafeEnabled

        guard
            safeManager.credentialsChanged(),
            wasSafeActive,
            SharedAppProvider.alertViewShown == nil,
            let topViewController = SharedAppProvider.currentTopViewController
        else {
            return
        }
        
        let actionConfirm = UIAlertAction(
            title: #localize("threema_safe_company_mdm_password_changed_accept"),
            style: .default
        ) { [weak self] _ in
            // User has accepted new password, change safe credentials
            safeManager.deactivate()
            safeManager.activateThroughMDM()

            self?.coordinator.showThreemaSafe()

            NotificationPresenterWrapper.shared.present(type: .safePasswordAccepted)
        }

        UIAlertTemplate.showTimedAlert(
            owner: topViewController,
            title: String.localizedStringWithFormat(
                #localize("threema_safe_company_mdm_password_changed_title"),
                TargetManager.localizedAppName
            ),
            message: #localize("threema_safe_company_mdm_password_changed_message"),
            action1: UIAlertAction(title: #localize("cancel"), style: .cancel),
            action2: actionConfirm,
            enableActionsAfter: 5
        )
    }
}
