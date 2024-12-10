//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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
import ThreemaMacros

// MARK: - NotificationPresenterStyle

public enum NotificationPresenterStyle: Identifiable {
    case none
    case success
    case error
    case warning
    
    public var id: String {
        switch self {
        case .none:
            "threemaNoneStyle"
        case .success:
            "threemaSucessStyle"
        case .error:
            "threemaErrorStyle"
        case .warning:
            "threemaInfoStyle"
        }
    }
    
    /// Optional UIImageView to be used in notification
    public var notificationImageView: UIImageView? {
        let view = UIImageView()
        
        switch self {
        case .none:
            return nil
            
        case .success:
            let image = UIImage(systemName: "checkmark.circle.fill")
            view.image = image
            view.tintColor = Colors.successGreen
            
        case .error:
            let image = UIImage(systemName: "exclamationmark.circle.fill")
            view.image = image
            view.tintColor = .systemRed
            
        case .warning:
            let image = UIImage(systemName: "info.circle.fill")
            view.image = image
            view.tintColor = .systemOrange
        }
        
        return view
    }
    
    /// Optional haptic feedback style
    public var hapticType: UINotificationFeedbackGenerator.FeedbackType? {
        switch self {
        case .none:
            nil
        case .success:
            .success
        case .error:
            .error
        case .warning:
            .warning
        }
    }
}

// MARK: - NotificationPresenterType

public struct NotificationPresenterType {
    
    // MARK: - Properties

    /// String to be used as main notification text
    let notificationText: String
    /// Style the notification should be in
    let notificationStyle: NotificationPresenterStyle
    
    public init(notificationText: String, notificationStyle: NotificationPresenterStyle) {
        self.notificationText = notificationText
        self.notificationStyle = notificationStyle
    }

    public static let generalSuccess = NotificationPresenterType(
        notificationText: #localize("Done"),
        notificationStyle: .success
    )
    public static let copySuccess = NotificationPresenterType(
        notificationText: #localize("notification_copying_succeeded"),
        notificationStyle: .success
    )
    public static let copyIDSuccess = NotificationPresenterType(
        notificationText: #localize("notification_copying_id_succeeded"),
        notificationStyle: .success
    )
    public static let copyError = NotificationPresenterType(
        notificationText: #localize("notification_copying_failed"),
        notificationStyle: .error
    )
    public static let saveSuccess = NotificationPresenterType(
        notificationText: #localize("notification_saving_succeeded"),
        notificationStyle: .success
    )
    public static let saveError = NotificationPresenterType(
        notificationText: #localize("notification_saving_failed"),
        notificationStyle: .error
    )
    public static let saveToPhotosSuccess = NotificationPresenterType(
        notificationText: #localize("notification_saving_to_photos_succeeded"),
        notificationStyle: .success
    )
    public static let saveToPhotosError = NotificationPresenterType(
        notificationText: #localize("notification_saving_to_photos_failed"),
        notificationStyle: .error
    )
    public static let autosaveMediaError = NotificationPresenterType(
        notificationText: #localize("notification_autosave_failed"),
        notificationStyle: .error
    )
    public static let sendingError = NotificationPresenterType(
        notificationText: #localize("notification_sending_failed"),
        notificationStyle: .error
    )
    public static let recordingTooLong = NotificationPresenterType(
        notificationText: #localize("notification_recording_too_long"),
        notificationStyle: .error
    )
    public static let playingError = NotificationPresenterType(
        notificationText: #localize("notification_cannot_play_video"),
        notificationStyle: .error
    )
    public static let connectedCallError = NotificationPresenterType(
        notificationText: #localize("notification_call_failed_connected"),
        notificationStyle: .error
    )
    public static let notConnectedCallError = NotificationPresenterType(
        notificationText: #localize("notification_call_failed_not_connected"),
        notificationStyle: .error
    )
    public static let callCreationError = NotificationPresenterType(
        notificationText: #localize("notification_call_creation_failed"),
        notificationStyle: .error
    )
    public static let callDisabledError = NotificationPresenterType(
        notificationText: #localize("notification_call_creation_disabled"),
        notificationStyle: .error
    )
    public static let profilePictureSentSuccess = NotificationPresenterType(
        notificationText: #localize("notification_sending_profile_picture_succeeded"),
        notificationStyle: .success
    )
    public static let profilePictureSentError = NotificationPresenterType(
        notificationText: #localize("notification_sending_profile_picture_failed"),
        notificationStyle: .error
    )
    public static let settingsSyncPending = NotificationPresenterType(
        notificationText: #localize("notification_settings_sync_pending"),
        notificationStyle: .none
    )
    public static let settingsSyncSuccess = NotificationPresenterType(
        notificationText: #localize("notification_settings_sync_succeeded"),
        notificationStyle: .success
    )
    public static let groupSyncSuccess = NotificationPresenterType(
        notificationText: #localize("notification_group_sync_succeeded"),
        notificationStyle: .success
    )
    public static let groupSyncError = NotificationPresenterType(
        notificationText: #localize("notification_group_sync_failed"),
        notificationStyle: .success
    )
    public static let groupCallStartError = NotificationPresenterType(
        notificationText: #localize("notification_group_call_start_failed"),
        notificationStyle: .error
    )
    public static let interactionDeleteSuccess = NotificationPresenterType(
        notificationText: #localize("notification_interaction_delete_succeeded"),
        notificationStyle: .success
    )
    public static let interactionDeleteError = NotificationPresenterType(
        notificationText: #localize("notification_interaction_delete_failed"),
        notificationStyle: .error
    )
    public static let revocationFailed = NotificationPresenterType(
        notificationText: #localize("notification_revocation_failed"),
        notificationStyle: .error
    )
    public static let captionTooLong = NotificationPresenterType(
        notificationText: #localize("notification_caption_too_long"),
        notificationStyle: .error
    )
    public static let updateWorkDataFailed = NotificationPresenterType(
        notificationText: #localize("notification_updateworkdata_failed"),
        notificationStyle: .error
    )
    public static let emptyDebugLogSuccess = NotificationPresenterType(
        notificationText: #localize("notification_empty_debug_log_success"),
        notificationStyle: .success
    )
    public static let flushMessageQueueSuccess = NotificationPresenterType(
        notificationText: #localize("notification_flush_message_queue_succeeded"),
        notificationStyle: .success
    )
    public static let resetUnreadCountSuccess = NotificationPresenterType(
        notificationText: #localize("settings_advanced_successfully_reset_unread_count_label"),
        notificationStyle: .success
    )
    public static let reregisterNotificationsSuccess = NotificationPresenterType(
        notificationText: #localize("notification_reregister_notifications_succeeded"),
        notificationStyle: .success
    )
    public static let audioMuted = NotificationPresenterType(
        notificationText: #localize("notification_audio_muted"),
        notificationStyle: .none
    )
    public static let audioUnmuted = NotificationPresenterType(
        notificationText: #localize("notification_audio_unmuted"),
        notificationStyle: .none
    )
    public static let videoMuted = NotificationPresenterType(
        notificationText: #localize("notification_video_muted"),
        notificationStyle: .none
    )
    public static let videoUnmuted = NotificationPresenterType(
        notificationText: #localize("notification_video_unmuted"),
        notificationStyle: .none
    )
    public static let safePasswordAccepted = NotificationPresenterType(
        notificationText: #localize("threema_safe_company_mdm_password_changed_accepted"),
        notificationStyle: .success
    )
    public static let noConnection = NotificationPresenterType(
        notificationText: #localize("cannot_connect_title"),
        notificationStyle: .error
    )
    public static let idWrongLength = NotificationPresenterType(
        notificationText: #localize("notification_threema_id_wrong_length"),
        notificationStyle: .error
    )
}

// MARK: - AccessibilityAnnouncementType

public struct AccessibilityAnnouncementType {
    
    // MARK: - Properties

    /// String to be used as main notification text
    let announcementText: String
    
    public init(announcementText: String) {
        self.announcementText = announcementText
    }
    
    public static let audioMuted = AccessibilityAnnouncementType(
        announcementText: #localize("notification_audio_muted")
    )
    public static let audioUnmuted = AccessibilityAnnouncementType(
        announcementText: #localize("notification_audio_unmuted")
    )
    public static let videoMuted = AccessibilityAnnouncementType(
        announcementText: #localize("notification_video_muted")
    )
    public static let videoUnmuted = AccessibilityAnnouncementType(
        announcementText: #localize("notification_video_unmuted")
    )
}
