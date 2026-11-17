import CocoaLumberjackSwift
import FileUtility
import Foundation
import Intents
import PromiseKit
import ThreemaEssentials
import ThreemaMacros

public enum UserNotificationStage: String, CaseIterable {
    case initial
    case abstract
    case base
    case final
}

public protocol PendingUserNotificationManagerProtocol {
    /// Create or update pending user notification for threema push.
    /// - Parameters:
    ///     - for: `ThreemaPushNotification`
    ///     - stage: `UserNotificationStage` for the notification, usually is `.initial`
    /// - Returns: Optional `PendingUserNotification`
    func pendingUserNotification(
        for threemaPushNotification: ThreemaPushNotification,
        stage: UserNotificationStage
    )
        -> PendingUserNotification?
    
    /// Create or update pending user notification for an abstract message.
    /// - Parameters:
    ///     - for: `AbstractMessage`
    ///     - stage: `UserNotificationStage` for the notification. Not used for fetching the pending notification,
    /// usually is `.abstract`
    /// - Returns: Optional `PendingUserNotification`
    func pendingUserNotification(
        for abstractMessage: AbstractMessage,
        stage: UserNotificationStage
    ) -> PendingUserNotification?
    
    /// Create or update pending user notification for abstract message and set given base message.
    /// - Parameters:
    ///     - for: `AbstractMessage`
    ///     - baseMessage: Created or edited message
    ///     - stage: Stage for the notification, usually is `.base` or `.final`
    /// - Returns: Optional `PendingUserNotification`
    func pendingUserNotification(
        for abstractMessage: AbstractMessage,
        baseMessage: BaseMessageEntity,
        stage: UserNotificationStage
    ) -> PendingUserNotification?
    
    func pendingUserNotification(
        for boxedMessage: BoxedMessage,
        stage: UserNotificationStage
    )
        -> PendingUserNotification?
    
    /// Start timed notification for incoming message.
    /// - Parameter pendingUserNotification: Informations about incoming message
    /// - Returns: `true` if pending user notification successfully processed, shown or suppressed notification
    func startTimedUserNotification(pendingUserNotification: PendingUserNotification) -> Guarantee<Bool>
    
    /// Start test notification (necessary for customer support).
    /// - Parameters:
    ///     - payload: Information about test push
    ///     - completion: Notification's completion handler
    func startTestUserNotification(payload: [AnyHashable: Any], completion: @escaping () -> Void)
   
    /// Edit threema web notification content.
    /// - Parameter payload: Information about threema web push
    /// - Returns: User notification for user notification center
    func editThreemaWebNotification(payload: [AnyHashable: Any]) -> UNMutableNotificationContent
    
    /// Remove all timed user notifications from notification center for pending user notification.
    /// - Parameter pendingUserNotification: Remove all timed notifications for this pending user notification
    func removeAllTimedUserNotifications(pendingUserNotification: PendingUserNotification)
    
    /// Add pending user notification as processed.
    /// - Parameter pendingUserNotification: Adding pending user notification as processed
    func addAsProcessed(pendingUserNotification: PendingUserNotification)
    
    /// Check is pending user notification processed.
    /// - Returns: `true` if pending user notification processed otherwise false
    func isProcessed(pendingUserNotification: PendingUserNotification) -> Bool
    
    /// Get a list of pending user notifications are not pending in notification center.
    /// - Returns: Pending user notifications or nil
    func pendingUserNotificationsAreNotPending() -> [PendingUserNotification]?
    
    func isValid(pendingUserNotification: PendingUserNotification) -> Bool
    
    /// Loads the lists of pending and processed user notifications.
    func loadAll()
}

public final class PendingUserNotificationManager: NSObject, PendingUserNotificationManagerProtocol {

    // MARK: - Static
    // Pending
    private static var pendingUserNotifications: [PendingUserNotification]?
    public static let pendingQueue = DispatchQueue(label: "ch.threema.PendingUserNotificationManager.pendingQueue")
    static var pathPendingUserNotifications: String {
        var path: String?
        if path == nil {
            path = FileUtility.shared.appDataDirectory(appGroupID: AppGroup.groupID())!
                .appendingPathComponent("PendingUserNotifications").path
        }
        return path!
    }
    
    // Processed
    public static let processedUserNotificationsFileName = "ProcessedUserNotifications"
    private static var processedUserNotifications: [String]?
    private static let maxProcessedUserNotificationsCount = 300
    private static let processedQueue = DispatchQueue(label: "ch.threema.PendingUserNotificationManager.processedQueue")
    static var pathProcessedUserNotifications: String {
        var path: String?
        if path == nil {
            path = FileUtility.shared.appDataDirectory(appGroupID: AppGroup.groupID())!
                .appendingPathComponent(processedUserNotificationsFileName).path
        }
        return path!
    }

    // MARK: - Private properties
    
    private let userNotificationManager: any UserNotificationManagerProtocol
    private let userNotificationCenterManager: any UserNotificationCenterManagerProtocol
    private let pushSettingManager: any PushSettingManagerProtocol
    private let entityManager: EntityManager
    private let userSettings: any UserSettingsProtocol

    // MARK: - Lifecycle
    
    required init(
        userNotificationManager: any UserNotificationManagerProtocol,
        userNotificationCenterManager: any UserNotificationCenterManagerProtocol,
        pushSettingManager: any PushSettingManagerProtocol,
        entityManager: EntityManager,
        userSettings: any UserSettingsProtocol
    ) {
        self.userNotificationManager = userNotificationManager
        self.userNotificationCenterManager = userNotificationCenterManager
        self.pushSettingManager = pushSettingManager
        self.entityManager = entityManager
        self.userSettings = userSettings
        super.init()

        loadAll()
    }
    
    public convenience init(
        userNotificationManager: any UserNotificationManagerProtocol,
        pushSettingManager: any PushSettingManagerProtocol,
        entityManager: EntityManager,
        userSettings: any UserSettingsProtocol
    ) {
        self.init(
            userNotificationManager: userNotificationManager,
            userNotificationCenterManager: UserNotificationCenterManager(),
            pushSettingManager: pushSettingManager,
            entityManager: entityManager,
            userSettings: userSettings
        )
    }
    
    // MARK: - Public functions
    
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

    public func pendingUserNotification(
        for abstractMessage: AbstractMessage,
        baseMessage: BaseMessageEntity,
        stage: UserNotificationStage
    ) -> PendingUserNotification? {
        var pendingUserNotification: PendingUserNotification?
        if let key = PendingUserNotificationKey.key(
            identity: abstractMessage.fromIdentity,
            messageID: abstractMessage.messageID
        ) {
            // Reactions of everybody to the same message update one and the same notification, all other
            // notifications are per sender and message
            let contentKey: PendingUserNotificationKey? =
                if abstractMessage is ReactionMessage || abstractMessage is GroupReactionMessage {
                    PendingUserNotificationKey.reactionKey(reactedMessageID: baseMessage.id)
                }
                else {
                    PendingUserNotificationKey.key(
                        identity: abstractMessage.fromIdentity,
                        messageID: baseMessage.id
                    )
                }

            PendingUserNotificationManager.pendingQueue.sync {
                pendingUserNotification = getPendingUserNotification(key: key)
                pendingUserNotification?.abstractMessage = abstractMessage
                pendingUserNotification?.contentKey = contentKey ?? key
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

    @discardableResult public func startTimedUserNotification(pendingUserNotification: PendingUserNotification)
        -> Guarantee<Bool> {
        Guarantee { seal in
            guard isValid(pendingUserNotification: pendingUserNotification) else {
                DDLogWarn("[Push] Pending user notification is not valid")
                seal(false)
                return
            }

            if pendingUserNotification.abstractMessage is EditMessage ||
                pendingUserNotification.abstractMessage is EditGroupMessage,
                pendingUserNotification.baseMessage != nil,
                userNotificationCenterManager.isDelivered(contentKey: pendingUserNotification.contentKey) {
                // In general we will not display a notification for an edit message, but if a notification has already
                // been
                // delivered, the content of the notification will be changed. Therefore `canShowUserNotification` is
                // not
                // validated in this case.
            }
            else if pendingUserNotification.abstractMessage is ReactionMessage ||
                pendingUserNotification.abstractMessage is GroupReactionMessage,
                pendingUserNotification.baseMessage != nil {
                // We only show a notification for reactions if there is a base message for them.
            }
            else {
                guard pendingUserNotification.abstractMessage?.canShowUserNotification() ?? true else {
                    DDLogNotice("[Push] Removing notification from \(#function)")
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
            
            let isReactionNotification = pendingUserNotification.abstractMessage is ReactionMessage
                || pendingUserNotification.abstractMessage is GroupReactionMessage

            // Add notification or suppress it
            var suppress = false
            var silent = false

            if let pushSetting = pushSettingManager.pushSetting(for: pendingUserNotification) {
                if userNotificationContent.isGroupMessage {
                    if let baseMessage = pendingUserNotification.baseMessage {
                        suppress = !pushSettingManager.canSendPush(
                            for: baseMessage,
                            isReaction: isReactionNotification
                        ) || !pushSetting
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
            
            // If we got a reaction notification, but there are no longer any reactions for the message, we make sure to
            // remove any existing
            // notifications for the affected message already visible.
            if isReactionNotification, let baseMessageObjectID = pendingUserNotification.baseMessage?.objectID {
                let (isOwnMessage, reactionCount) = entityManager.performAndWait {
                    guard let baseMessage = self.entityManager.entityFetcher
                        .existingObject(with: baseMessageObjectID) as? BaseMessageEntity else {
                        return (true, 0)
                    }
                    let reactionCount = self.entityManager.entityFetcher
                        .unreadMessageReactionEntities(for: baseMessage)?.count ?? 0
                    return (baseMessage.isOwnMessage, reactionCount)
                }

                guard isOwnMessage else {
                    DDLogWarn(
                        "[Push] Reaction not for own message. Suppressed push, removing from pending, key: \(pendingUserNotification.contentKey)"
                    )
                    userNotificationCenterManager.remove(
                        contentKey: pendingUserNotification.contentKey,
                        exceptStage: nil,
                        justPending: true
                    )
                    seal(false)
                    return
                }
                
                if reactionCount == 0 {
                    DDLogWarn(
                        "[Push] No reactions to show. Suppressed push, removing from pending, key: \(pendingUserNotification.contentKey)"
                    )
                    userNotificationCenterManager.remove(
                        contentKey: pendingUserNotification.contentKey,
                        exceptStage: nil,
                        justPending: false
                    )
                    seal(false)
                    return
                }

                let contentKey = pendingUserNotification.contentKey
                if pendingUserNotification.isReactionWithdrawal,
                   !userNotificationCenterManager.isDelivered(contentKey: contentKey),
                   !UserNotificationStage.allCases.contains(where: {
                       userNotificationCenterManager.isPending(contentKey: contentKey, stage: $0)
                   }) {
                    DDLogNotice("[Push] Reaction withdrawn, but no notification to update, key: \(contentKey)")
                    seal(false)
                    return
                }
            }
            
            var notification = UNMutableNotificationContent()
            userNotificationManager.applyContent(
                from: userNotificationContent,
                to: &notification,
                silent: silent
            )
                        
            let notificationType = NotificationType.type(for: userSettings.notificationType)
                        
            // Add communication notification if enabled
            guard case .complete = notificationType, let interaction = pendingUserNotification.interaction else {
                // Add standard notification
                addPendingUserNotification(for: notification, with: pendingUserNotification, seal: seal)
                return
            }

            // Siri announces group messages from the content title, not from the intent's sender
            if userNotificationContent.isGroupMessage,
               let fromName = userNotificationContent.fromName,
               !notification.title.isEmpty,
               notification.title != fromName {
                notification.title = String.localizedStringWithFormat(
                    #localize("notification_group_message_title"),
                    fromName,
                    notification.title
                )
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
        // Taking a reaction back only updates the notification about the others, it must not alert again
        if pendingUserNotification.isReactionWithdrawal {
            notification.sound = nil
            notification.interruptionLevel = .passive
        }

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
                "[Push] Adding notification to notification center failed: \(error)"
            )
            seal(false)
        }
    }
    
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
                DDLogNotice("[Push] Error while adding test push notification: \(err)")
            }
            completion()
        }
    }
    
    public func editThreemaWebNotification(payload: [AnyHashable: Any]) -> UNMutableNotificationContent {
        userNotificationManager.threemaWebNotificationContent(payload: payload)
    }

    public func removeAllTimedUserNotifications(pendingUserNotification: PendingUserNotification) {
        DDLogNotice("[Push] Removing all notifications from \(#function)")
        userNotificationCenterManager.remove(
            contentKey: pendingUserNotification.contentKey,
            exceptStage: nil,
            justPending: true
        )
    }
    
    public func addAsProcessed(pendingUserNotification: PendingUserNotification) {
        // A processed notification is done, so it must not stay pending: otherwise only the (limited) processed list
        // keeps `showIsNotPending()` from showing it again. Async, because this is also called on `pendingQueue`.
        let key = pendingUserNotification.key
        PendingUserNotificationManager.pendingQueue.async {
            guard PendingUserNotificationManager.pendingUserNotifications?.contains(where: { $0.key == key }) == true
            else {
                return
            }

            PendingUserNotificationManager.pendingUserNotifications?.removeAll { $0.key == key }
            PendingUserNotificationManager.savePendingUserNotifications()
        }

        // Messages that never show a notification (receipts, typing indicators, …) would only push the keys of real
        // notifications out of the limited list. Reactions do notify, despite `canShowUserNotification()`.
        if let abstractMessage = pendingUserNotification.abstractMessage,
           !abstractMessage.canShowUserNotification(),
           !(abstractMessage is ReactionMessage || abstractMessage is GroupReactionMessage) {
            return
        }

        PendingUserNotificationManager.processedQueue.sync {
            if PendingUserNotificationManager.processedUserNotifications == nil {
                PendingUserNotificationManager.processedUserNotifications = [String]()
            }
            // Already processed: nothing changed, so don't rewrite the file
            guard PendingUserNotificationManager.processedUserNotifications?
                .contains(pendingUserNotification.key) != true else {
                return
            }

            PendingUserNotificationManager.processedUserNotifications?.append(pendingUserNotification.key)
            _ = PendingUserNotificationManager.limitProcessedUserNotifications()
            PendingUserNotificationManager.saveProcessedUserNotifications()
        }
    }
    
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

    public func loadAll() {
        let fileUtility = FileUtility.shared!
        
        // Processed
        PendingUserNotificationManager.processedQueue.sync {
            guard fileUtility.fileExists(atPath: PendingUserNotificationManager.pathProcessedUserNotifications),
                  let data = fileUtility.read(fileURL: URL(
                      fileURLWithPath: PendingUserNotificationManager.pathProcessedUserNotifications
                  ))
            else {
                return
            }
            
            guard let savedProcessedUserNotifications = try? NSKeyedUnarchiver.unarchivedObject(
                ofClasses: [NSArray.self, NSString.self],
                from: data
            ) as? [String] else {
                DDLogError("[Push] File of processed user notifications could not be decoded, removing file")
                try? fileUtility.delete(
                    atPath: PendingUserNotificationManager.pathProcessedUserNotifications
                )
                return
            }
            
            PendingUserNotificationManager.processedUserNotifications = savedProcessedUserNotifications
        }

        // Pending
        PendingUserNotificationManager.pendingQueue.sync {
            guard PendingUserNotificationManager.pendingUserNotifications == nil else {
                return
            }
            
            guard fileUtility.fileExists(atPath: PendingUserNotificationManager.pathPendingUserNotifications),
                  let data = fileUtility.read(fileURL: URL(
                      fileURLWithPath: PendingUserNotificationManager.pathPendingUserNotifications
                  ))
            else {
                return
            }
            
            guard let savedPendingUserNotifications = try? NSKeyedUnarchiver.unarchivedObject(
                ofClasses: [
                    NSArray.self,
                    PendingUserNotification.self,
                    NSString.self,
                    AbstractMessage.self,
                    NSData.self,
                    NSDate.self,
                ],
                from: data
            ) as? [PendingUserNotification] else {
                DDLogError("[Push] File of pending user notifications could not be decoded, removing file")
                try? fileUtility.delete(atPath: PendingUserNotificationManager.pathPendingUserNotifications)
                return
            }
            
            PendingUserNotificationManager.pendingUserNotifications = [PendingUserNotification]()
                    
            for pendingUserNotification in savedPendingUserNotifications {
                guard !isProcessed(pendingUserNotification: pendingUserNotification) else {
                    DDLogWarn("[Push] PendingUserNotification already processed")
                    continue
                }
                
                guard !(
                    PendingUserNotificationManager.pendingUserNotifications?
                        .contains(where: { $0.key == pendingUserNotification.key }) ?? false
                ) else {
                    DDLogWarn("[Push] PendingUserNotification duplicate")
                    continue
                }
           
                if pendingUserNotification.baseMessage == nil,
                   let baseMessageID = pendingUserNotification.baseMessageID,
                   let abstractMessage = pendingUserNotification.abstractMessage,
                   let conversation = entityManager.conversation(
                       forMessage: abstractMessage,
                       myIdentity: MyIdentityStore.shared().identity
                   ) {
                    pendingUserNotification.baseMessage =
                        self.entityManager.entityFetcher.message(
                            with: baseMessageID,
                            in: conversation
                        )
                }
                
                PendingUserNotificationManager.pendingUserNotifications?.append(pendingUserNotification)
            }
            PendingUserNotificationManager.savePendingUserNotifications()
        }
        
        // Limit
        PendingUserNotificationManager.processedQueue.sync {
            if PendingUserNotificationManager.limitProcessedUserNotifications() {
                PendingUserNotificationManager.saveProcessedUserNotifications()
            }
        }
    }

    /// Drop the oldest processed keys beyond `maxProcessedUserNotificationsCount`, must run on `processedQueue`
    /// - Returns: True if keys were dropped
    private static func limitProcessedUserNotifications() -> Bool {
        guard let count = processedUserNotifications?.count, count > maxProcessedUserNotificationsCount else {
            return false
        }

        processedUserNotifications?.removeFirst(count - maxProcessedUserNotificationsCount)
        return true
    }

    /// Caution: This function is only for unit testing!
    static func clear() {
        PendingUserNotificationManager.pendingUserNotifications = nil
        PendingUserNotificationManager.processedUserNotifications = nil
    }
    
    private static func savePendingUserNotifications() {
        let fileUtility = FileUtility.shared!
        
        do {
            if fileUtility.fileExists(atPath: pathPendingUserNotifications) {
                try fileUtility.delete(atPath: pathPendingUserNotifications)
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
                    requiringSecureCoding: true
                )
                fileUtility.write(
                    contents: archivedData,
                    to: URL(fileURLWithPath: pathPendingUserNotifications)
                )
            }
        }
        catch {
            DDLogError(
                "[Push] Unable to write \(pathPendingUserNotifications) file: \(error)"
            )
        }
    }
    
    private static func saveProcessedUserNotifications() {
        let fileUtility = FileUtility.shared!
        
        do {
            if fileUtility.fileExists(atPath: pathProcessedUserNotifications) {
                try fileUtility.delete(atPath: pathProcessedUserNotifications)
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
                    requiringSecureCoding: true
                )
                fileUtility.write(
                    contents: archivedData,
                    to: URL(fileURLWithPath: pathProcessedUserNotifications)
                )
            }
        }
        catch {
            DDLogError(
                "[Push] Unable to write \(pathProcessedUserNotifications) file: \(error)"
            )
        }
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
