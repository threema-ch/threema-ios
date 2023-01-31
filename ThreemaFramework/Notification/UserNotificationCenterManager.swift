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
        key: String,
        stage: UserNotificationStage,
        notification: UNNotificationContent
    ) -> Promise<Date?>
    func isPending(key: String, stage: UserNotificationStage) -> Bool
    func remove(key: String, exceptStage: UserNotificationStage?)
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
        key: String,
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
            
            let dispatchGroup = DispatchGroup()
            dispatchGroup.enter()
            
            let notificationRequest = UNNotificationRequest(
                identifier: getIdentifier(key, stage),
                content: notification,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(notificationRequest) { error in
                if let error = error {
                    seal.reject(
                        UserNotificationCenterManagerError
                            .failedToAdd(
                                message: "[Push] Adding notification for message \(key) was not successful. Error: \(error.localizedDescription)"
                            )
                    )
                }
                else {
                    DDLogNotice(
                        "[Push] Added message \(key) to notification center with trigger \(trigger?.timeInterval ?? 0)s and identifier \(notificationRequest.identifier)"
                    )
                    self.remove(key: key, exceptStage: stage)
                    
                    seal.fulfill(fireDate)
                }
                dispatchGroup.leave()
            }
            
            dispatchGroup.wait()
        }
    }
    
    /// Looking for notification is pending in notification center.
    ///
    /// - Parameters:
    ///     - key: Key of notification
    ///     - stage: Stage of incoming message
    /// - Returns: True notification is pending in notification center
    func isPending(key: String, stage: UserNotificationStage) -> Bool {
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
    ///     - key: Key of notification to remove
    ///     - exceptStage: Remove all notifications with key except this stages
    func remove(key: String, exceptStage: UserNotificationStage?) {
        var removeKeyStages = [String]()
        for stage in UserNotificationStage.allCases.filter({ stage -> Bool in
            exceptStage == nil ? true : stage != exceptStage
        }) {
            removeKeyStages.append(getIdentifier(key, stage))
        }
        
        DDLogNotice("[Push] Remove notifications with keys: \(removeKeyStages)")
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: removeKeyStages)
    }
    
    private func getIdentifier(_ key: String, _ stage: UserNotificationStage) -> String {
        "\(key)-\(stage)"
    }
}
