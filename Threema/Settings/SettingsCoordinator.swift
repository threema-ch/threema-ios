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

final class SettingsCoordinator: NSObject, Coordinator {
    
    // MARK: - Internal destination
    
    typealias CoordinatorDestination = InternalDestination
    
    enum InternalDestination: Equatable {
        case betaFeedback
        case developer
        
        case privacy
        case appearance
        case noftifications
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
        
        case support
        case policy
        case tos
        case license
        case advanced
    }
    
    // MARK: - Coordinator
    
    weak var parentCoordinator: (any Coordinator)?
    var childCoordinators: [any Coordinator] = []
    
    private(set) var currentDestination: InternalDestination?
    
    private lazy var rootVC = SettingsViewController(coordinator: self)
    
    // MARK: - Public properties
    
    var horizontalSizeClass: UIUserInterfaceSizeClass = .unspecified {
        didSet {
            guard oldValue != horizontalSizeClass else {
                return
            }
            horizontalSizeClassDidChange()
        }
    }
    
    // MARK: - Private properties

    private lazy var settingsStore = BusinessInjector.ui.settingsStore as! SettingsStore
    
    // MARK: - Lifecycle

    init(parentCoodinator: any Coordinator) {
        self.parentCoordinator = parentCoodinator
    }
    
    func rootViewController() -> UIViewController {
        rootVC
    }
    
    // MARK: - Updates

    func checkDetailVC() {
        guard horizontalSizeClass == .regular else {
            return
        }
        
        show(currentDestination ?? .privacy)
    }
    
    private func horizontalSizeClassDidChange() {
        rootVC.updateSelection()
    }
    
    // MARK: - Presentation
    
    func show(_ destination: Destination) {
        parentCoordinator?.show(destination)
    }
    
    func show(_ destination: Destination.AppDestination.SettingsDestination) { }
    
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
            
        case .noftifications:
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
        
        rootVC.updateSelection()
    }
    
    func show(_ viewController: UIViewController, style: CordinatorNavigationStyle) {
        parentCoordinator?.show(viewController, style: style)
    }
    
    func shareActivity(_ items: [Any], sourceView: UIView?) {
        parentCoordinator?.shareActivity(items, sourceView: sourceView)
    }
    
    func dismiss() {
        parentCoordinator?.dismiss()
    }
    
    // MARK: - Private functions
    
    private func openBetaFeedbackChat() {
        // TODO: (IOS-5212) Add once conversations coordinator is in
        assertionFailure("Not implemented")
    }
    
    private func showDeveloperSettings() {
        let vc = UIHostingController(rootView: DeveloperSettingsView())
        show(vc)
    }
    
    private func showPrivacySettings() {
        let vc = UIHostingController(rootView: PrivacySettingsView().environmentObject(settingsStore))
        show(vc)
    }
    
    private func showAppearanceSettings() {
        let vc = UIStoryboard(name: "SettingsStoryboard", bundle: nil)
            .instantiateViewController(identifier: "AppearanceSettingsViewController")
        show(vc)
    }
    
    private func showNotificationSettings() {
        let vc = UIHostingController(rootView: NotificationSettingsView().environmentObject(settingsStore))
        show(vc)
    }
    
    private func showChatSettings() {
        let vc = UIHostingController(rootView: ChatSettingsView().environmentObject(settingsStore))
        show(vc)
    }
    
    private func showMediaSettings() {
        let vc = UIHostingController(rootView: MediaSettingsView().environmentObject(settingsStore))
        show(vc)
    }
    
    private func showStorageSettings() {
        let vc =
            UIHostingController(
                rootView: StorageManagementView(model: .init(businessInjector: BusinessInjector.ui))
                    .environmentObject(settingsStore)
            )
        show(vc)
    }
    
    private func showPasscodeSettings() {
        let vc = KKPasscodeSettingsViewController(style: .insetGrouped)
        show(vc, style: .passcode(style: .show))
    }
    
    private func showCallSettings() {
        let vc = UIHostingController(rootView: CallSettingsView().environmentObject(settingsStore))
        show(vc)
    }
    
    private func showDesktopSettings() {
        let vc = UIHostingController(rootView: LinkedDevicesView().environmentObject(settingsStore))
        show(vc)
    }
    
    private func showWebSettings() {
        let vc = UIStoryboard(name: "SettingsStoryboard", bundle: nil)
            .instantiateViewController(identifier: "ThreemaWeb")
        show(vc)
    }
    
    private func showWorkInfo() {
        let vc = SettingsWebViewViewController(
            url: ThreemaURLProvider.workInfo,
            title: #localize("settings_threema_work"),
            allowsContentJavaScript: true
        )
        show(vc)
    }
    
    private func showInviteActivity(sourceView: UIView) {
        let shareText = String.localizedStringWithFormat(
            #localize("invite_sms_body"),
            TargetManager.appName,
            TargetManager.localizedAppName,
            BusinessInjector.ui.myIdentityStore.identity ?? ""
        )
        shareActivity([shareText], sourceView: sourceView)
    }
    
    private func openChannelChat() {
        // TODO: (IOS-5212) Add once conversations coordinator is in
        assertionFailure("Not implemented")
    }
    
    private func showSupportInfo() {
        let vc = SettingsWebViewViewController(
            url: ThreemaURLProvider.supportFaq(),
            title: #localize("settings_list_support_title"),
            allowsContentJavaScript: true
        )
        show(vc)
    }
    
    private func showPrivacyPolicy() {
        let vc = SettingsWebViewViewController(
            url: ThreemaURLProvider.privacyPolicy,
            title: #localize("settings_list_privacy_policy_title")
        )
        show(vc)
    }
    
    private func showToS() {
        let vc = SettingsWebViewViewController(
            url: ThreemaURLProvider.termsOfService,
            title: #localize("settings_list_tos_title")
        )
        show(vc)
    }
    
    private func showLicense() {
        let vc = LicenseViewController()
        show(vc)
    }
    
    private func showAdvancedSettings() {
        let vc = UIHostingController(rootView: AdvancedSettingsView().environmentObject(settingsStore))
        show(vc)
    }
}

// MARK: - UINavigationControllerDelegate

extension SettingsCoordinator: UINavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        // If we navigate back to the rootVC, we reset the destination
        if navigationController.topViewController == rootVC, horizontalSizeClass == .compact {
            currentDestination = nil
        }
    }
}
