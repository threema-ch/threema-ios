//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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

/// This class provides the list of available shortcut items.
///
/// To add a new shortcut item, add a new case to the `ActionType` enum.
/// Then add the new case to the `items(for:)` method.
///
@objc class UIApplicationShortcutItemProvider: NSObject {
    
    enum ActionType {
        case newMessage
        case myID
        case scanQrCode
        
        var localizedTitle: String {
            switch self {
            case .newMessage:
                "application_shortcut_item_new_message"
            case .myID:
                "application_shortcut_item_my_id"
            case .scanQrCode:
                "application_shortcut_item_scan_qr_code"
            }
        }
      
        var icon: String {
            switch self {
            case .newMessage:
                "square.and.pencil"
            case .myID:
                "person.crop.rectangle.fill"
            case .scanQrCode:
                "qrcode.viewfinder"
            }
        }
        
        var type: String {
            switch self {
            case .newMessage:
                "ch.threema.newmessage"
            case .myID:
                "ch.threema.myid"
            case .scanQrCode:
                "ch.threema.scanid"
            }
        }
        
        var item: UIApplicationShortcutItem {
            .init(
                type: type,
                localizedTitle: BundleUtil.localizedString(forKey: localizedTitle),
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: icon)
            )
        }
    }
    
    /// This method will return an array of shortcut items that are displayed on the home screen.
    ///
    /// - Parameter mdm: used for dynamic shortcut items
    /// - Returns: an array of shortcut items
    @objc static func items(for mdm: MDMSetup) -> [UIApplicationShortcutItem] {
        var items: [ActionType] = [.newMessage, .myID]

        if !mdm.disableAddContact() {
            items.append(.scanQrCode)
        }
        
        return items.map(\.item)
    }
}
