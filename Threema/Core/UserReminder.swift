import CocoaLumberjackSwift
import Foundation
import ThreemaMacros

enum UserReminder {
    private static let debug = false
    private static let timeIntervalDebug = false
    
    private static let secondsInMinute: TimeInterval = 60
    private static let minutesInHour: TimeInterval = 60
    private static let hoursInDay: TimeInterval = 60
    private static let secondsInDay: TimeInterval = secondsInMinute * minutesInHour * hoursInDay
    
    private static let linkReminderTime: TimeInterval = 2 * secondsInDay
    private static let kPublicNicknameReminderTime: TimeInterval = 3 * secondsInDay
    private static let pushReminderTime: TimeInterval = secondsInMinute * 15
    private static let pushReminderInterval: TimeInterval = 1 * secondsInDay
    
    private static var idCreatedLessThanIntervalAgo: Bool {
        let targetDate = idCreationDate.addingTimeInterval(UserReminder.pushReminderTime)
        return targetDate.distance(to: Date()) <= 0
    }
    
    private static var idCreationDate: Date {
        let key = "IdentityCreationDate"
        guard let date = AppGroup.userDefaults().object(forKey: key) as? Date else {
            DDLogVerbose("Init with current date")
            let currentDate = Date()
            AppGroup.userDefaults().set(currentDate, forKey: key)
            return Date()
        }
        
        return date
    }
    
    private static var shouldShowPushNotificationReminder: Bool {
        !alreadyShownNotificationInInterval && !pushRemindersDisabled
    }
    
    private static var alreadyShownNotificationInInterval: Bool {
        guard let lastShown = AppGroup.userDefaults().object(forKey: "PushReminderShowDate") as? Date else {
            return false
        }

        return lastShown.distance(to: Date()) < pushReminderInterval && !timeIntervalDebug
    }
    
    private static var pushRemindersDisabled: Bool {
        AppGroup.userDefaults().bool(forKey: "PushReminderDoNotShowAgain")
    }
    
    public static func isPushEnabled() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { notificationSettings in
                switch notificationSettings.authorizationStatus {
                case .authorized:
                    let allVisibleNotificationsDisabled = notificationSettings.notificationCenterSetting == .disabled
                        && notificationSettings.lockScreenSetting == .disabled
                        && notificationSettings.alertSetting == .disabled
                    
                    let allAudibleNotificationsDisabled = notificationSettings.soundSetting == .disabled
                    
                    if allVisibleNotificationsDisabled, allAudibleNotificationsDisabled {
                        continuation.resume(returning: false)
                    }
                    else {
                        continuation.resume(returning: true)
                    }
                case .denied:
                    continuation.resume(returning: false)
                case .notDetermined:
                    continuation.resume(returning: false)
                default:
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    public static func checkPushReminder() async -> Bool {
        let isPushEnabled = await isPushEnabled()
        
        guard !isPushEnabled || debug else {
            DDLogVerbose("Push notifications are enabled")
            return false
        }
        
        guard !idCreatedLessThanIntervalAgo || debug else {
            DDLogVerbose("Push reminder: not time to show yet")
            return false
        }
        
        guard shouldShowPushNotificationReminder || debug else {
            DDLogVerbose("Push Reminder disabled or already shown")
            return false
        }
        
        return true
    }

    static func maybeShowArchiveInfo(on viewController: UIViewController) {
        let key = "ArchiveInfoDoNotShowAgain"
        let doNotShowAgain = AppGroup.userDefaults().bool(forKey: key)
        
        guard !doNotShowAgain else {
            DDLogVerbose("Archived Info already shown")
            return
        }
        
        let title = #localize("archived_alert_title")
        let message = #localize("archived_alert_message")
        
        UIAlertTemplate.showAlert(owner: viewController, title: title, message: message, actionOk: { _ in
            AppGroup.userDefaults().set(true, forKey: key)
        })
    }
    
    static func maybeShowDeletePrivateChatInfoOnViewController(on viewController: UIViewController) {
        let key = "PrivateChatDeleteInfoDoNotShowAgain"
        let doNotShowAgain = AppGroup.userDefaults().bool(forKey: key)
        
        guard !doNotShowAgain else {
            DDLogVerbose("Private Chat delete Info already shown")
            return
        }
        
        let title = #localize("privateChat_alert_title")
        let message = #localize("private_delete_info_alert_message")
        
        UIAlertTemplate.showAlert(owner: viewController, title: title, message: message, actionOk: { _ in
            AppGroup.userDefaults().set(true, forKey: key)
        })
    }
    
    static func markIdentityAsDeleted() {
        AppGroup.userDefaults().removeObject(forKey: "LinkReminderShown")
        AppGroup.userDefaults().removeObject(forKey: "PublicNicknameReminderShown")
        AppGroup.userDefaults().removeObject(forKey: "IdentityCreationDate")
        AppGroup.userDefaults().removeObject(forKey: "PushReminderDoNotShowAgain")
    }
}
