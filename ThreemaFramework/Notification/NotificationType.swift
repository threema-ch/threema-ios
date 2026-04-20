import CocoaLumberjackSwift
import Foundation
import ThreemaMacros

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
    
    public static let remoteSecretCases: [NotificationType] = [.restrictive, .balanced]
    
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
            #localize("settings_notification_type_preview_restrictive_title")
        case .balanced:
            #localize("settings_notification_type_preview_balanced_title")
        case .complete:
            #localize("settings_notification_type_preview_complete_title")
        }
    }
    
    public var previewDescription: String {
        switch self {
        case .restrictive:
            #localize("settings_notification_type_preview_restrictive_description")
        case .balanced:
            #localize("settings_notification_type_preview_balanced_description")
        case .complete:
            String.localizedStringWithFormat(
                #localize("settings_notification_type_preview_complete_description"),
                ThreemaURLProvider.notificationTypesFAQ.absoluteString
            )
        }
    }
    
    public var previewSenderName: String {
        switch self {
        case .restrictive:
            #localize("settings_notification_type_preview_restrictive_sender_name")
        case .balanced:
            #localize("settings_notification_type_preview_balanced_sender_name")
        case .complete:
            #localize("settings_notification_type_preview_complete_sender_name")
        }
    }
    
    public var previewMessageTextWithPreviewOn: String {
        #localize("settings_notification_type_preview_message_text")
    }
    
    public var previewMessageTextWithPreviewOff: String {
        #localize("chat_text_view_placeholder")
    }
}
