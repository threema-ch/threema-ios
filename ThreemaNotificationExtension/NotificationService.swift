//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2025 Threema GmbH
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

import CallKit
import CocoaLumberjackSwift
import FileUtility
import Keychain
import PromiseKit
import RemoteSecret
import RemoteSecretProtocol
import ThreemaEssentials
import ThreemaFramework
import ThreemaMacros
import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    
    private static var isRunning = false
    private static var runningStartDate: Date?
    private static var didJustReportCall = false

    var contentHandler: ((UNNotificationContent) -> Void)?
    
    private var backgroundBusinessInjector: BusinessInjectorProtocol?
    private var pendingUserNotificationManager: PendingUserNotificationManagerProtocol?
    private var persistenceManager: PersistenceManager?

    private static var stopProcessingTimer: Timer?
    private static var stopProcessingGroup: DispatchGroup?

    private var isChatQueueDry = false
    private var isReflectionQueueDry = false

    private var conversationsChanged: Set<NSManagedObjectID>?
    private var conversationsChangedQueue =
        DispatchQueue(label: "ch.threema.NotificationService.conversationsChangedQueue")
    
    private let threemaPayloadKey = "threema"
    private let aliveCheckKey = "alive-check"
    private let pushTestKey = "push-test"
    
    private var observer: Any?

    /// Push received, every code path must call `contentHandler` (see `applyContent(...)`) at the end!
    /// - Parameters:
    ///   - request: Push request/payload
    ///   - contentHandler: Must be called before leaving this function
    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        PromiseKitConfiguration.configurePromiseKit()
        FileUtilityObjCSetter.setInitialFileUtility()

        AppGroup.setGroupID(BundleUtil.threemaAppGroupIdentifier())
        AppGroup.setAppID(BundleUtil.mainBundle()?.bundleIdentifier)

        #if DEBUG
            LogManager.initializeGlobalLogger(debug: true)
        #else
            LogManager.initializeGlobalLogger(debug: false)
        #endif

        DebugLog.logAppVersion()

        // Initialize content handler to show any notification
        self.contentHandler = contentHandler

        guard !NotificationService.didJustReportCall else {
            ServerConnector.shared().disconnect(initiator: .notificationExtension)

            DDLogNotice("[Push] Suppressing push because we have just reported an incoming call")
            applyContent()
            return
        }

        // Make timer invalid, to prevent stopping processing
        DispatchQueue.main.async {
            NotificationService.stopProcessingTimer?.invalidate()
        }
        
        // Suppressing push if notification extension is still running and running date is not older then 25 seconds
        if NotificationService.isRunning,
           let startDate = NotificationService.runningStartDate,
           Date().timeIntervalSince(startDate) < kNSETimeout {
            DDLogNotice("[Push] Suppressing push because Notification Extension is still running")
            
            let emptyContent = UNMutableNotificationContent()
            contentHandler(emptyContent)
            
            return
        }
        
        // Set the running start date to check if its older then 25 seconds
        NotificationService.runningStartDate = Date()
        NotificationService.isRunning = true

        // Checking database file exists as early as possible
        AppSetup.registerIfADatabaseFileExists()

        DDLogNotice("[Push] Notification did receive: \(request.content)")
        
        logMemoryUsage()

        // Drop shared instance in order to adapt to user's configuration changes
        UserSettings.resetSharedInstance()
        
        extensionIsReady { businessInjector in
            guard let businessInjector else {
                // Content apply is called in `extensionIsReady` if it returns `nil`
                return
            }

            // Set BusinessInjector intended to be used by the `MessageProcessorDelegate` functions and `applyContent`
            self.backgroundBusinessInjector = businessInjector

            // Delete all files and directories from temporary app directory
            FileUtility.shared.removeItemsInDirectory(directoryURL: FileUtility.shared.appTemporaryDirectory)

            guard let bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent) else {
                self.applyContent(recalculateBadgeCount: false)
                return
            }
            
            self.receiveWithReadyExtension(bestAttemptContent: bestAttemptContent, businessInjector: businessInjector)
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push
        // payload will be used.
        DDLogWarn("[Push] Stopping processing incoming messages, because extension will expire!")
        exitIfAllTasksProcessed(force: true, willExpire: true)
    }
    
    // MARK: Private functions
    
    private func receiveWithReadyExtension(
        bestAttemptContent: UNMutableNotificationContent,
        businessInjector: BusinessInjectorProtocol
    ) {

        guard let threemaDictEntcrypted = bestAttemptContent.userInfo[threemaPayloadKey],
              let threemaDict = PushPayloadDecryptor.decryptPushPayload(threemaDictEntcrypted as? [AnyHashable: Any])
        else {
            notThreemaDictInPayload(bestAttemptContent, businessInjector: businessInjector)
            return
        }
                    
        DDLogInfo("[Push] Request threema push: \(threemaDict)")
        
        let isAliveCheck: Bool = ((threemaDict[aliveCheckKey] as? Int) != nil)
        let isPushTest: Bool = ((threemaDict[pushTestKey] as? Int) != nil)
        let threemaPushNotification = try? ThreemaPushNotification(from: threemaDict as! [String: Any])
        
        guard !isPushTest else {
            // Show test notification (necessary for customer support)
            showTestNotification(bestAttemptContent, businessInjector: businessInjector)
            return
        }
        
        if threemaPushNotification != nil || isAliveCheck {
            // Refresh all DB objects before access it
            persistenceManager?.dirtyObjectManager.refreshAllObjects()
            businessInjector.entityManager.refreshAllObjects()

            businessInjector.contactStore.resetEntityManager()

            if let senderIdentity = threemaPushNotification?.from,
               let hexStringOfmessageID = threemaPushNotification?.messageID,
               let messageID = BytesUtility.toData(hexString: hexStringOfmessageID) {

                guard !businessInjector.entityManager.entityFetcher
                    .isMessageDelivered(from: senderIdentity, with: messageID) else {
                    DDLogWarn("[Push] Suppressing push because message is already processed")
                    applyContent()
                    return
                }
            }

            // Exit if connected already
            if businessInjector.serverConnector.connectionState == .connecting ||
                businessInjector.serverConnector.connectionState == .connected ||
                businessInjector.serverConnector.connectionState == .loggedIn {
                DDLogWarn("[Push] Suppressing push because already connected")
                applyContent()
                return
            }
            
            // For some users sometimes an invalid Core Data entity was created and prevented saving of any new changes
            // even after the notification extension was exited in the meantime. Only a device restart would resolve
            // this. Because saving errors in Core Data are not propagated (IOS-5256) this could lead to lost messages.
            // To prevent this we roll back the Core Data contexts on each notification extension execution which
            // removes any invalid & unsaved entity. See IOS-5204 for details.
            // TODO: (IOS-5256) Remove this again
            businessInjector.entityManager.fullRollback()

            businessInjector.serverConnector
                .backgroundEntityManagerForMessageProcessing = businessInjector.entityManager

            // TODO: (IOS-4677) Shouldn't we always process GC messages?
            if businessInjector.settingsStore.enableThreemaGroupCalls {
                GlobalGroupCallManagerSingleton.injectedBackgroundBusinessInjector = businessInjector
            }
            
            pendingUserNotificationManager = PendingUserNotificationManager(
                userNotificationManager: UserNotificationManager(
                    settingsStore: businessInjector.settingsStore,
                    userSettings: businessInjector.userSettings,
                    myIdentityStore: businessInjector.myIdentityStore,
                    pushSettingManager: businessInjector.pushSettingManager,
                    contactStore: businessInjector.contactStore,
                    groupManager: businessInjector.groupManager,
                    entityManager: businessInjector.entityManager,
                    isWorkApp: TargetManager.isBusinessApp
                ),
                pushSettingManager: businessInjector.pushSettingManager,
                entityManager: businessInjector.entityManager
            )
            
            // Create pendingUserNotification only for message notifications, not for keep alive checks
            // Keep alive check will connect to the server, because if the last connection was too long ago, the
            // server sets the identity as inactive
            if let threemaPushNotification {
                if threemaPushNotification.voip == false {
                    if let pendingUserNotification = pendingUserNotificationManager?
                        .pendingUserNotification(
                            for: threemaPushNotification,
                            stage: .initial
                        ) {
                        _ = pendingUserNotificationManager?
                            .startTimedUserNotification(pendingUserNotification: pendingUserNotification)
                    }
                }
            }
            else {
                DDLogInfo("[Push] Alive check")
            }
            
            // Start processing incoming messages and wait (max. 25s kNSETimeout)
            DDLogNotice("[Push] Enter the stopProcessingGroup")
            NotificationService.stopProcessingGroup = DispatchGroup()
            NotificationService.stopProcessingGroup?.enter()
            
            // We observe for invalid license
            observer = NotificationCenter.default.addObserver(
                forName: Notification.Name(rawValue: kNotificationLicenseMissing),
                object: nil,
                queue: nil
            ) { [weak self] _ in
                self?.addInvalidLicenseKeyNotification(removingInitialPushFor: threemaPushNotification)
            }
            
            DispatchQueue.global().async {
                // Initialize conversation changed for calc unread messages badge count
                self.conversationsChangedQueue.async {
                    self.conversationsChanged = Set<NSManagedObjectID>()
                }
                
                // Register message processor delegate and connect to server
                businessInjector.serverConnector.registerMessageProcessorDelegate(delegate: self)
                businessInjector.serverConnector.registerConnectionStateDelegate(delegate: self)

                if !businessInjector.userSettings.ipcCommunicationEnabled {
                    AppGroup.setMeActive()
                }

                businessInjector.serverConnector
                    .connect(initiator: .notificationExtension) { isConnecting in
                        if !isConnecting {
                            DDLogNotice("[Push] Not connecting do forced exit")
                            self.exitIfAllTasksProcessed(force: true, willExpire: true)
                        }
                    }
            }
            
            let result = NotificationService.stopProcessingGroup?.wait(timeout: .now() + kNSETimeout)
            if result != .success {
                DDLogWarn("[Push] Stopping processing incoming messages, because time is up!")
                
                if NotificationService.didJustReportCall {
                    DDLogError("[Push] Stopped processing incoming messages, but we were reporting a call!")
                    NotificationService.didJustReportCall = false
                }
            }
            
            businessInjector.serverConnector.unregisterMessageProcessorDelegate(delegate: self)
            businessInjector.serverConnector.unregisterConnectionStateDelegate(delegate: self)
            businessInjector.serverConnector.disconnectWait(initiator: .notificationExtension)
        }
        
        if isAliveCheck {
            let emptyContent = UNMutableNotificationContent()
            emptyContent.userInfo = bestAttemptContent.userInfo
            applyContent(emptyContent)
        }
        else {
            applyContent()
        }
    }
    
    /// Apply notification content or suppress it.
    /// For muted groups update badge count here.
    ///
    /// - Parameters:
    ///   - bestAttemptContent: Best content for notification, is nil no notification will be shown
    ///   - recalculateBadgeCount: If `true` count of unread messages will calculated for changed conversations
    ///                            (`NotificationService.conversationsChanged`)
    private func applyContent(
        _ bestAttemptContent: UNMutableNotificationContent? = nil,
        recalculateBadgeCount: Bool = true
    ) {
        NotificationService.isRunning = false
        DDLogNotice("[Push] isRunning set to false from apply.")
        
        var badge: Int?
        if recalculateBadgeCount, let backgroundBusinessInjector {
            badge = conversationsChangedQueue.sync {
                var recalculateConversations: Set<ConversationEntity>?
                if let conversationsChanged, let conversations = backgroundBusinessInjector.entityManager.entityFetcher
                    .notArchivedConversationEntities() {

                    recalculateConversations = Set(conversations.filter { conversationsChanged.contains($0.objectID) })
                }

                return if let recalculateConversations, !recalculateConversations.isEmpty {
                    backgroundBusinessInjector.unreadMessages
                        .totalCount(doCalcUnreadMessagesCountOf: Set(recalculateConversations))
                }
                else {
                    backgroundBusinessInjector.unreadMessages.totalCount()
                }
            }
            DDLogNotice("[Push] Unread messages: \(badge)")
        }
        
        logMemoryUsage()
        
        // Remove observer if there is any
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }

        if !UserSettings.shared().ipcCommunicationEnabled {
            AppGroup.setMeInactive()
        }

        if let bestAttemptContent {
            DDLogInfo("[Push] Notification shown!")
            DDLog.flushLog()

            if let badge {
                bestAttemptContent.badge = NSNumber(integerLiteral: badge)
            }
            
            contentHandler?(bestAttemptContent)
        }
        else {
            DDLogInfo("[Push] Notification suppressed!")
            DDLog.flushLog()

            let emptyContent = UNMutableNotificationContent()
            
            if let badge {
                emptyContent.badge = NSNumber(integerLiteral: badge)
            }
            
            contentHandler?(emptyContent)
        }
    }

    // Implemented with a completion handler because the entry point of the notification extension isn't async
    private func extensionIsReady(completion: @escaping (BusinessInjectorProtocol?) -> Void) {
        MyIdentityStore.resetSharedInstance()

        Task {
            do {
                let remoteSecretManager = try await AppLaunchManager.shared.initializeRemoteSecret(
                    navigationController: nil,
                    onDelete: nil,
                    onCancel: nil
                )
                
                DebugLog.logAppConfiguration()

                let databaseManager = AppLaunchManager.shared
                    .initializeDatabaseManager(remoteSecretManager: remoteSecretManager)

                self.persistenceManager = PersistenceManager(
                    appGroupID: AppGroup.groupID(),
                    userDefaults: AppGroup.userDefaults(),
                    remoteSecretManager: AppLaunchManager.remoteSecretManager
                )

                // TODO: (IOS-5305) Move keychain manager creation out of here
                let keychainManager = KeychainManager(remoteSecretManager: remoteSecretManager)

                // Hack to make BI work
                if let identity = try? keychainManager.loadIdentity() {
                    MyIdentityStore.shared().setupIdentity(identity)
                }

                if let license = try? keychainManager.loadLicense() {
                    LicenseStore.shared().licenseUsername = license.user
                    LicenseStore.shared().licensePassword = license.password
                    LicenseStore.shared().licenseDeviceID = license.deviceID ?? ""
                    LicenseStore.shared().onPremConfigURL = license.onPremServer
                }
                
                // TODO: (IOS-5579) Check if this is still needed with full OPPF caching
                // After the license is set we can fetch the OPPF
                // Reset pinned certificates to ensure we (also) use pins from OPPF for OnPrem flavor apps
                if TargetManager.isOnPrem || TargetManager.isCustomOnPrem {
                    NotificationCenter.default.post(name: .resetSSLCAHelperCache, object: nil)
                }

                let businessInjector = try AppLaunchManager.shared.business(
                    remoteSecretManager: remoteSecretManager,
                    databaseManager: databaseManager,
                    myIdentityStore: MyIdentityStore.shared(),
                    forBackgroundProcess: true
                )
                
                completion(businessInjector)
            }
            catch let error as RemoteSecretManagerError {
                DDLogWarn("[Push] Remote secret error: \(error.description)")
                
                showAppNotReadyLocalNotification { [weak self] in
                    self?.applyContent(nil, recalculateBadgeCount: false)
                    completion(nil)
                }
            }
            catch {
                DDLogWarn("[Push] Business injector is not ready to use: \(error)")
                
                showAppNotReadyLocalNotification { [weak self] in
                    self?.applyContent(nil, recalculateBadgeCount: false)
                    completion(nil)
                }
            }
        }
    }

    /// Exit Notification Extension if all tasks processed.
    /// - Parameters:
    ///   - force: Means last incoming task is processed, exit anyway
    ///   - reportedCall: Exit due to Threema Call was reported to the App, `NotificationService.didJustReportCall` will
    ///                   be set to `true` for 5s
    ///   - willExpire: If function is called from `serviceExtensionTimeWillExpire`
    private func exitIfAllTasksProcessed(force: Bool = false, reportedCall: Bool = false, willExpire: Bool = false) {
        let isMultiDeviceRegistered = UserSettings.shared().enableMultiDevice
        if force ||
            (
                isChatQueueDry &&
                    (!isMultiDeviceRegistered || (isMultiDeviceRegistered && isReflectionQueueDry)) &&
                    TaskManager.isEmpty()
            ) {
            DDLogNotice(
                "[Push] Stopping process incoming messages (force: \(force), reportedCall: \(reportedCall) willExpire: \(willExpire)), because receive message queue finished or chat/reflection queue is dry!"
            )
            DDLog.flushLog()

            guard !willExpire else {
                NotificationService.stopProcessingTimer?.invalidate()
                NotificationService.didJustReportCall = false
                DDLogNotice("[Push] Leave Processing Group")
                NotificationService.stopProcessingGroup?.leave()
                NotificationService.stopProcessingGroup = nil
                NotificationService.isRunning = false
                DDLogNotice("[Push] isRunning set to false from exit.")
                return
            }
            
            if reportedCall {
                DDLogNotice("[Push] Set didJustReportCall")
                NotificationService.didJustReportCall = reportedCall
            }

            DispatchQueue.main.async {
                NotificationService.stopProcessingTimer?.invalidate()
                NotificationService.stopProcessingTimer = Timer.scheduledTimer(
                    withTimeInterval: 2, // Gives a little time to remove notification from notification center
                    repeats: false,
                    block: { _ in
                        if NotificationService.didJustReportCall {
                            DDLogNotice("[Push] didJustReportCall timer will start")
                            Timer.scheduledTimer(
                                withTimeInterval: 5,
                                repeats: false,
                                block: { _ in
                                    DDLogNotice("[Push] Reset didJustReportCall")
                                    NotificationService.didJustReportCall = false
                                }
                            )
                        }

                        DDLogNotice("[Push] Leave Processing Group")
                        NotificationService.stopProcessingGroup?.leave()
                        NotificationService.stopProcessingGroup = nil
                        NotificationService.isRunning = false
                        DDLogNotice("[Push] isRunning set to false from exit.")
                    }
                )
            }
        }
    }

    private func addInvalidLicenseKeyNotification(
        removingInitialPushFor threemaPushNotification: ThreemaPushNotification?
    ) {
        DDLogWarn("[Push] Show invalid license key notification")
        
        // We remove the pending notification if it exists
        if let threemaPushNotification,
           let pendingUserNotification = (
               pendingUserNotificationManager?
                   .pendingUserNotification(for: threemaPushNotification, stage: .initial)
           ) {
            pendingUserNotificationManager?
                .removeAllTimedUserNotifications(pendingUserNotification: pendingUserNotification)
        }

        DDLogNotice("[Push] Left the stopProcessingGroup because there is no valid license")
        NotificationService.stopProcessingGroup?.leave()
        NotificationService.stopProcessingGroup = nil

        let content = UNMutableNotificationContent()
        content.body = #localize("new_message_invalid_license")
        applyContent(content)
    }
    
    /// Reports incoming call to iOS, if originating identity is not blocked.
    /// - Parameters:
    ///   - payload: Payload to be reported
    ///   - message: Incoming VoIP call offer message
    ///   - identity: Originating Identity
    ///   - businessInjector: `BusinessInjector` from init in the launch of the extension
    ///   - onCompletion: Return `self` to prevent deadlock
    ///   - onError: Return error and `self` to prevent deadlock
    private func reportVoIPCall(
        for payload: [String: String],
        message: VoIPCallOfferMessage,
        from identity: String?,
        businessInjector: BusinessInjectorProtocol,
        onCompletion: @escaping ((MessageProcessorDelegate) -> Void),
        onError: @escaping (any Error, any MessageProcessorDelegate) -> Void
    ) {
        guard !KeychainManager.isKeychainLocked else {
            onCompletion(self)
            return
        }
        
        // Check if VoIP calls are allowed
        guard ThreemaEnvironment.supportsCallKit() else {
            onCompletion(self)
            return
        }
        
        // Check if blocked
        guard let identity,
              !businessInjector.userSettings.blacklist.contains(identity) else {
            onCompletion(self)
            return
        }

        // Call forced exit here with reported call, this set didJustReportCall and prevent adding new tasks within
        // Notification Extension
        exitIfAllTasksProcessed(force: true, reportedCall: true)

        // Remove all incoming tasks. All further messages must be processed by the App
        TaskManager.interrupt()

        // Cancel the actual task processing of Offer message, because this message must be processed from the App
        // again!
        onError(ThreemaProtocolError.doNotProcessOfferMessageInNotificationExtension, self)

        DDLogNotice("[Push] will Report Incoming VoIP Push Payload to OS.")
        CXProvider.reportNewIncomingVoIPPushPayload(payload) { error in
            if let error {
                DDLogError("[Push] Incoming VoIP Push Payload, system disallow the call: \(error)")
            }
            else {
                DDLogNotice("[Push] Incoming VoIP Push Payload reported")
            }
        }
    }

    private func logMemoryUsage() {
        let memoryTotal = ByteCountFormatter.string(
            fromByteCount: Int64(DeviceUtility.getTotalMemory()),
            countStyle: .memory
        )
        let memoryInUse = ByteCountFormatter.string(
            fromByteCount: Int64(DeviceUtility.getUsageMemory() ?? 0.0),
            countStyle: .memory
        )
        DDLogNotice("[Push] Memory: \(memoryTotal) in use \(memoryInUse)")
    }
    
    private func showAppNotReadyLocalNotification(onCompletion: @escaping () -> Void) {
        let title = #localize("new_message_no_access_title")
        let message = String.localizedStringWithFormat(
            #localize("new_message_no_access_message"),
            TargetManager.appName
        )
        
        ThreemaUtility.showLocalNotification(
            identifier: "NotificationExtensionAppNotReady",
            title: title,
            body: message,
            badge: 1,
            userInfo: nil,
            completionHandler: onCompletion
        )
    }
    
    /// Will apply the test message content
    /// - Parameters:
    ///   - bestAttemptContent: UNMutableNotificationContent
    ///   - businessInjector: `BusinessInjector` from init in the launch of the extension
    private func showTestNotification(
        _ bestAttemptContent: UNMutableNotificationContent,
        businessInjector: BusinessInjectorProtocol
    ) {
        pendingUserNotificationManager = PendingUserNotificationManager(
            userNotificationManager: UserNotificationManager(
                settingsStore: businessInjector.settingsStore,
                userSettings: businessInjector.userSettings,
                myIdentityStore: businessInjector.myIdentityStore,
                pushSettingManager: businessInjector.pushSettingManager,
                contactStore: businessInjector.contactStore,
                groupManager: businessInjector.groupManager,
                entityManager: businessInjector.entityManager,
                isWorkApp: TargetManager.isBusinessApp
            ),
            pushSettingManager: businessInjector.pushSettingManager,
            entityManager: businessInjector.entityManager
        )
        
        pendingUserNotificationManager?.startTestUserNotification(
            payload: bestAttemptContent.userInfo,
            completion: {
                DDLogInfo("[Push] Test notification shown!")
                
                let emptyContent = UNMutableNotificationContent()
                bestAttemptContent.badge = 999
                self.applyContent(emptyContent)
            }
        )
    }
    
    /// Will apply a empty content or threema web content (if 3mw is in payload)
    /// - Parameters:
    ///   - bestAttemptContent: UNMutableNotificationContent
    ///   - businessInjector: `BusinessInjector` from init in the launch of the extension
    private func notThreemaDictInPayload(
        _ bestAttemptContent: UNMutableNotificationContent,
        businessInjector: BusinessInjectorProtocol
    ) {
        DDLogWarn("[Push] Missing threema key in payload")

        pendingUserNotificationManager = PendingUserNotificationManager(
            userNotificationManager: UserNotificationManager(
                settingsStore: businessInjector.settingsStore,
                userSettings: businessInjector.userSettings,
                myIdentityStore: businessInjector.myIdentityStore,
                pushSettingManager: businessInjector.pushSettingManager,
                contactStore: businessInjector.contactStore,
                groupManager: businessInjector.groupManager,
                entityManager: businessInjector.entityManager,
                isWorkApp: TargetManager.isBusinessApp
            ),
            pushSettingManager: businessInjector.pushSettingManager,
            entityManager: businessInjector.entityManager
        )
        
        if bestAttemptContent.userInfo["3mw"] is [AnyHashable: Any] {
            DDLogInfo("[Push] Configure Threema Web notification")
            // Use applyContent to set the badge with the count of unread messages
            let content = pendingUserNotificationManager?
                .editThreemaWebNotification(payload: bestAttemptContent.userInfo)
            applyContent(content)
        }
        else {
            applyContent()
        }
    }

    private func updateNotificationContent(
        for message: VoIPCallHangupMessage,
        businessInjector: BusinessInjectorProtocol
    ) {
        guard let contactIdentity = message.contactIdentity else {
            DDLogError("Cannot update local notification without contact identity")
            return
        }

        let contact = businessInjector.entityManager.entityFetcher.contactEntity(for: contactIdentity)
        let notificationType = businessInjector.settingsStore.notificationType
        let content = UNMutableNotificationContent()

        if case .restrictive = notificationType {
            if let publicNickname = contact?.publicNickname,
               !publicNickname.isEmpty {
                content.title = publicNickname
            }
            else {
                content.title = contactIdentity
            }
        }
        else {
            if let displayName = contact?.displayName {
                content.title = displayName
            }
        }

        content.body = #localize("call_missed")

        // Group notifications together with others from the same contact
        content.threadIdentifier = "SINGLE-\(contactIdentity)"
        applyContent(content)
    }
}

// MARK: - MessageProcessorDelegate

extension NotificationService: MessageProcessorDelegate {
    func beforeDecode() { }

    func changedManagedObjectID(_ objectID: NSManagedObjectID) {
        persistenceManager?.dirtyObjectManager.markAsDirty(objectID: objectID) {
            AppGroup.notifySyncNeeded()
        }
    }
    
    func incomingMessageStarted(_ message: AbstractMessage) {
        guard let backgroundBusinessInjector else {
            DDLogError("BusinessInjector is not ready")
            return
        }

        backgroundBusinessInjector.entityManager.performAndWait {
            let msgID = message.messageID.hexString
            DDLogNotice("[Push] Message processor started for message id: \(msgID)")

            if let pendingUserNotification = self.pendingUserNotificationManager?.pendingUserNotification(
                for: message,
                stage: .abstract
            ) {
                DDLogInfo("[Push] Message processor started for message id: \(msgID) found")
                _ = self.pendingUserNotificationManager?
                    .startTimedUserNotification(pendingUserNotification: pendingUserNotification)
            }
        }
    }
    
    func incomingMessageChanged(_ message: AbstractMessage, baseMessageEntity baseMessageEntityObject: NSObject) {
        guard let backgroundBusinessInjector else {
            DDLogError("BusinessInjector is not ready")
            return
        }

        backgroundBusinessInjector.entityManager.performAndWait {
            let baseMessage = baseMessageEntityObject as! BaseMessageEntity

            if let msg = backgroundBusinessInjector.entityManager.entityFetcher
                .managedObject(with: baseMessage.objectID) as? BaseMessageEntity {
                let msgID = msg.id.hexString
                DDLogNotice("[Push] Message processor changed for message id: \(msgID)")

                self.persistenceManager?.dirtyObjectManager.markAsDirty(objectID: msg.objectID) {
                    AppGroup.notifySyncNeeded()
                }

                backgroundBusinessInjector.unreadMessages
                    .totalCount(doCalcUnreadMessagesCountOf: [msg.conversation])

                // Add conversation as change to recalculate unread messages
                self.conversationsChangedQueue.async {
                    self.conversationsChanged?.insert(msg.conversation.objectID)
                }
                
                if let pendingUserNotification = self.pendingUserNotificationManager?.pendingUserNotification(
                    for: message,
                    baseMessage: msg,
                    stage: .base
                ) {
                    DDLogInfo("[Push] Message processor changed for message id: \(msgID) found")
                    _ = self.pendingUserNotificationManager?
                        .startTimedUserNotification(pendingUserNotification: pendingUserNotification)
                }
            }
        }
    }
    
    func incomingMessageFinished(_ message: AbstractMessage) {
        guard let backgroundBusinessInjector else {
            DDLogError("BusinessInjector is not ready")
            return
        }

        backgroundBusinessInjector.entityManager.performAndWait {
            let msgID = message.messageID.hexString
            DDLogNotice("[Push] Message processor finished for message id: \(msgID)")

            if let pendingUserNotification = self.pendingUserNotificationManager?.pendingUserNotification(
                for: message,
                stage: .final
            ) {
                DDLogNotice("[Push] Message processor finished for message id: \(msgID) found")
                self.pendingUserNotificationManager?
                    .startTimedUserNotification(pendingUserNotification: pendingUserNotification)
                    .done(on: .global(), flags: .inheritQoS) { showed in
                        if showed {
                            self.pendingUserNotificationManager?
                                .addAsProcessed(pendingUserNotification: pendingUserNotification)
                            DDLogNotice("[Push] Notification shown for message id: \(msgID)")
                        }

                        DDLogNotice("[Push] Notification processed for message id: \(msgID)")
                    }
            }
        }
    }

    func readMessage(inConversations: Set<AnyHashable>?) {
        let conversations = inConversations as! Set<ConversationEntity>

        conversationsChangedQueue.async {
            for conversation in conversations {
                self.conversationsChanged?.insert(conversation.objectID)
            }
        }
    }
    
    func incomingMessageFailed(_ message: BoxedMessage) {
        if let pendingUserNotification = pendingUserNotificationManager?.pendingUserNotification(
            for: message,
            stage: .initial
        ) {
            pendingUserNotificationManager?.addAsProcessed(pendingUserNotification: pendingUserNotification)
            pendingUserNotificationManager?
                .removeAllTimedUserNotifications(pendingUserNotification: pendingUserNotification)
        }
    }
    
    func incomingAbstractMessageFailed(_ message: AbstractMessage) {
        if let pendingUserNotification = pendingUserNotificationManager?.pendingUserNotification(
            for: message,
            stage: .abstract
        ) {
            pendingUserNotificationManager?.addAsProcessed(pendingUserNotification: pendingUserNotification)
            pendingUserNotificationManager?
                .removeAllTimedUserNotifications(pendingUserNotification: pendingUserNotification)
        }
    }
    
    func incomingForwardSecurityMessageWithNoResultFinished(_ message: AbstractMessage) {
        // Remove notification
        if let pendingUserNotification = pendingUserNotificationManager?.pendingUserNotification(
            for: message,
            stage: .abstract
        ) {
            pendingUserNotificationManager?.addAsProcessed(pendingUserNotification: pendingUserNotification)
            pendingUserNotificationManager?.removeAllTimedUserNotifications(
                pendingUserNotification: pendingUserNotification
            )
        }
        
        guard let backgroundBusinessInjector else {
            DDLogError("BusinessInjector is not ready")
            return
        }

        // Mark contact & conversation as dirty (1:1 conversation is needed if any status messages were added and the
        // conversation was shown when the app was backgrounded)
        backgroundBusinessInjector.entityManager.performAndWait {
            if let contactEntity = backgroundBusinessInjector.entityManager.entityFetcher.contactEntity(
                for: message.fromIdentity
            ) {
                self.persistenceManager?.dirtyObjectManager.markAsDirty(objectID: contactEntity.objectID) {
                    AppGroup.notifySyncNeeded()
                }
            }
            
            if let conversation = backgroundBusinessInjector.entityManager.entityFetcher.conversationEntity(
                for: message.fromIdentity
            ) {
                self.persistenceManager?.dirtyObjectManager.markAsDirty(objectID: conversation.objectID) {
                    AppGroup.notifySyncNeeded()
                }
            }
        }
    }
    
    func taskQueueEmpty() {
        exitIfAllTasksProcessed(force: true)
    }
    
    func chatQueueDry() {
        DDLogNotice("[Push] Message processor chat queue is dry")
        isChatQueueDry = true
        exitIfAllTasksProcessed()
    }
    
    func reflectionQueueDry() {
        DDLogNotice("[Push] Message processor reflection queue is dry")
        isReflectionQueueDry = true
        exitIfAllTasksProcessed()
    }
    
    func processTypingIndicator(_ message: TypingIndicatorMessage) { }
    
    func processVoIPCall(
        _ message: NSObject,
        identity: String?,
        onCompletion: @escaping ((any MessageProcessorDelegate)?) -> Void,
        onError: @escaping (any Error, (any MessageProcessorDelegate)?) -> Void
    ) {
        guard let backgroundBusinessInjector else {
            onError(AppLaunchManager.AppLaunchError.businessInjectorNotReady, self)
            return
        }

        switch message {
        case is VoIPCallOfferMessage:
            let offerMessage = message as! VoIPCallOfferMessage
            
            guard let identity else {
                DDLogError("No contact for processing VoIP call offer.")
                onCompletion(self) // Discard message
                return
            }
            guard backgroundBusinessInjector.userSettings.enableThreemaCall else {
                offerMessage.contactIdentity = identity
                rejectCall(offer: offerMessage)
                onCompletion(self) // Discard message
                return
            }
            guard backgroundBusinessInjector.pushSettingManager.canMasterDndSendPush() else {
                offerMessage.contactIdentity = identity
                rejectCall(offer: offerMessage, rejectReason: .offHours)
                onCompletion(self) // Discard message
                return
            }
            
            // In the context of Framework tests, setting the permission is not feasible. Consequently, we must
            // disregard this guard.
            guard AVAudioApplication.shared.recordPermission == .granted || ProcessInfoHelper.isRunningForTests else {
                offerMessage.contactIdentity = identity
                rejectCall(offer: offerMessage, rejectReason: .unknown)
                
                ThreemaUtility
                    .sendMicrophonePermissionErrorLocalNotification(
                        entityManager: backgroundBusinessInjector
                            .entityManager
                    )

                onCompletion(self) // Discard message
                return
            }
            
            let displayName: String =
                if identity == backgroundBusinessInjector.myIdentityStore.identity {
                    #localize("me")
                }
                else {
                    backgroundBusinessInjector.entityManager.entityFetcher.contactEntity(for: identity)?
                        .displayName ?? identity
                }
                    
            let pushSettingManager = backgroundBusinessInjector.pushSettingManager
            let pushSetting = pushSettingManager.find(forContact: ThreemaIdentity(identity))
           
            var ringtoneSound: String
            if pushSetting.canSendPush(), pushSetting.muted == false {
                ringtoneSound = UserSettings.shared()?.voIPSound ?? "default"
                if ringtoneSound != "default" {
                    ringtoneSound = "\(ringtoneSound).caf"
                }
            }
            else {
                ringtoneSound = "silent.mp3"
            }
            
            reportVoIPCall(
                for: [
                    Constants.notificationExtensionOffer: identity,
                    Constants.notificationExtensionCallerName: displayName,
                    Constants.notificationExtensionRingtoneSoundName: ringtoneSound,
                    Constants.notificationExtensionCallID: String(offerMessage.callID.callID),
                ],
                message: message as! VoIPCallOfferMessage,
                from: identity,
                businessInjector: backgroundBusinessInjector,
                onCompletion: onCompletion,
                onError: onError
            )
            
        case let message as VoIPCallHangupMessage:
            CallSystemMessageHelper
                .maybeAddMissedCallNotificationToConversation(
                    with: message,
                    on: backgroundBusinessInjector
                ) { _, systemMessage in
                    if let systemMessage {
                        guard let backgroundBusinessInjector = self.backgroundBusinessInjector else {
                            onError(AppLaunchManager.AppLaunchError.businessInjectorNotReady, self)
                            return
                        }

                        backgroundBusinessInjector.entityManager.performAndWait {
                            self.persistenceManager?.dirtyObjectManager.markAsDirty(objectID: systemMessage.objectID) {
                                AppGroup.notifySyncNeeded()
                            }
                        }

                        self.updateNotificationContent(for: message, businessInjector: backgroundBusinessInjector)
                    }
                    
                    onCompletion(self)
                }

        default:
            DDLogError("Message couldn't be processed as VoIP call.")
            onCompletion(self) // Discard message
        }
    }
    
    /// Reject call because Threema Calls are disabled on this device
    /// - Parameter offer: VoIPCallOfferMessage
    /// - Parameter rejectReason: Reject reason (Default: .disabled)
    private func rejectCall(
        offer: VoIPCallOfferMessage,
        rejectReason: VoIPCallAnswerMessage.MessageRejectReason = .disabled
    ) {
        guard let backgroundBusinessInjector else {
            DDLogError("BusinessInjector is not ready")
            return
        }

        let voIPCallSender = VoIPCallSender(
            messageSender: backgroundBusinessInjector.messageSender,
            myIdentityStore: backgroundBusinessInjector.myIdentityStore
        )
        let reason: VoIPCallAnswerMessage.MessageRejectReason = rejectReason
        let answer = VoIPCallAnswerMessage(
            action: .reject,
            answer: nil,
            rejectReason: reason,
            features: nil,
            isVideoAvailable: false,
            isUserInteraction: false,
            callID: offer.callID,
            completion: nil
        )
        answer.contactIdentity = offer.contactIdentity
        voIPCallSender.sendVoIPCall(answer: answer)
        
        guard let contactIdentity = offer.contactIdentity else {
            DDLogError("Cannot reject call offer as it does not have an identity")
            return
        }
        
        CallSystemMessageHelper.addRejectedMessageToConversation(
            contactIdentity: contactIdentity,
            reason: .callMissed,
            on: backgroundBusinessInjector
        ) { conversation, systemMessage in
            guard let backgroundBusinessInjector = self.backgroundBusinessInjector else {
                DDLogError("BusinessInjector is not ready")
                return
            }

            backgroundBusinessInjector.entityManager.performAndWait {
                self.persistenceManager?.dirtyObjectManager.markAsDirty(objectID: systemMessage.objectID) {
                    AppGroup.notifySyncNeeded()
                }
            }

            backgroundBusinessInjector.unreadMessages
                .totalCount(doCalcUnreadMessagesCountOf: [conversation])

            // Add conversation as change to recalculate unread messages
            self.conversationsChangedQueue.async {
                self.conversationsChanged?.insert(conversation.objectID)
            }
        }
    }
}

// MARK: - ConnectionStateDelegate

extension NotificationService: ConnectionStateDelegate {
    func changed(connectionState state: ConnectionState) {
        if state == .disconnecting || state == .disconnected {
            DDLogWarn(
                "[Push] Server connection is disconnected (state: \(ServerConnector.shared().name(for: state)))) stop processing"
            )

            guard !NotificationService.didJustReportCall else {
                DDLogNotice("[Push] Don't leave after connection state change because we just reported a call.")
                return
            }

            exitIfAllTasksProcessed(force: true)
        }
    }
}
