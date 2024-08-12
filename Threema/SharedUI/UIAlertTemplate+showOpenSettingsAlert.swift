//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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
import UIKit

// TODO: Move this into `UIAlertTemplate` if no more Objective-C is needed
@objc public enum NoAccessAlertType: Int {
    case camera
    case contacts
    case location
    case preciseLocation
    case microphone
}

extension NoAccessAlertType {
    fileprivate var localizedTitle: String {
        switch self {
        case .camera:
            BundleUtil.localizedString(forKey: "alert_no_access_title_camera")
        case .contacts:
            BundleUtil.localizedString(forKey: "alert_no_access_title_contacts")
        case .location:
            BundleUtil.localizedString(forKey: "alert_no_access_title_location")
        case .preciseLocation:
            BundleUtil.localizedString(forKey: "alert_no_access_title_location_precise")
        case .microphone:
            BundleUtil.localizedString(forKey: "alert_no_access_title_microphone")
        }
    }
    
    fileprivate var localizedMessage: String {
        switch self {
        case .camera:
            BundleUtil.localizedString(forKey: "alert_no_access_message_camera")
        case .contacts:
            BundleUtil.localizedString(forKey: "alert_no_access_message_contacts")
        case .location:
            BundleUtil.localizedString(forKey: "alert_no_access_message_location")
        case .preciseLocation:
            BundleUtil.localizedString(forKey: "alert_no_access_message_location_precise")
        case .microphone:
            BundleUtil.localizedString(forKey: "alert_no_access_message_microphone")
        }
    }
}

// This is in the app targets, because `UIApplication.shared.open(_:)` cannot be called in app extensions
extension UIAlertTemplate {

    /// Shows an alert which informs the user that some access is not granted, and gives them the option to open
    /// settings
    ///
    /// - Parameters:
    ///   - owner: UIViewController to present the alert on
    ///   - noAccessAlertType: Type of missing access
    ///   - openSettingsCompletion: Closure called after settings are opened
    ///   - actionCancel: Closure called when cancel is selected
    public static func showOpenSettingsAlert(
        owner: UIViewController,
        noAccessAlertType: NoAccessAlertType,
        openSettingsCompletion: (() -> Void)? = nil,
        actionCancel: (() -> Void)? = nil
    ) {
        let alert = UIAlertController(
            title: noAccessAlertType.localizedTitle,
            message: noAccessAlertType.localizedMessage,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(
            title: BundleUtil.localizedString(forKey: "alert_no_access_open_settings"),
            style: .default,
            handler: { _ in
                guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
                    DDLogWarn("Unable to get settings URL")
                    return
                }

                UIApplication.shared.open(settingsURL)
                
                openSettingsCompletion?()
            }
        ))

        alert.addAction(UIAlertAction(
            title: BundleUtil.localizedString(forKey: "cancel"),
            style: .cancel,
            handler: { _ in actionCancel?() }
        ))

        owner.present(alert, animated: true)
    }
    
    /// Shows an alert which informs the user that some access is not granted, and gives them the option to open
    /// settings
    ///
    /// - Parameters:
    ///   - owner: UIViewController to present the alert on
    ///   - noAccessAlertType: Type of missing access
    @available(*, deprecated, message: "Only use this from obj-c.")
    @objc public static func showOpenSettingsAlert(
        owner: UIViewController,
        noAccessAlertType: NoAccessAlertType
    ) {
        UIAlertTemplate.showOpenSettingsAlert(
            owner: owner,
            noAccessAlertType: noAccessAlertType,
            openSettingsCompletion: nil,
            actionCancel: nil
        )
    }
}
