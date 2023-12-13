//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

import Foundation
import SwiftUI

/// Adapter class to make SwiftUI-Views useable in Obj-C code
@objc class SwiftUIAdapter: NSObject {
    
    @objc static func createDeleteRevokeIdentityView() -> UIViewController {
        let deleteRevokeView = DeleteRevokeInfoView()
        let hostingController = UIHostingController(rootView: deleteRevokeView)
        hostingController.navigationItem.largeTitleDisplayMode = .never
        hostingController.navigationController?.navigationBar.isHidden = true
        hostingController.hidesBottomBarWhenPushed = true
        hostingController.navigationItem.hidesBackButton = true
        hostingController.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        return hostingController
    }
    
    @objc static func createDeleteSummaryView() -> UIViewController {
        let deleteView = DeleteRevokeSummaryView(type: .delete)
        let hostingController = UIHostingController(rootView: deleteView)
        return hostingController
    }

    @objc static func createNotificationSettingsView() -> UIViewController {
        let notificationSettingsView = NotificationSettingsView(settingsVM: SettingsStore())
        let hostingController = UIHostingController(rootView: notificationSettingsView)
        hostingController.navigationItem.largeTitleDisplayMode = .never
        return hostingController
    }
    
    @objc static func createSettingsView() -> UIViewController {
        let settingsView = SettingsView()
        let hostingController = UIHostingController(rootView: settingsView)
        hostingController.navigationItem.largeTitleDisplayMode = .never
        return hostingController
    }
    
    @objc static func createProfileView() -> UIViewController {
        ProfileView().createProfileViewController()
    }
}
