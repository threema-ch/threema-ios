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

final class SettingsCoordinator: NSObject, Coordinator, CurrentDestinationHolding {
    
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
    
    private let shareActivityRouter: any ShareActivityRouting
    private let passcodeRouter: any PasscodeRouting
    
    var currentDestination: InternalDestination?
    
    // MARK: - Private properties

    private lazy var settingsStore = BusinessInjector.ui.settingsStore as! SettingsStore
    private weak var presentingViewController: UIViewController?
    
    private lazy var settingsViewController: SettingsViewController = {
        let settingsViewController = SettingsViewController(coordinator: self)
        
        let tabBarItem = ThreemaTabBarController.TabBarItem(.settings)
        settingsViewController.tabBarItem = tabBarItem.uiTabBarItem
        settingsViewController.title = tabBarItem.title
        
        return settingsViewController
    }()
    
    private lazy var rootNavigationController = UINavigationController()
        
    private lazy var navigationDestinationResetter = NavigationDestinationResetter(
        rootViewController: settingsViewController,
        destinationHolder: self.eraseToAnyDestinationHolder()
    )
    
    // MARK: - Lifecycle

    init(
        presentingViewController: UIViewController,
        shareActivityRouter: any ShareActivityRouting,
        passcodeRouter: any PasscodeRouting
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
        // TODO: (IOS-5212) Add once conversations coordinator is in
        assertionFailure("Not implemented")
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
        // TODO: (IOS-5212) Add once conversations coordinator is in
        assertionFailure("Not implemented")
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
}
