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

import CocoaLumberjackSwift
import SwiftUI
import ThreemaEssentials
import UIKit

extension URLHandler {
    @MainActor
    @objc static func handle(item: UIApplicationShortcutItem) -> Bool {
        if item.type == "ch.threema.newmessage" {
            composeMessage()
            return true
        }
        else if item.type == "ch.threema.myid" {
            guard let tabBar = AppDelegate.getMainTabBarController() else {
                return false
            }
            tabBar.selectedIndex = Int(kMyIdentityTabBarIndex)
            return true
        }
        else if item.type == "ch.threema.scanid" {
            guard let tabBar = AppDelegate.getMainTabBarController() else {
                return false
            }
            if !DeviceCapabilitiesManager().supportsRecordingVideo {
                DDLogVerbose("No Camera available.")
                return false
            }
            if TargetManager.isBusinessApp, MDMSetup()?.disableAddContact() == true {
                DDLogVerbose("Contact scanning is disabled for this business app.")
                return false
            }

            let model = QRCodeScannerViewModel(
                mode: .identity,
                audioSessionManager: AudioSessionManager(),
                systemFeedbackManager: SystemFeedbackManager(
                    deviceCapabilitiesManager: DeviceCapabilitiesManager(),
                    settingsStore: BusinessInjector.ui.settingsStore
                ),
                systemPermissionsManager: SystemPermissionsManager()
            )
            model.onCompletion = { result in
                handleScannerResult(result)
            }
            model.onCancel = {
                tabBar.dismiss(animated: true)
            }
            let rootView = QRCodeScannerView(model: model)
            let viewController = UIHostingController(rootView: rootView)
            let nav = PortraitNavigationController(rootViewController: viewController)
            topViewController.present(nav, animated: true)

            return true
        }
        else {
            return false
        }
    }

    private static func handleScannerResult(_ result: QRCodeScannerViewModel.QRCodeResult) {
        MainActor.assumeIsolated {
            switch result {
            case let .identityContact(identity: id, publicKey: key, expirationDate: date):
                let model = ContactIdentityProcessingViewModel(
                    expectedIdentity: nil,
                    scannedIdentity: id,
                    scannedPublicKey: key,
                    scannedExpirationDate: date,
                    systemFeedbackManager: SystemFeedbackManager(
                        deviceCapabilitiesManager: DeviceCapabilitiesManager(),
                        settingsStore: BusinessInjector.ui.settingsStore
                    )
                )
                model.onCompletion = { verifiedContact in
                    topViewController.dismiss(animated: true) {
                        if let verifiedContact {
                            let name = Notification.Name(kNotificationShowContact)
                            let userInfo = [kKeyContact: verifiedContact]
                            NotificationCenter.default.post(name: name, object: nil, userInfo: userInfo)
                        }
                    }
                }
                let rootView = ContactIdentityProcessingView(model: model)
                let viewController = UIHostingController(rootView: rootView)
                (topViewController as? UINavigationController)?.pushViewController(viewController, animated: true)

            case let .identityLink(url: url):
                topViewController.dismiss(animated: true) {
                    handleThreemaDotIDURL(url, hideAppChooser: true)
                }

            default:
                break
            }
        }
    }

    static func composeMessage() {
        ShareController().startShare()
    }

    private static var topViewController: UIViewController {
        AppDelegate.shared().currentTopViewController() ?? .init()
    }
}
