//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2024 Threema GmbH
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
import ThreemaFramework

@objc class IncomingMessageManager: NSObject {
    
    @objc static let inAppNotificationNewMessage = "ThreemaNewMessageReceived"

    /// Using as main (context) configured manager (will be used when messages are processed in main thread)
    private let pendingUserNotificationManager: PendingUserNotificationManagerProtocol

    /// Using as background (context) configured manager (will be used when messages are processed in background, see:
    /// MessageProcessorDelegate)
    private let backgroundPendingUserNotificationManager: PendingUserNotificationManagerProtocol

    private let businessInjector: BusinessInjectorProtocol
    private let notificationManager: NotificationManager

    private var completionHandler: (() -> Void)?

    required init(
        pendingUserNotificationManager: PendingUserNotificationManagerProtocol,
        backgroundPendingUserNotificationManager: PendingUserNotificationManagerProtocol,
        backgroundBusinessInjector: BusinessInjectorProtocol
    ) {
        self.pendingUserNotificationManager = pendingUserNotificationManager
        self.backgroundPendingUserNotificationManager = backgroundPendingUserNotificationManager
        self.businessInjector = backgroundBusinessInjector
        self.notificationManager = NotificationManager(businessInjector: backgroundBusinessInjector)
    }
    
    @objc override convenience init() {
        let businessInjector = BusinessInjector()
        let backgroundBusinessInjector = BusinessInjector(forBackgroundProcess: true)
        self.init(
            pendingUserNotificationManager: PendingUserNotificationManager(
                UserNotificationManager(
                    businessInjector.settingsStore,
                    businessInjector.userSettings,
                    businessInjector.myIdentityStore,
                    businessInjector.pushSettingManager,
                    businessInjector.contactStore,
                    businessInjector.groupManager,
                    businessInjector.entityManager,
                    businessInjector.licenseStore.getRequiresLicenseKey()
                ),
                businessInjector.pushSettingManager,
                businessInjector.entityManager
            ),
            backgroundPendingUserNotificationManager: PendingUserNotificationManager(
                UserNotificationManager(
                    backgroundBusinessInjector.settingsStore,
                    backgroundBusinessInjector.userSettings,
                    backgroundBusinessInjector.myIdentityStore,
                    backgroundBusinessInjector.pushSettingManager,
                    backgroundBusinessInjector.contactStore,
                    backgroundBusinessInjector.groupManager,
                    backgroundBusinessInjector.entityManager,
                    backgroundBusinessInjector.licenseStore.getRequiresLicenseKey()
                ),
                backgroundBusinessInjector.pushSettingManager,
                backgroundBusinessInjector.entityManager
            ),
            backgroundBusinessInjector: backgroundBusinessInjector
        )
    }

    @objc func reloadPendingUserNotificationCache() {
        pendingUserNotificationManager.loadAll()
    }
    
    /// Show notification for incoming Threema push.
    /// - Parameters:
    ///     - threemaDic: Dictionary of threema push
    ///     - completion: Completion block of notification
    @objc func incomingPush(threemaDic: [String: Any], completion: @escaping () -> Void) {
        businessInjector.entityManager.performBlockAndWait {
            guard let threemaPushNotification = try? ThreemaPushNotification(from: threemaDic),
                  let pendingUserNotification = self.pendingUserNotificationManager.pendingUserNotification(
                      for: threemaPushNotification,
                      stage: .initial
                  ) else {

                completion()
                return
            }
            self.completionHandler = completion

            self.show(
                pendingUserNotification: pendingUserNotification,
                pendingUserNotificationManager: self.pendingUserNotificationManager,
                pushSettingManager: self.businessInjector.pushSettingManager,
                groupManager: self.businessInjector.groupManager,
                entityManager: self.businessInjector.entityManager
            )
        }
    }

    /// Show notification for test push (necessary for customer support).
    /// - Parameters:
    ///     - payloadDic: Dictionary of test push (without threema key)
    ///     - completion: Completion block of notification
    @objc func incomingPush(payloadDic: [String: Any], completion: @escaping () -> Void) {
        pendingUserNotificationManager.startTestUserNotification(payload: payloadDic, completion: completion)
    }
    
    /// Show notification for pending user notification is missing on notification center.
    @objc func showIsNotPending() {
        businessInjector.entityManager.performAndWait {
            if let pendingUserNotificationsAreNotPending = self.pendingUserNotificationManager
                .pendingUserNotificationsAreNotPending() {
                for pendingUserNotification in pendingUserNotificationsAreNotPending {
                    self.show(
                        pendingUserNotification: pendingUserNotification,
                        pendingUserNotificationManager: self.pendingUserNotificationManager,
                        pushSettingManager: self.businessInjector.pushSettingManager,
                        groupManager: self.businessInjector.groupManager,
                        entityManager: self.businessInjector.entityManager
                    )
                    .done { _ in
                        self.pendingUserNotificationManager
                            .addAsProcessed(pendingUserNotification: pendingUserNotification)
                    }
                }
            }
        }
    }
    
    // MARK: Private functions

    @discardableResult fileprivate func show(
        pendingUserNotification: PendingUserNotification,
        pendingUserNotificationManager manager: PendingUserNotificationManagerProtocol,
        pushSettingManager: PushSettingManagerProtocol,
        groupManager: GroupManagerProtocol,
        entityManager: EntityManager
    ) -> Guarantee<Bool> {
        Guarantee { seal in
            if !AppDelegate.shared().active {
                manager
                    .startTimedUserNotification(pendingUserNotification: pendingUserNotification)
                    .done(on: .global(), flags: .inheritQoS) { started in
                        if !started {
                            self.notificationManager.updateUnreadMessagesCount()
                        }
                        seal(started)
                    }
            }
            else {
                guard manager.isValid(pendingUserNotification: pendingUserNotification) else {
                    seal(false)
                    return
                }
                
                guard !manager.isProcessed(pendingUserNotification: pendingUserNotification) else {
                    manager
                        .removeAllTimedUserNotifications(pendingUserNotification: pendingUserNotification)
                    seal(true)
                    return
                }
                
                if let message = pendingUserNotification.baseMessage,
                   message.deletedAt == nil,
                   pendingUserNotification.stage == .final,
                   pendingUserNotification.abstractMessage?.receivedAfterInitialQueueSend == true {

                    if pushSettingManager.canMasterDndSendPush() {
                        entityManager.performBlock {
                            var pushSetting: PushSetting
                            if let group = groupManager.getGroup(conversation: message.conversation) {
                                pushSetting = pushSettingManager.find(forGroup: group.groupIdentity)
                            }
                            else if let contactEntity = message.conversation.contact {
                                pushSetting = pushSettingManager.find(forContact: contactEntity.threemaIdentity)
                            }
                            else {
                                fatalError("No push settings for conversation found")
                            }

                            if pushSettingManager.canSendPush(for: message) {
                                let messageObjectID = message.objectID

                                DispatchQueue.main.async {
                                    NotificationCenter.default.post(
                                        name: NSNotification
                                            .Name(rawValue: IncomingMessageManager.inAppNotificationNewMessage),
                                        object: messageObjectID,
                                        userInfo: nil
                                    )
                                }

                                if !pushSetting.muted {
                                    self.notificationManager.playReceivedMessageSound()
                                }
                            }
                        }
                    }

                    manager
                        .removeAllTimedUserNotifications(pendingUserNotification: pendingUserNotification)

                    self.notificationManager.updateUnreadMessagesCount()
                    
                    seal(true)
                    return
                }

                // Start timed user notification, will be removed on stage final anyway
                manager
                    .startTimedUserNotification(pendingUserNotification: pendingUserNotification)
                    .done(on: .global(), flags: .inheritQoS) { started in
                        if !started {
                            PendingUserNotificationManager.pendingQueue.sync {
                                self.notificationManager.updateUnreadMessagesCount()
                                seal(false)
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - MessageProcessorDelegate

extension IncomingMessageManager: MessageProcessorDelegate {
    public func beforeDecode() {
        DDLogNotice("[Threema Web] processIncomingMessage --> connect all running sessions")
        WCSessionManager.shared.connectAllRunningSessions()
    }

    func changedManagedObjectID(_ objectID: NSManagedObjectID) {
        if !AppDelegate.shared().active {
            // Set dirty DB objects for refreshing in the app process
            let databaseManager = DatabaseManager()
            databaseManager.addDirtyObjectID(objectID)
        }
    }
    
    func incomingMessageStarted(_ message: AbstractMessage) {
        businessInjector.entityManager.performBlockAndWait {
            if let pendingUserNotification = self.backgroundPendingUserNotificationManager.pendingUserNotification(
                for: message,
                stage: .abstract
            ) {
                self.show(
                    pendingUserNotification: pendingUserNotification,
                    pendingUserNotificationManager: self.backgroundPendingUserNotificationManager,
                    pushSettingManager: self.businessInjector.pushSettingManager,
                    groupManager: self.businessInjector.groupManager,
                    entityManager: self.businessInjector.entityManager
                )
            }
        }
    }
    
    func incomingMessageChanged(_ message: AbstractMessage, baseMessage: BaseMessage) {
        businessInjector.entityManager.performAndWaitSave {
            if let msg = self.businessInjector.entityManager.entityFetcher
                .getManagedObject(by: baseMessage.objectID) as? BaseMessage {
                if !AppDelegate.shared().active {
                    let databaseManager = DatabaseManager()
                    databaseManager.addDirtyObject(msg)
                    if let conversation = msg.conversation {
                        databaseManager.addDirtyObject(conversation)
                        if let contact = conversation.contact {
                            databaseManager.addDirtyObject(contact)
                        }
                    }
                }

                if let conversation = msg.conversation {
                    let totalCount = self.businessInjector.unreadMessages
                        .totalCount(doCalcUnreadMessagesCountOf: [conversation], withPerformBlockAndWait: false)
                    self.notificationManager.updateTabBarBadge(badgeTotalCount: totalCount)
                }

                if let pendingUserNotification = self.pendingUserNotificationManager.pendingUserNotification(
                    for: message,
                    baseMessage: msg,
                    stage: .base
                ) {
                    self.show(
                        pendingUserNotification: pendingUserNotification,
                        pendingUserNotificationManager: self.backgroundPendingUserNotificationManager,
                        pushSettingManager: self.businessInjector.pushSettingManager,
                        groupManager: self.businessInjector.groupManager,
                        entityManager: self.businessInjector.entityManager
                    )
                }
            }
        }
    }
    
    func incomingMessageFinished(_ message: AbstractMessage) {
        if let pendingUserNotification = pendingUserNotificationManager.pendingUserNotification(
            for: message,
            stage: .final
        ) {
            businessInjector.entityManager.performBlockAndWait {
                self.show(
                    pendingUserNotification: pendingUserNotification,
                    pendingUserNotificationManager: self.backgroundPendingUserNotificationManager,
                    pushSettingManager: self.businessInjector.pushSettingManager,
                    groupManager: self.businessInjector.groupManager,
                    entityManager: self.businessInjector.entityManager
                )
                .done(on: .global(), flags: .inheritQoS) { showed in
                    if showed {
                        self.backgroundPendingUserNotificationManager
                            .addAsProcessed(pendingUserNotification: pendingUserNotification)
                    }
                }
            }
        }
    }
    
    func readMessage(inConversations: Set<Conversation>?) {
        if let inConversations, !inConversations.isEmpty {
            businessInjector.unreadMessages.totalCount(doCalcUnreadMessagesCountOf: inConversations)
        }

        DispatchQueue.main.async {
            self.notificationManager.updateUnreadMessagesCount()
        }
    }

    func incomingMessageFailed(_ message: BoxedMessage) {
        if let pendingUserNotification = pendingUserNotificationManager.pendingUserNotification(
            for: message,
            stage: .initial
        ) {
            pendingUserNotificationManager.addAsProcessed(pendingUserNotification: pendingUserNotification)
            pendingUserNotificationManager
                .removeAllTimedUserNotifications(pendingUserNotification: pendingUserNotification)
        }
    }
    
    func incomingAbstractMessageFailed(_ message: AbstractMessage) {
        if let pendingUserNotification = pendingUserNotificationManager.pendingUserNotification(
            for: message,
            stage: .abstract
        ) {
            pendingUserNotificationManager.addAsProcessed(pendingUserNotification: pendingUserNotification)
            pendingUserNotificationManager
                .removeAllTimedUserNotifications(pendingUserNotification: pendingUserNotification)
        }
    }
    
    func incomingForwardSecurityMessageWithNoResultFinished(_ message: AbstractMessage) {
        if let pendingUserNotification = pendingUserNotificationManager.pendingUserNotification(
            for: message,
            stage: .abstract
        ) {
            pendingUserNotificationManager.addAsProcessed(pendingUserNotification: pendingUserNotification)
            pendingUserNotificationManager.removeAllTimedUserNotifications(
                pendingUserNotification: pendingUserNotification
            )
        }
        
        // Mark contact & conversation as dirty
        
        guard !AppDelegate.shared().active else {
            // Don't mark anything as dirty if the app is active
            return
        }
        
        businessInjector.entityManager.performAndWait {
            let databaseManager = DatabaseManager()
            
            if let contactEntity = self.businessInjector.entityManager.entityFetcher.contact(
                for: message.fromIdentity
            ) {
                databaseManager.addDirtyObject(contactEntity)
            }
            
            if let conversation = self.businessInjector.entityManager.entityFetcher.conversation(
                forIdentity: message.fromIdentity
            ) {
                databaseManager.addDirtyObject(conversation)
            }
        }
    }

    public func taskQueueEmpty(_ queueTypeName: String) {
        let queueType = TaskQueueType.queue(name: queueTypeName)
        if queueType == .incoming {
            if completionHandler != nil {
                DispatchQueue.global().async {
                    // Call completionHandler just once, will be set again for new push
                    self.completionHandler?()
                    self.completionHandler = nil
                }
            }
        }
        else if queueType == .outgoing {
            // Gives a little time to process delivery receipts
            // Cancel possible background task for sending message when the is in background
            DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(5)) {
                BackgroundTaskManager.shared.cancelBackgroundTask(key: kAppClosedByUserBackgroundTask)
            }
        }
    }

    public func chatQueueDry() { }
    
    public func reflectionQueueDry() { }
    
    public func processTypingIndicator(_ message: TypingIndicatorMessage) {
        TypingIndicatorManager.sharedInstance()?
            .setTypingIndicatorForIdentity(message.fromIdentity, typing: message.typing)
    }
    
    func processVoIPCall(
        _ message: NSObject,
        identity: String?,
        onCompletion: ((MessageProcessorDelegate) -> Void)? = nil
    ) {
        switch message {
        case is VoIPCallOfferMessage:
            guard let identity else {
                DDLogError("No contact for processing VoIP call offer.")
                break
            }
            
            VoIPCallStateManager.shared.incomingCallOffer(offer: message as! VoIPCallOfferMessage, identity: identity) {
                onCompletion?(self)
            }
        case is VoIPCallAnswerMessage:
            guard let identity else {
                DDLogError("No contact for processing VoIP call answer.")
                break
            }
            
            VoIPCallStateManager.shared.incomingCallAnswer(
                answer: message as! VoIPCallAnswerMessage,
                identity: identity
            ) {
                onCompletion?(self)
            }
        case is VoIPCallIceCandidatesMessage:
            guard let identity else {
                DDLogError("No contact for processing VoIP call ice candidates.")
                break
            }
            
            VoIPCallStateManager.shared.incomingIceCandidates(
                candidates: message as! VoIPCallIceCandidatesMessage,
                identity: identity
            ) {
                onCompletion?(self)
            }
        case is VoIPCallHangupMessage:
            VoIPCallStateManager.shared.incomingCallHangup(hangup: message as! VoIPCallHangupMessage)
            onCompletion?(self)
        case is VoIPCallRingingMessage:
            VoIPCallStateManager.shared.incomingCallRinging(ringing: message as! VoIPCallRingingMessage)
            onCompletion?(self)
        default:
            DDLogError("Message couldn't process as VoIP call.")
        }
    }
}
