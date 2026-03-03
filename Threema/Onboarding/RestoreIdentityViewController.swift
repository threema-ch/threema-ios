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

import SwiftUI
import ThreemaMacros

extension RestoreIdentityViewController {
    private var topViewController: UIViewController {
        AppDelegate.shared().currentTopViewController() ?? .init()
    }

    private var systemFeedbackManager: SystemFeedbackManagerProtocol {
        SystemFeedbackManager(
            deviceCapabilitiesManager: DeviceCapabilitiesManager(),
            settingsStore: BusinessInjector.ui.settingsStore
        )
    }

    @MainActor @objc func showScannerViewController() {
        let model = QRCodeScannerViewModel(
            mode: .identityBackup,
            audioSessionManager: .null, // BusinessInjector is not available
            systemFeedbackManager: .null, // BusinessInjector is not available
            systemPermissionsManager: SystemPermissionsManager()
        )
        model.onCompletion = { [weak self] result in
            guard let self, case let .plainText(text) = result else {
                return
            }
            topViewController.dismiss(animated: true) { [weak self] in
                self?.backupLabel.isHidden = true
                self?.backupTextView.text = text
            }
        }
        model.onCancel = { [weak self] in
            self?.topViewController.dismiss(animated: true)
        }
        let rootView = QRCodeScannerView(model: model)
        let viewController = UIHostingController(rootView: rootView)
        let nav = PortraitNavigationController(rootViewController: viewController)
        topViewController.present(nav, animated: true)
    }
}
