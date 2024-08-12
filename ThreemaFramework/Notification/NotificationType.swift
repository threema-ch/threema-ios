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

import CocoaLumberjackSwift
import Foundation

public enum NotificationType: Equatable, CaseIterable, Hashable {
   
    // We only show the nickname
    case restrictive
    // We show the display name
    case balanced
    // We show the display name and show a rich notification
    case complete
     
    // Used to save to user defaults
    var userSettingsValue: Int {
        switch self {
        case .restrictive:
            0
        case .balanced:
            1
        case .complete:
            2
        }
    }
    
    public static func type(for number: NSNumber) -> NotificationType {
        switch number {
        case 0:
            return .restrictive
        case 1:
            return .balanced
        case 2:
            return .complete
        default:
            DDLogError("NotificationType was higher than 2, will use case .restrictive.")
            return .restrictive
        }
    }

    // MARK: - Preview
    
    public var previewTitle: String {
        switch self {
        case .restrictive:
            BundleUtil.localizedString(forKey: "settings_notification_type_preview_restrictive_title")
        case .balanced:
            BundleUtil.localizedString(forKey: "settings_notification_type_preview_balanced_title")
        case .complete:
            BundleUtil.localizedString(forKey: "settings_notification_type_preview_complete_title")
        }
    }
    
    public var previewDescription: String {
        switch self {
        case .restrictive:
            return BundleUtil.localizedString(forKey: "settings_notification_type_preview_restrictive_description")
        case .balanced:
            return BundleUtil.localizedString(forKey: "settings_notification_type_preview_balanced_description")
        case .complete:
            let faqURLString = BundleUtil.object(forInfoDictionaryKey: "ThreemaNotificationInfo") as! String
            return String.localizedStringWithFormat(
                BundleUtil.localizedString(forKey: "settings_notification_type_preview_complete_description"),
                faqURLString
            )
        }
    }
    
    public var previewSenderName: String {
        switch self {
        case .restrictive:
            BundleUtil.localizedString(forKey: "settings_notification_type_preview_restrictive_sender_name")
        case .balanced:
            BundleUtil.localizedString(forKey: "settings_notification_type_preview_balanced_sender_name")
        case .complete:
            BundleUtil.localizedString(forKey: "settings_notification_type_preview_complete_sender_name")
        }
    }
    
    public var previewMessageTextWithPreviewOn: String {
        BundleUtil.localizedString(forKey: "settings_notification_type_preview_message_text")
    }
    
    public var previewMessageTextWithPreviewOff: String {
        BundleUtil.localizedString(forKey: "chat_text_view_placeholder")
    }
}
