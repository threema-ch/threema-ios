//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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
import PromiseKit

protocol UserNotificationCenterManagerProtocol {
    func add(
        key: PendingUserNotificationKey,
        stage: UserNotificationStage,
        notification: UNNotificationContent
    ) -> Promise<Date?>
    func isPending(key: PendingUserNotificationKey, stage: UserNotificationStage) -> Bool
    func remove(key: PendingUserNotificationKey, exceptStage: UserNotificationStage?, justPending: Bool)
}

enum UserNotificationCenterManagerError: Error {
    case failedToAdd(message: String)
}

class UserNotificationCenterManager: UserNotificationCenterManagerProtocol {
    
    /// Add notification to notification center.
    ///
    /// - Parameters:
    ///    - key: Key of notification
    ///    - stage: Stage of incoming message, if not equals 'final' set trigger date (30s) to fire (show) notification otherwise fire notification right now
    ///    - notification: Notification for adding/replacing
    /// - Returns: Date when notification will be showed
    func add(
        key: PendingUserNotificationKey,
        stage: UserNotificationStage,
        notification: UNNotificationContent
    ) -> Promise<Date?> {
        Promise { seal in
            var trigger: UNTimeIntervalNotificationTrigger?
            var fireDate: Date?
            
            if stage != .final {
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: 30, repeats: false)
                fireDate = trigger!.nextTriggerDate()
            }
            
            let notificationRequest = UNNotificationRequest(
                identifier: getIdentifier(key, stage),
                content: notification,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(notificationRequest) { error in
                if let error = error {
                    if let error = error as? UNError, error.code == .attachmentInvalidURL {
                        // As of iOS 16.4 there is an issue where we can't always add notifications with attachments.
                        // In that case we just remove the attachment and post the notification without it.
                        // This is not great but still gives us quicker notifications (rather than waiting for the 30s timeout)
                        // and keeps rich communication notifications donations.
                        guard !notification.attachments.isEmpty else {
                            seal.reject(
                                UserNotificationCenterManagerError
                                    .failedToAdd(
                                        message: "[Push] Adding notification for message \(key) was not successful. Error: \(error.localizedDescription)"
                                    )
                            )
                            return
                        }
                        let mutCopy = notification.mutableCopy() as! UNMutableNotificationContent
                        mutCopy.attachments = []
                        
                        self.add(key: key, stage: stage, notification: mutCopy).pipe(to: { seal.resolve($0) })
                    }
                    else {
                        seal.reject(
                            UserNotificationCenterManagerError
                                .failedToAdd(
                                    message: "[Push] Adding notification for message \(key) was not successful. Error: \(error.localizedDescription)"
                                )
                        )
                    }
                }
                else {
                    DDLogNotice(
                        "[Push] Added message \(key) to notification center with trigger \(trigger?.timeInterval ?? 0)s and identifier \(notificationRequest.identifier)"
                    )
                    self.remove(key: key, exceptStage: stage, justPending: true)
                    
                    seal.fulfill(fireDate)
                }
            }
        }
    }
    
    /// Looking for notification is pending in notification center.
    ///
    /// - Parameters:
    ///     - key: Key of notification
    ///     - stage: Stage of incoming message
    /// - Returns: True notification is pending in notification center
    func isPending(key: PendingUserNotificationKey, stage: UserNotificationStage) -> Bool {
        var isPending = false

        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        UNUserNotificationCenter.current().getPendingNotificationRequests { pendingNotifications in
            for pendingNotification in pendingNotifications {
                if pendingNotification.identifier.elementsEqual(self.getIdentifier(key, stage)) {
                    isPending = true
                    break
                }
            }
            dispatchGroup.leave()
        }
        dispatchGroup.wait()
        
        return isPending
    }
    
    /// Remove notifications with key from notification center.
    ///
    /// - Parameters:
    ///   - key: Key of notification to remove
    ///   - exceptStage: Removes all notifications with key except this stages
    ///   - justPending: Removes pending notifications only
    func remove(key: PendingUserNotificationKey, exceptStage: UserNotificationStage?, justPending: Bool) {
        var removeKeyStages = [String]()
        for stage in UserNotificationStage.allCases.filter({ stage -> Bool in
            exceptStage == nil ? true : stage != exceptStage
        }) {
            removeKeyStages.append(getIdentifier(key, stage))
        }

        DDLogNotice("[Push] Remove pending notifications with keys: \(removeKeyStages)")
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: removeKeyStages)

        if !justPending {
            DDLogNotice("[Push] Remove delivered notifications with keys: \(removeKeyStages)")
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: removeKeyStages)
        }
    }

    private func getIdentifier(_ key: PendingUserNotificationKey, _ stage: UserNotificationStage) -> String {
        "\(key)-\(stage)"
    }
}
