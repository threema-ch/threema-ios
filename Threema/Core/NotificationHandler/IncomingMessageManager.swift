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
import ThreemaFramework

@objc class IncomingMessageManager: NSObject {
    
    @objc static let inAppNotificationNewMessage = "ThreemaNewMessageReceived"

    /// Using as main (context) configured manager (will be used when messages are processed in main thread)
    private let pendingUserNotificationManager: PendingUserNotificationManagerProtocol

    /// Using as background (context) configured manager (will be used when messages are processed in background, see: MessageProcessorDelegate)
    private let backgroundPendingUserNotificationManager: PendingUserNotificationManagerProtocol

    private let businessInjector: BusinessInjectorProtocol
    private let notificationManager: NotificationManager

    private var completionHandler: (() -> Void)?

    required init(
        pendingUserNotificationManager: PendingUserNotificationManagerProtocol,
        backgroundPendingUserNotificationManager: PendingUserNotificationManagerProtocol,
        businessInjector: BusinessInjectorProtocol
    ) {
        self.pendingUserNotificationManager = pendingUserNotificationManager
        self.backgroundPendingUserNotificationManager = backgroundPendingUserNotificationManager
        self.businessInjector = businessInjector
        self.notificationManager = NotificationManager(businessInjector: businessInjector)
    }
    
    @objc override convenience init() {
        let businessInjector = BusinessInjector()
        self.init(
            pendingUserNotificationManager: PendingUserNotificationManager(
                UserNotificationManager(
                    businessInjector.settingsStore,
                    UserSettings.shared(),
                    ContactStore.shared(),
                    businessInjector.groupManager,
                    businessInjector.entityManager,
                    LicenseStore.shared().getRequiresLicenseKey()
                ),
                businessInjector.entityManager
            ),
            backgroundPendingUserNotificationManager: PendingUserNotificationManager(
                UserNotificationManager(
                    businessInjector.settingsStore,
                    UserSettings.shared(),
                    ContactStore.shared(),
                    businessInjector.backgroundGroupManager,
                    businessInjector.backgroundEntityManager,
                    LicenseStore.shared().getRequiresLicenseKey()
                ),
                businessInjector.backgroundEntityManager
            ),
            businessInjector: businessInjector
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
        businessInjector.entityManager.performBlock {
            if let pendingUserNotificationsAreNotPending = self.pendingUserNotificationManager
                .pendingUserNotificationsAreNotPending() {
                for pendingUserNotification in pendingUserNotificationsAreNotPending {
                    self.show(
                        pendingUserNotification: pendingUserNotification,
                        pendingUserNotificationManager: self.pendingUserNotificationManager,
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
        entityManager: EntityManager
    ) -> Guarantee<Bool> {
        Guarantee { seal in
            if !AppDelegate.shared().active {
                manager
                    .startTimedUserNotification(pendingUserNotification: pendingUserNotification)
                    .done { started in
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
                
                guard !pendingUserNotification.isPendingGroup,
                      !manager.isProcessed(pendingUserNotification: pendingUserNotification)
                else {
                    manager
                        .removeAllTimedUserNotifications(pendingUserNotification: pendingUserNotification)
                    seal(true)
                    return
                }
                
                if let message = pendingUserNotification.baseMessage, pendingUserNotification.stage == .final,
                   pendingUserNotification.abstractMessage?.receivedAfterInitialQueueSend == true {
                    let pushSettingManager = PushSettingManager(
                        UserSettings.shared(),
                        LicenseStore.requiresLicenseKey()
                    )
                    if pushSettingManager.canMasterDndSendPush() {
                        entityManager.performBlock {
                            let pushSetting = PushSetting(for: message.conversation)
                            if pushSetting.canSendPush(for: message) {
                                let messageObjectID = message.objectID

                                DispatchQueue.main.async {
                                    NotificationCenter.default.post(
                                        name: NSNotification
                                            .Name(rawValue: IncomingMessageManager.inAppNotificationNewMessage),
                                        object: messageObjectID,
                                        userInfo: nil
                                    )
                                }

                                if !pushSetting.silent {
                                    self.notificationManager.playReceivedMessageSound()
                                }
                            }
                        }
                    }

                    manager
                        .removeAllTimedUserNotifications(pendingUserNotification: pendingUserNotification)

                    notificationManager.updateUnreadMessagesCount()
                    seal(true)
                    return
                }

                // Start timed user notification, will be removed on stage final anyway
                manager
                    .startTimedUserNotification(pendingUserNotification: pendingUserNotification)
                    .done { _ in
                        PendingUserNotificationManager.pendingQueue.sync {
                            self.notificationManager.updateUnreadMessagesCount()
                            seal(false)
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
        businessInjector.backgroundEntityManager.performBlockAndWait {
            if let pendingUserNotification = self.backgroundPendingUserNotificationManager.pendingUserNotification(
                for: message,
                stage: .abstract,
                isPendingGroup: false
            ) {
                self.show(
                    pendingUserNotification: pendingUserNotification,
                    pendingUserNotificationManager: self.backgroundPendingUserNotificationManager,
                    entityManager: self.businessInjector.backgroundEntityManager
                )
            }
        }
    }
    
    func incomingMessageChanged(_ message: BaseMessage, fromIdentity: String) {
        businessInjector.backgroundEntityManager.performBlockAndWait {
            if let msg = self.businessInjector.backgroundEntityManager.entityFetcher
                .getManagedObject(by: message.objectID) as? BaseMessage {
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
                    self.businessInjector.backgroundUnreadMessages
                        .totalCount(doCalcUnreadMessagesCountOf: [conversation])
                }

                if let pendingUserNotification = self.pendingUserNotificationManager.pendingUserNotification(
                    for: msg,
                    fromIdentity: fromIdentity,
                    stage: .base
                ) {
                    self.show(
                        pendingUserNotification: pendingUserNotification,
                        pendingUserNotificationManager: self.backgroundPendingUserNotificationManager,
                        entityManager: self.businessInjector.backgroundEntityManager
                    )
                }
            }
        }
    }
    
    func incomingMessageFinished(_ message: AbstractMessage, isPendingGroup: Bool) {
        if let pendingUserNotification = pendingUserNotificationManager.pendingUserNotification(
            for: message,
            stage: .final,
            isPendingGroup: isPendingGroup
        ) {
            businessInjector.backgroundEntityManager.performBlockAndWait {
                guard !pendingUserNotification.isPendingGroup else {
                    self.backgroundPendingUserNotificationManager
                        .removeAllTimedUserNotifications(pendingUserNotification: pendingUserNotification)

                    if let grpMsg = message as? AbstractGroupMessage, !AppDelegate.shared().isAppInBackground(),
                       let groupCreator = grpMsg.groupCreator,
                       !self.businessInjector.userSettings.blacklist.contains(groupCreator) {
                        self.businessInjector.backgroundGroupManager.unknownGroup(
                            groupID: grpMsg.groupID,
                            creator: grpMsg.groupCreator
                        )
                    }

                    return
                }

                self.show(
                    pendingUserNotification: pendingUserNotification,
                    pendingUserNotificationManager: self.backgroundPendingUserNotificationManager,
                    entityManager: self.businessInjector.backgroundEntityManager
                )
                .done { showed in
                    if showed {
                        self.backgroundPendingUserNotificationManager
                            .addAsProcessed(pendingUserNotification: pendingUserNotification)
                    }
                }
            }
        }
    }
    
    func readMessage(inConversations: Set<Conversation>?) {
        if let inConversations = inConversations, !inConversations.isEmpty {
            businessInjector.backgroundUnreadMessages.totalCount(doCalcUnreadMessagesCountOf: inConversations)
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
            stage: .abstract,
            isPendingGroup: false
        ) {
            pendingUserNotificationManager.addAsProcessed(pendingUserNotification: pendingUserNotification)
            pendingUserNotificationManager
                .removeAllTimedUserNotifications(pendingUserNotification: pendingUserNotification)
        }
    }

    public func taskQueueEmpty(_ queueTypeName: String) {
        let queueType = TaskQueueType.queue(name: queueTypeName)
        if queueType == .incoming {
            if completionHandler != nil {
                // Gives a littel time to remove notification from notification center
                // or has pending group messages (waiting for possible "group sync request" answer)
                let delay = !pendingUserNotificationManager.hasPendingGroupUserNotifications() ? 0 : 5
                DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(delay)) {
                    // Call completionHandler just once, will be set again for new push
                    self.completionHandler?()
                    self.completionHandler = nil
                }
            }
        }
        else if queueType == .outgoing {
            // Gives a littel time to process delivery receipts
            // Cancel possible background task for sending message when the is in background
            DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(5)) {
                BackgroundTaskManager.shared.cancelBackgroundTask(key: kAppClosedByUserBackgroundTask)
            }
        }
    }

    public func chatQueueDry() { }
    
    public func reflectionQueueDry() { }
    
    public func pendingGroup(_ message: AbstractMessage) {
        if let pendingUserNotification = pendingUserNotificationManager.pendingUserNotification(
            for: message,
            stage: .abstract,
            isPendingGroup: true
        ) {
            DDLogInfo("[Push] Group not found for pending user notification")

            pendingUserNotificationManager
                .removeAllTimedUserNotifications(pendingUserNotification: pendingUserNotification)

            DispatchQueue.main.async {
                self.notificationManager.updateUnreadMessagesCount()
            }
        }
    }
    
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
            guard let identity = identity else {
                DDLogError("No contact for processing VoIP call offer.")
                break
            }
            
            VoIPCallStateManager.shared.incomingCallOffer(offer: message as! VoIPCallOfferMessage, identity: identity) {
                onCompletion?(self)
            }
        case is VoIPCallAnswerMessage:
            guard let identity = identity else {
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
            guard let identity = identity else {
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
