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

import CocoaLumberjackSwift
import Foundation

@objc class UserReminder: NSObject {
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
    
    @objc static func maybeShowNoteGroupReminder(on viewController: UIViewController) {
        let doNotShowAgain = AppGroup.userDefaults().bool(forKey: "NoteGroupDoNotShowAgain")
        
        guard !doNotShowAgain else {
            DDLogVerbose("Note group already shown")
            return
        }
        
        let title = BundleUtil.localizedString(forKey: "create_note_group_info_title")
        let message = BundleUtil.localizedString(forKey: "create_note_group_info_text")
        let titleOk = BundleUtil.localizedString(forKey: "remind_me_next_time")
        let titleCancel = BundleUtil.localizedString(forKey: "ok")
        
        UIAlertTemplate.showAlert(
            owner: viewController,
            title: title,
            message: message,
            titleOk: titleOk,
            titleCancel: titleCancel
        ) { _ in
            AppGroup.userDefaults().set(true, forKey: "NoteGroupDoNotShowAgain")
        }
    }
    
    static func maybeShowArchiveInfo(on viewController: UIViewController) {
        let key = "ArchiveInfoDoNotShowAgain"
        let doNotShowAgain = AppGroup.userDefaults().bool(forKey: key)
        
        guard !doNotShowAgain else {
            DDLogVerbose("Archived Info already shown")
            return
        }
        
        let title = BundleUtil.localizedString(forKey: "archived_alert_title")
        let message = BundleUtil.localizedString(forKey: "archived_alert_message")
        
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
        
        let title = BundleUtil.localizedString(forKey: "privateChat_alert_title")
        let message = BundleUtil.localizedString(forKey: "private_delete_info_alert_message")
        
        UIAlertTemplate.showAlert(owner: viewController, title: title, message: message, actionOk: { _ in
            AppGroup.userDefaults().set(true, forKey: key)
        })
    }
    
    @objc static func markIdentityAsDeleted() {
        AppGroup.userDefaults().removeObject(forKey: "LinkReminderShown")
        AppGroup.userDefaults().removeObject(forKey: "PublicNicknameReminderShown")
        AppGroup.userDefaults().removeObject(forKey: "IdentityCreationDate")
        AppGroup.userDefaults().removeObject(forKey: "PushReminderDoNotShowAgain")
        AppGroup.userDefaults().removeObject(forKey: "NoteGroupDoNotShowAgain")
    }
}
