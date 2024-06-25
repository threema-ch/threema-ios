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
import Intents
import PromiseKit

public enum UserNotificationStage: String, CaseIterable {
    case initial
    case abstract
    case base
    case final
}

public protocol PendingUserNotificationManagerProtocol {
    func pendingUserNotification(for threemaPushNotification: ThreemaPushNotification, stage: UserNotificationStage)
        -> PendingUserNotification?
    func pendingUserNotification(
        for abstractMessage: AbstractMessage,
        stage: UserNotificationStage
    ) -> PendingUserNotification?
    func pendingUserNotification(
        for abstractMessage: AbstractMessage,
        baseMessage: BaseMessage,
        stage: UserNotificationStage
    ) -> PendingUserNotification?
    func pendingUserNotification(for boxedMessage: BoxedMessage, stage: UserNotificationStage)
        -> PendingUserNotification?
    func startTimedUserNotification(pendingUserNotification: PendingUserNotification) -> Guarantee<Bool>
    func startTestUserNotification(payload: [AnyHashable: Any], completion: @escaping () -> Void)
    func editThreemaWebNotification(payload: [AnyHashable: Any]) -> UNMutableNotificationContent
    func removeAllTimedUserNotifications(pendingUserNotification: PendingUserNotification)
    func addAsProcessed(pendingUserNotification: PendingUserNotification)
    func isProcessed(pendingUserNotification: PendingUserNotification) -> Bool
    func pendingUserNotificationsAreNotPending() -> [PendingUserNotification]?
    func isValid(pendingUserNotification: PendingUserNotification) -> Bool
    func loadAll()
}

public class PendingUserNotificationManager: NSObject, PendingUserNotificationManagerProtocol {

    private let userNotificationManager: UserNotificationManagerProtocol
    private let userNotificationCenterManager: UserNotificationCenterManagerProtocol
    private let pushSettingManager: PushSettingManagerProtocol
    private let entityManager: EntityManager

    private static var pendingUserNotifications: [PendingUserNotification]?
    public static let pendingQueue = DispatchQueue(label: "ch.threema.PendingUserNotificationManager.pendingQueue")

    private static var processedUserNotifications: [String]?
    private static let processedQueue = DispatchQueue(label: "ch.threema.PendingUserNotificationManager.processedQueue")

    required init(
        _ userNotificationManager: UserNotificationManagerProtocol,
        _ userNotificationCenterManager: UserNotificationCenterManagerProtocol,
        _ pushSettingManager: PushSettingManagerProtocol,
        _ entityManager: EntityManager
    ) {
        self.userNotificationManager = userNotificationManager
        self.userNotificationCenterManager = userNotificationCenterManager
        self.pushSettingManager = pushSettingManager
        self.entityManager = entityManager
        super.init()

        loadAll()
    }
    
    public convenience init(
        _ userNotificationManager: UserNotificationManagerProtocol,
        _ pushSettingManager: PushSettingManagerProtocol,
        _ entityManager: EntityManager
    ) {
        self.init(
            userNotificationManager,
            UserNotificationCenterManager(),
            pushSettingManager,
            entityManager
        )
    }
    
    /// Create or update pending user notification for threema push.
    /// - Parameters:
    ///     - for: Threema push
    ///     - stage: Stage for the notification, usually is 'initial'
    /// - Returns: Pending user notification or nil
    public func pendingUserNotification(
        for threemaPushNotification: ThreemaPushNotification,
        stage: UserNotificationStage
    ) -> PendingUserNotification? {
        var pendingUserNotification: PendingUserNotification?
        if let key = PendingUserNotificationKey.key(for: threemaPushNotification) {
            PendingUserNotificationManager.pendingQueue.sync {
                pendingUserNotification = getPendingUserNotification(key: key)
                pendingUserNotification?.threemaPushNotification = threemaPushNotification
                pendingUserNotification?.stage = stage
                PendingUserNotificationManager.savePendingUserNotifications()
            }
        }
        return pendingUserNotification
    }
    
    /// Create or update pending user notification for abstract message.
    /// - Parameters:
    ///     - for: Abstract message
    ///     - stage: Stage for the notification. Not used for fetching the pending notification
    /// - Returns: Pending user notification or nil, usually is 'abstract'
    public func pendingUserNotification(
        for abstractMessage: AbstractMessage,
        stage: UserNotificationStage
    ) -> PendingUserNotification? {
        var pendingUserNotification: PendingUserNotification?
        if let key = PendingUserNotificationKey.key(for: abstractMessage) {
            PendingUserNotificationManager.pendingQueue.sync {
                pendingUserNotification = getPendingUserNotification(key: key)
                pendingUserNotification?.abstractMessage = abstractMessage
                pendingUserNotification?.stage = stage
                PendingUserNotificationManager.savePendingUserNotifications()
            }
        }
        return pendingUserNotification
    }

    /// Create or update pending user notification for abstract message and set given base message.
    /// - Parameters:
    ///     - for: Abstract message
    ///     - baseMessage: Created or edited message
    ///     - stage: Stage for the notification, usually is 'base' or 'final'
    /// - Returns: Pending user notification or nil
    public func pendingUserNotification(
        for abstractMessage: AbstractMessage,
        baseMessage: BaseMessage,
        stage: UserNotificationStage
    ) -> PendingUserNotification? {
        var pendingUserNotification: PendingUserNotification?
        if let key = PendingUserNotificationKey.key(
            identity: abstractMessage.fromIdentity,
            messageID: abstractMessage.messageID
        ) {
            PendingUserNotificationManager.pendingQueue.sync {
                pendingUserNotification = getPendingUserNotification(key: key)
                pendingUserNotification?.contentKey = PendingUserNotificationKey.key(
                    identity: abstractMessage.fromIdentity,
                    messageID: baseMessage.id
                ) ?? key
                pendingUserNotification?.baseMessage = baseMessage
                pendingUserNotification?.stage = stage
                PendingUserNotificationManager.savePendingUserNotifications()
            }
        }
        return pendingUserNotification
    }
    
    public func pendingUserNotification(
        for boxedMessage: BoxedMessage,
        stage: UserNotificationStage
    ) -> PendingUserNotification? {
        var pendingUserNotification: PendingUserNotification?
        if let key = PendingUserNotificationKey.key(for: boxedMessage) {
            PendingUserNotificationManager.pendingQueue.sync {
                pendingUserNotification = getPendingUserNotification(key: key)
                pendingUserNotification?.stage = stage
                PendingUserNotificationManager.savePendingUserNotifications()
            }
        }
        return pendingUserNotification
    }

    /// Start timed notification for incoming message.
    /// - Parameter pendingUserNotification: Informations about incoming message
    /// - Returns: True pending user notification successfully processed, showed or suppressed notification
    @discardableResult public func startTimedUserNotification(pendingUserNotification: PendingUserNotification)
        -> Guarantee<Bool> {
        Guarantee { seal in
            guard isValid(pendingUserNotification: pendingUserNotification) else {
                DDLogWarn("[Push] Pending user notification is not valid")
                seal(false)
                return
            }

            if pendingUserNotification.abstractMessage is EditMessage,
               pendingUserNotification.baseMessage != nil,
               userNotificationCenterManager.isDelivered(contentKey: pendingUserNotification.contentKey) {

                // In general for edit message will not displayed a notification, but if a notification has already been
                // delivered, the content of the notification is changed. Therefore `canShowUserNotification` is not
                // validated in this case.
            }
            else {
                guard pendingUserNotification.abstractMessage?.canShowUserNotification() ?? true else {
                    DDLogNotice("Removing notification from \(#function)")
                    userNotificationCenterManager.remove(
                        contentKey: pendingUserNotification.contentKey,
                        exceptStage: nil,
                        justPending: false
                    )
                    addAsProcessed(pendingUserNotification: pendingUserNotification)
                    seal(true)
                    return
                }

                guard !isProcessed(pendingUserNotification: pendingUserNotification) else {
                    userNotificationCenterManager.remove(
                        contentKey: pendingUserNotification.contentKey,
                        exceptStage: nil,
                        justPending: true
                    )
                    seal(true)
                    return
                }
            }

            // Get notification content
            guard let userNotificationContent = self.userNotificationManager
                .userNotificationContent(pendingUserNotification) else {
                DDLogWarn(
                    "[Push] Invalid Notification content, removed from pending, key: \(pendingUserNotification.contentKey)"
                )
                userNotificationCenterManager.remove(
                    contentKey: pendingUserNotification.contentKey,
                    exceptStage: nil,
                    justPending: true
                )
                seal(false)
                return
            }
            
            // Add notification or suppress it
            var suppress = false
            var silent = false
                    
            if let pushSetting = pushSettingManager.pushSetting(for: pendingUserNotification) {
                if userNotificationContent.isGroupMessage {
                    if let baseMessage = pendingUserNotification.baseMessage {
                        suppress = !pushSettingManager.canSendPush(for: baseMessage) || !pushSetting
                            .canSendPushGroupCallStartMessage(for: pendingUserNotification.abstractMessage)
                    }
                    else {
                        suppress = !pushSetting
                            .canSendPushGroupCallStartMessage(for: pendingUserNotification.abstractMessage)
                    }
                }
                else {
                    suppress = !pushSetting.canSendPush()
                }

                silent = pushSetting.muted
            }

            guard !suppress else {
                DDLogWarn("[Push] Suppressed push, removing from pending, key: \(pendingUserNotification.contentKey)")
                userNotificationCenterManager.remove(
                    contentKey: pendingUserNotification.contentKey,
                    exceptStage: nil,
                    justPending: true
                )
                seal(false)
                return
            }
            
            var notification = UNMutableNotificationContent()
            userNotificationManager.applyContent(
                userNotificationContent,
                &notification,
                silent,
                pendingUserNotification.baseMessage
            )
                        
            let businessInjector = BusinessInjector()
            let notificationType = NotificationType.type(for: businessInjector.userSettings.notificationType)
                        
            // Add communication notification if enabled
            guard case .complete = notificationType, let interaction = pendingUserNotification.interaction else {
                // Add standard notification
                addPendingUserNotification(for: notification, with: pendingUserNotification, seal: seal)
                return
            }

            // Donating
            interaction.donate { error in
                guard error == nil else {
                    // Could not donate, we add a standard notification instead
                    DDLogError("[Push] Could not donate Intent, error: \(error!.localizedDescription)")
                                    
                    self.addPendingUserNotification(
                        for: notification,
                        with: pendingUserNotification,
                        seal: seal
                    )
                    return
                }
                                
                // Update notification content with intent
                do {
                    guard let updatedNotification = try notification
                        .updating(
                            from: interaction
                                .intent as! UNNotificationContentProviding
                        ) as? UNMutableNotificationContent else {
                        DDLogError("[Push] Could not cast to mutable notification. Post old.")
                                            
                        self.addPendingUserNotification(
                            for: notification,
                            with: pendingUserNotification,
                            seal: seal
                        )
                        return
                    }
                                        
                    // Add communication notification
                    self.addPendingUserNotification(
                        for: updatedNotification,
                        with: pendingUserNotification,
                        seal: seal
                    )
                }
                catch {
                    // Could not update, add standard notification instead
                    DDLogError(
                        "[Push] Could not update notification content with intent, error: \(error.localizedDescription)"
                    )
                                    
                    self.addPendingUserNotification(
                        for: notification,
                        with: pendingUserNotification,
                        seal: seal
                    )
                }
            }
        }
    }
    
    private func addPendingUserNotification(
        for notification: UNMutableNotificationContent,
        with pendingUserNotification: PendingUserNotification,
        seal: @escaping (Bool) -> Void
    ) {
        
        userNotificationCenterManager.add(
            contentKey: pendingUserNotification.contentKey,
            stage: pendingUserNotification.stage,
            notification: notification
        )
        .done { (fireDate: Date?) in
            PendingUserNotificationManager.pendingQueue.sync {
                pendingUserNotification.fireDate = fireDate
                PendingUserNotificationManager.savePendingUserNotifications()
            }
                
            seal(true)
        }
        .catch { error in
            DDLogError(
                "[Push] Adding notification to notification center failed: \(error.localizedDescription)"
            )
            seal(false)
        }
    }
    
    /// Start test notification (necessary for customer support).
    /// - Parameters:
    ///     - payload: Information about test push
    ///     - completion: Notification's completion handler
    public func startTestUserNotification(payload: [AnyHashable: Any], completion: @escaping () -> Void) {
        let notificationContent = userNotificationManager.testNotificationContent(payload: payload)

        let notificationRequest = UNNotificationRequest(
            identifier: "PushTest",
            content: notificationContent,
            trigger: nil
        )
        let center = UNUserNotificationCenter.current()
        center.add(notificationRequest) { error in
            if let err = error {
                DDLogNotice("Error while adding test push notification: \(err)")
            }
            completion()
        }
    }
    
    /// Edit threema web notification content.
    /// - Parameter payload: Information about threema web push
    /// - Returns: User notification for user notification center
    public func editThreemaWebNotification(payload: [AnyHashable: Any]) -> UNMutableNotificationContent {
        userNotificationManager.threemaWebNotificationContent(payload: payload)
    }

    /// Remove all timed user notifications from notification center for pending user notification.
    /// - Parameter pendingUserNotification: Remove all timed notifications for this pending user notification
    public func removeAllTimedUserNotifications(pendingUserNotification: PendingUserNotification) {
        DDLogNotice("Removing all notifications from \(#function)")
        userNotificationCenterManager.remove(
            contentKey: pendingUserNotification.contentKey,
            exceptStage: nil,
            justPending: true
        )
    }
    
    /// Add pending user notification as processed.
    /// - Parameter pendingUserNotification: Adding pending user notification as processed
    public func addAsProcessed(pendingUserNotification: PendingUserNotification) {
        PendingUserNotificationManager.processedQueue.sync {
            if PendingUserNotificationManager.processedUserNotifications == nil {
                PendingUserNotificationManager.processedUserNotifications = [String]()
            }
            if !(
                PendingUserNotificationManager.processedUserNotifications?
                    .contains(pendingUserNotification.key) ?? false
            ) {
                PendingUserNotificationManager.processedUserNotifications?.append(pendingUserNotification.key)
            }
            PendingUserNotificationManager.saveProcessedUserNotifications()
        }
    }
    
    /// Check is pending user notification processed.
    /// - Returns:True if pending user notification processed otherwise false
    public func isProcessed(pendingUserNotification: PendingUserNotification) -> Bool {
        var isProcessed = isProcessed(key: pendingUserNotification.key)
        if !isProcessed,
           (
               pendingUserNotification.stage == .final && pendingUserNotification
                   .fireDate == nil &&
                   !(pendingUserNotification.abstractMessage?.receivedAfterInitialQueueSend ?? false)
           )
           || (pendingUserNotification.fireDate != nil && pendingUserNotification.fireDate! < Date()) {

            addAsProcessed(pendingUserNotification: pendingUserNotification)

            isProcessed = true
        }
        return isProcessed
    }

    private func isProcessed(key: String) -> Bool {
        PendingUserNotificationManager.processedQueue.sync {
            PendingUserNotificationManager.processedUserNotifications?.filter { $0 == key }.count ?? 0 > 0
        }
    }
    
    /// Get a list of pending user notifications are not pending in notification center.
    /// - Returns: Pending user notifications or nil
    public func pendingUserNotificationsAreNotPending() -> [PendingUserNotification]? {
        guard let pendingUserNotifications = PendingUserNotificationManager.pendingUserNotifications,
              !pendingUserNotifications.isEmpty else {
            return nil
        }
        
        var pendingUserNotificationsAreNotPending: [PendingUserNotification]?
        
        for pendingUserNotification in pendingUserNotifications {
            if !userNotificationCenterManager.isPending(
                contentKey: pendingUserNotification.contentKey,
                stage: pendingUserNotification.stage
            ) {
                if pendingUserNotificationsAreNotPending == nil {
                    pendingUserNotificationsAreNotPending = [PendingUserNotification]()
                }
                pendingUserNotificationsAreNotPending?.append(pendingUserNotification)
            }
        }
        
        return pendingUserNotificationsAreNotPending
    }

    public func isValid(pendingUserNotification: PendingUserNotification) -> Bool {
        guard pendingUserNotification.isGroupMessage != nil, pendingUserNotification.messageID != nil,
              pendingUserNotification.senderIdentity != nil else {
            return false
        }
        return true
    }

    /// Loads the lists of pending and processed user notifications.
    public func loadAll() {
        PendingUserNotificationManager.processedQueue.sync {
            if FileManager.default.fileExists(atPath: PendingUserNotificationManager.pathProcessedUserNotifications) {
                if var savedProcessedUserNotifications = NSKeyedUnarchiver
                    .unarchiveObject(
                        withFile: PendingUserNotificationManager
                            .pathProcessedUserNotifications
                    ) as? [String] {

                    PendingUserNotificationManager.processedUserNotifications = savedProcessedUserNotifications
                }
                else {
                    DDLogError("File of processed user notifications could not be decoded")
                }
            }
        }

        if FileManager.default.fileExists(atPath: PendingUserNotificationManager.pathPendingUserNotifications) {
            PendingUserNotificationManager.pendingQueue.sync {
                if let savedPendingUserNotifications = NSKeyedUnarchiver
                    .unarchiveObject(
                        withFile: PendingUserNotificationManager
                            .pathPendingUserNotifications
                    ) as? [PendingUserNotification] {
                    
                    guard PendingUserNotificationManager.pendingUserNotifications == nil else {
                        return
                    }
                    PendingUserNotificationManager.pendingUserNotifications = [PendingUserNotification]()
                    
                    for pendingUserNotification in savedPendingUserNotifications {
                        if isProcessed(pendingUserNotification: pendingUserNotification) {
                            continue
                        }
                        
                        if let exists = PendingUserNotificationManager.pendingUserNotifications?
                            .contains(where: { $0.key == pendingUserNotification.key }), exists {
                            DDLogWarn("[Push] PendingUserNotification duplicate")
                        }
                        else {
                            if pendingUserNotification.baseMessage == nil,
                               let baseMessageID = pendingUserNotification.baseMessageID,
                               let abstractMessage = pendingUserNotification.abstractMessage,
                               let conversation = entityManager.conversation(forMessage: abstractMessage) {
                                pendingUserNotification.baseMessage = self.entityManager
                                    .entityFetcher.message(with: baseMessageID, conversation: conversation)
                            }
                            PendingUserNotificationManager.pendingUserNotifications?.append(pendingUserNotification)
                        }
                    }
                    
                    PendingUserNotificationManager.savePendingUserNotifications()
                }
                else {
                    DDLogError("File of pending user notifications could not be decoded")
                }
            }
        }
        
        PendingUserNotificationManager.processedQueue.sync {
            guard var savedProcessedUserNotifications = PendingUserNotificationManager.processedUserNotifications,
                  !savedProcessedUserNotifications.isEmpty else {
                return
            }
            let maxListCount = 300
                
            if savedProcessedUserNotifications.count > maxListCount {
                for _ in 0...savedProcessedUserNotifications.count - maxListCount {
                    savedProcessedUserNotifications.remove(at: 0)
                }
                PendingUserNotificationManager.saveProcessedUserNotifications()
            }
        }
    }

    /// Caution: This function is only for unit testing!
    static func clear() {
        PendingUserNotificationManager.pendingUserNotifications = nil
        PendingUserNotificationManager.processedUserNotifications = nil
    }
    
    fileprivate static func savePendingUserNotifications() {
        do {
            if FileManager.default.fileExists(atPath: pathPendingUserNotifications) {
                try FileManager.default.removeItem(atPath: pathPendingUserNotifications)
            }
        }
        catch {
            DDLogError(
                "[Push] Unable to delete \(pathPendingUserNotifications) file: \(error)"
            )
        }
        
        do {
            if let pendingUserNotifications = PendingUserNotificationManager.pendingUserNotifications,
               !pendingUserNotifications.isEmpty {
                let archivedData = try NSKeyedArchiver.archivedData(
                    withRootObject: pendingUserNotifications,
                    requiringSecureCoding: false
                )
                try archivedData.write(to: URL(fileURLWithPath: pathPendingUserNotifications))
            }
        }
        catch {
            DDLogError(
                "[Push] Unable to write \(pathPendingUserNotifications) file: \(error)"
            )
        }
    }
    
    private static func saveProcessedUserNotifications() {
        do {
            if FileManager.default.fileExists(atPath: pathProcessedUserNotifications) {
                try FileManager.default.removeItem(atPath: pathProcessedUserNotifications)
            }
        }
        catch {
            DDLogError(
                "[Push] Unable to delete \(pathProcessedUserNotifications) file: \(error)"
            )
        }
        
        do {
            if let processedUserNotifications = PendingUserNotificationManager.processedUserNotifications,
               !processedUserNotifications.isEmpty {
                let archivedData = try NSKeyedArchiver.archivedData(
                    withRootObject: processedUserNotifications,
                    requiringSecureCoding: false
                )
                try archivedData.write(to: URL(fileURLWithPath: pathProcessedUserNotifications))
            }
        }
        catch {
            DDLogError(
                "[Push] Unable to write \(pathProcessedUserNotifications) file: \(error)"
            )
        }
    }
    
    static var pathPendingUserNotifications: String {
        var path: String?
        if path == nil {
            path = FileUtility.shared.appDataDirectory!.appendingPathComponent("PendingUserNotifications").path
        }
        return path!
    }
    
    static var pathProcessedUserNotifications: String {
        var path: String?
        if path == nil {
            path = FileUtility.shared.appDataDirectory!.appendingPathComponent("ProcessedUserNotifications").path
        }
        return path!
    }
    
    private func getPendingUserNotification(key: String) -> PendingUserNotification? {
        var pendingUserNotification: PendingUserNotification?
        
        if PendingUserNotificationManager.pendingUserNotifications == nil {
            PendingUserNotificationManager.pendingUserNotifications = [PendingUserNotification]()
        }
    
        pendingUserNotification = PendingUserNotificationManager.pendingUserNotifications?
            .first(where: { $0.key == key })
        if pendingUserNotification == nil {
            pendingUserNotification = PendingUserNotification(key: key)
            PendingUserNotificationManager.pendingUserNotifications?.append(pendingUserNotification!)
        }
        
        return pendingUserNotification
    }
}
