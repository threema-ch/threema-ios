import CocoaLumberjackSwift
import Coordinator
import Foundation
import SwiftUI
import ThreemaFramework
import ThreemaMacros

final class SettingsCoordinator: NSObject, Coordinator, CurrentDestinationHolderProtocol {
    
    // MARK: - Internal destination
    
    enum InternalDestination: Equatable {
        case betaFeedback
        case developer
        
        case privacy
        case appearance
        case notifications
        case chat
        case media
        case storage
        case passcode
        case calls
        
        case desktop
        case web
        
        case invite(sourceView: UIView)
        case channel
        case workInfo
        case workReferral
        
        case support
        case policy
        case tos
        case license
        case advanced
    }
    
    // MARK: - Coordinator
    
    var childCoordinators: [any Coordinator] = []
    var rootViewController: UIViewController {
        rootNavigationController
    }
    
    // MARK: - Routers
    
    private let shareActivityRouter: any ShareActivityRouterProtocol
    private let passcodeRouter: any PasscodeRouterProtocol
    
    var currentDestination: InternalDestination?
    
    // MARK: - Private properties

    private lazy var settingsStore = BusinessInjector.ui.settingsStore as! SettingsStore
    private(set) weak var presentingViewController: ThreemaSplitViewController?
    
    private lazy var settingsViewController: SettingsViewController = {
        let settingsViewController = SettingsViewController(coordinator: self)
        
        let tab = ThreemaTab(.settings)
        settingsViewController.tabBarItem = tab.tabBarItem
        settingsViewController.title = tab.title
        
        return settingsViewController
    }()
    
    private lazy var rootNavigationController = StatusNavigationController()
        
    private lazy var navigationDestinationResetter = NavigationDestinationResetter(
        rootViewController: settingsViewController,
        splitViewController: presentingViewController,
        destinationHolder: self.eraseToAnyDestinationHolder()
    )
    
    // MARK: - Lifecycle

    init(
        presentingViewController: ThreemaSplitViewController,
        shareActivityRouter: any ShareActivityRouterProtocol,
        passcodeRouter: any PasscodeRouterProtocol
    ) {
        self.presentingViewController = presentingViewController
        self.shareActivityRouter = shareActivityRouter
        self.passcodeRouter = passcodeRouter
    }
    
    // MARK: - Presentation
    
    func start() {
        rootNavigationController.delegate = navigationDestinationResetter
        
        /// Due to this coordinator's rootViewController being part of a
        /// `UITabViewController`, it's not needed to present anything here.
        /// The rootViewController is added by to the `UITabViewController`'s
        /// viewControllers in ``AppCoordinator``'s `configureSplitViewController` method.
        rootNavigationController.setViewControllers(
            [settingsViewController],
            animated: false
        )
    }
    
    func show(_ destination: InternalDestination) {
        guard currentDestination != destination else {
            return
        }
        currentDestination = destination
        
        switch destination {
        case .betaFeedback:
            openBetaFeedbackChat()
            
        case .developer:
            showDeveloperSettings()
            
        case .privacy:
            showPrivacySettings()
            
        case .appearance:
            showAppearanceSettings()
            
        case .notifications:
            showNotificationSettings()
            
        case .chat:
            showChatSettings()
            
        case .media:
            showMediaSettings()
            
        case .storage:
            showStorageSettings()
            
        case .passcode:
            showPasscodeSettings()
            
        case .calls:
            showCallSettings()
            
        case .desktop:
            showDesktopSettings()
            
        case .web:
            showWebSettings()
            
        case let .invite(sourceView):
            showInviteActivity(sourceView: sourceView)
            
        case .channel:
            openChannelChat()
            
        case .workInfo:
            showWorkInfo()
        
        case .workReferral:
            showWorkReferral()
            
        case .support:
            showSupportInfo()
            
        case .policy:
            showPrivacyPolicy()
            
        case .tos:
            showToS()
            
        case .license:
            showLicense()
            
        case .advanced:
            showAdvancedSettings()
        }
        
        settingsViewController.updateSelection()
    }
    
    // MARK: - Private functions
    
    private func openBetaFeedbackChat() {
        let versionText = "Version: \(ThreemaUtility.clientVersionWithMDM)"
        if let contact = BusinessInjector.ui.entityManager.entityFetcher
            .contactEntity(for: Constants.betaFeedbackIdentity) {
            showConversation(for: contact, text: versionText)
        }
        else {
            BusinessInjector.ui.contactStore.addContact(
                with: Constants.betaFeedbackIdentity,
                verificationLevel: Int32(ContactEntity.VerificationLevel.unverified.rawValue)
            ) { contact, _ in
                guard let contactEntity = contact as? ContactEntity else {
                    DDLogError("Can't add \(Constants.betaFeedbackIdentity) as contact")
                    return
                }
                
                self.showConversation(for: contactEntity, text: versionText)
            } onError: { error in
                DDLogError("Can't add \(Constants.betaFeedbackIdentity) as contact \(error)")
            }
        }
    }
    
    private func showDeveloperSettings() {
        let vc = UIHostingController(rootView: DeveloperSettingsView())
        presentingViewController?.show(vc, sender: self)
    }
    
    private func showPrivacySettings() {
        let vc = UIHostingController(rootView: PrivacySettingsView().environmentObject(settingsStore))
        presentingViewController?.show(vc, sender: self)
    }
    
    private func showAppearanceSettings() {
        let vc = UIHostingController(rootView: AppearanceSettingsView())
        presentingViewController?.show(vc, sender: self)
    }
    
    private func showNotificationSettings() {
        let vc = UIHostingController(rootView: NotificationSettingsView().environmentObject(settingsStore))
        presentingViewController?.show(vc, sender: self)
    }
    
    private func showChatSettings() {
        let vc = UIHostingController(rootView: ChatSettingsView().environmentObject(settingsStore))
        presentingViewController?.show(vc, sender: self)
    }
    
    private func showMediaSettings() {
        let vc = UIHostingController(rootView: MediaSettingsView().environmentObject(settingsStore))
        presentingViewController?.show(vc, sender: self)
    }
    
    private func showStorageSettings() {
        let vc =
            UIHostingController(
                rootView: StorageManagementView(model: .init(businessInjector: BusinessInjector.ui))
                    .environmentObject(settingsStore)
            )
        presentingViewController?.show(vc, sender: self)
    }
    
    private func showPasscodeSettings() {
        passcodeRouter.requireAuthenticationIfNeeded(onSuccess: { [weak self] in
            let vc = KKPasscodeSettingsViewController(style: .insetGrouped)
            self?.presentingViewController?.show(vc, sender: self)
        })
    }
    
    private func showCallSettings() {
        let vc = UIHostingController(rootView: CallSettingsView().environmentObject(settingsStore))
        presentingViewController?.show(vc, sender: self)
    }
    
    private func showDesktopSettings() {
        let vc = UIHostingController(rootView: LinkedDevicesView().environmentObject(settingsStore))
        presentingViewController?.show(vc, sender: self)
    }
    
    private func showWebSettings() {
        let vc = UIHostingController(rootView: ThreemaWebSettingsView())
        presentingViewController?.show(vc, sender: self)
    }
    
    private func showWorkInfo() {
        let vc = SettingsWebViewViewController(
            url: ThreemaURLProvider.workInfo,
            title: #localize("settings_threema_work"),
            allowsContentJavaScript: true
        )
        presentingViewController?.show(vc, sender: self)
    }
    
    private func showWorkReferral() {
        let vc = UIHostingController(rootView: WorkReferralView())
        presentingViewController?.show(vc, sender: self)
    }
    
    private func showInviteActivity(sourceView: UIView) {
        let shareText = String.localizedStringWithFormat(
            #localize("invite_sms_body"),
            TargetManager.appName,
            TargetManager.localizedAppName,
            BusinessInjector.ui.myIdentityStore.identity ?? ""
        )
        shareActivityRouter.present(items: [shareText], sourceView: sourceView)
    }
    
    private func openChannelChat() {
        guard TargetManager.isPrivate || TargetManager.isWork else {
            return
        }
        
        let identity = TargetManager.isPrivate ? PredefinedContacts.threema.identity : PredefinedContacts.threemaWork.identity
        
        guard let identity else {
            return
        }
        let businessInjector = BusinessInjector.ui
        let entityManager = businessInjector.entityManager
        let contactEntity = entityManager.performAndWait {
            entityManager.entityFetcher.contactEntity(for: identity.rawValue)
        }
        
        if let contactEntity {
            showConversation(for: contactEntity)
            return
        }
        
        let title = TargetManager.isPrivate ? #localize("threema_channel_intro") : #localize(
            "threema_work_channel_intro"
        )
        let message = TargetManager.isPrivate ? #localize("threema_channel_info") : #localize(
            "threema_work_channel_info"
        )
        
        UIAlertTemplate.showAlert(
            owner: rootViewController,
            title: title,
            message: message,
            titleOk: #localize("add_button"),
            actionOk: { _ in
                addChannel(in: self.rootViewController, identity: identity.rawValue)
            }
        ) { _ in
            self.currentDestination = nil
        }
        
        func addChannel(in viewController: UIViewController, identity: String) {
            ContactStore.shared().addContact(
                with: identity,
                verificationLevel: Int32(ContactEntity.VerificationLevel.unverified.rawValue),
                onCompletion: { contact, _ in
                    guard let contactEntity = contact as? ContactEntity else {
                        let title = TargetManager.isPrivate ? #localize("threema_channel_failed") : #localize(
                            "threema_work_channel_failed"
                        )
                        UIAlertTemplate.showAlert(
                            owner: viewController,
                            title: title,
                            message: nil
                        )
                        return
                    }
                    
                    self.showConversation(for: contactEntity)
                    
                    let initialMessages = createInitialMessages()
                    dispatchInitialMessages(messages: initialMessages, with: contactEntity)
                    
                }, onError: { error in
                    let title = TargetManager.isPrivate ? #localize("threema_channel_failed") : #localize(
                        "threema_work_channel_failed"
                    )
                    UIAlertTemplate.showAlert(
                        owner: viewController,
                        title: title,
                        message: error.localizedDescription
                    )
                }
            )
        }
        
        func createInitialMessages() -> [String] {
            var initialMessages = [String]()
            
            if !(Bundle.main.preferredLocalizations[0].hasPrefix("de")) {
                initialMessages.append("en")
            }
            else {
                initialMessages.append("de")
            }
            
            if TargetManager.isPrivate {
                initialMessages.append("Start News")
            }
            initialMessages.append("Start iOS")
            initialMessages.append("Info")
            
            return initialMessages
        }
            
        func dispatchInitialMessages(messages: [String], with contact: ContactEntity) {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                let businessInjector = BusinessInjector.ui

                guard let conversation = businessInjector.entityManager.entityFetcher
                    .conversationEntity(for: contact.identity) else {
                    DDLogWarn("Unable to add initial messages to Threema Channel. Reason: conversation not found.")
                    return
                }
                
                for (index, message) in messages.enumerated() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(index)) {
                        businessInjector.messageSender.sendTextMessage(
                            containing: message,
                            in: conversation
                        )
                    }
                }
            }
        }
    }
    
    private func showSupportInfo() {
        let vc = SettingsWebViewViewController(
            url: ThreemaURLProvider.supportFAQ,
            title: #localize("settings_list_support_title"),
            allowsContentJavaScript: true
        )
        presentingViewController?.show(vc, sender: self)
    }
    
    private func showPrivacyPolicy() {
        let vc = SettingsWebViewViewController(
            url: ThreemaURLProvider.privacyPolicy,
            title: #localize("settings_list_privacy_policy_title")
        )
        presentingViewController?.show(vc, sender: self)
    }
    
    private func showToS() {
        let vc = SettingsWebViewViewController(
            url: ThreemaURLProvider.termsOfService,
            title: #localize("settings_list_tos_title")
        )
        presentingViewController?.show(vc, sender: self)
    }
    
    private func showLicense() {
        let vc = LicenseViewController()
        presentingViewController?.show(vc, sender: self)
    }
    
    private func showAdvancedSettings() {
        let vc = UIHostingController(rootView: AdvancedSettingsView().environmentObject(settingsStore))
        presentingViewController?.show(vc, sender: self)
    }
    
    // MARK: - Helper functions
    
    private func showConversation(for contact: ContactEntity, text: String? = nil) {
        var info = [
            kKeyContact: contact,
            kKeyForceCompose: NSNumber(booleanLiteral: text != nil),
        ] as [String: Any]
        
        if let text {
            info[kKeyText] = text
        }
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name(rawValue: kNotificationShowConversation),
                object: nil,
                userInfo: info
            )
        }
    }
}
