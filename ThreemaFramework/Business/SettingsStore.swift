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
import ThreemaProtocols

public class SettingsStore: SettingsStoreInternalProtocol, SettingsStoreProtocol, ObservableObject {
    
    // MARK: Public Attributes
    
    public var wallpaperStore = WallpaperStore.shared

    // MARK: Private Attributes

    private let serverConnector: ServerConnectorProtocol
    private let myIdentityStore: MyIdentityStoreProtocol
    private let contactStore: ContactStoreProtocol
    private let userSettings: UserSettingsProtocol
    private let taskManager: TaskManagerProtocol?
    
    // MARK: - Lifecycle

    public convenience init() {
        self.init(
            serverConnector: ServerConnector.shared(),
            myIdentityStore: MyIdentityStore.shared(),
            contactStore: ContactStore.shared(),
            userSettings: UserSettings.shared(),
            taskManager: nil
        )
    }
    
    init(
        serverConnector: ServerConnectorProtocol,
        myIdentityStore: MyIdentityStoreProtocol,
        contactStore: ContactStoreProtocol,
        userSettings: UserSettingsProtocol,
        taskManager: TaskManagerProtocol?
    ) {
        self.serverConnector = serverConnector
        self.myIdentityStore = myIdentityStore
        self.contactStore = contactStore
        self.userSettings = userSettings
        self.taskManager = taskManager
        
        // Privacy Settings
        self.syncContacts = userSettings.syncContacts
        self.blacklist = Set<String>(userSettings.blacklist.array as? [String] ?? [])
        self.syncExclusionList = userSettings.syncExclusionList as? [String] ?? []
        self.blockUnknown = userSettings.blockUnknown
        self.allowOutgoingDonations = userSettings.allowOutgoingDonations
        self.sendReadReceipts = userSettings.sendReadReceipts
        self.sendTypingIndicator = userSettings.sendTypingIndicator
        self.choosePOI = userSettings.enablePoi
        self.hidePrivateChats = userSettings.hidePrivateChats
        
        // Notifications
        self.inAppSounds = userSettings.inAppSounds
        self.inAppVibrate = userSettings.inAppVibrate
        self.inAppPreview = userSettings.inAppPreview
        self.notificationType = NotificationType.type(for: userSettings.notificationType)
        self.pushShowPreview = userSettings.pushDecrypt
        self.pushSound = userSettings.pushSound
        self.pushGroupSound = userSettings.pushGroupSound
        self.enableMasterDnd = userSettings.enableMasterDnd
        self.masterDndWorkingDays = Set<Int>(userSettings.masterDndWorkingDays.array as? [Int] ?? [])
        self.masterDndStartTime = userSettings.masterDndStartTime
        self.masterDndEndTime = userSettings.masterDndEndTime

        // Chat
        self.useBigEmojis = !userSettings.disableBigEmojis
        self.sendMessageFeedback = userSettings.sendMessageFeedback

        // Media
        self.imageSize = userSettings.imageSize
        self.videoQuality = userSettings.videoQuality
        self.autoSaveMedia = userSettings.autoSaveMedia
        
        // Threema Calls
        self.enableThreemaCall = userSettings.enableThreemaCall
        self.alwaysRelayCalls = userSettings.alwaysRelayCalls
        self.includeCallsInRecents = userSettings.includeCallsInRecents
        self.enableVideoCall = userSettings.enableVideoCall
        self.threemaVideoCallQualitySetting = userSettings.threemaVideoCallQualitySetting
        self.voIPSound = userSettings.voIPSound
        self.enableThreemaGroupCalls = userSettings.enableThreemaGroupCalls

        // Advanced
        self.enableIPv6 = userSettings.enableIPv6
        self.disableProximityMonitoring = userSettings.disableProximityMonitoring
        self.validationLogging = userSettings.validationLogging
        self.sentryAppDevice = userSettings.sentryAppDevice
        
        // Multi-Device
        self.isMultiDeviceRegistered = userSettings.enableMultiDevice
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(incomingUpdate),
            name: NSNotification.Name(rawValue: kNotificationIncomingSettingsSynchronization),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateLocalValuesAsyncObjC),
            name: NSNotification.Name(rawValue: kNotificationSettingStoreSynchronization),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Published Attributes
    
    @Published public var isSyncing = false
    @Published public var syncFailed = false
    
    // MARK: Privacy Settings

    @Published public var syncContacts: Bool {
        didSet {
            guard userSettings.syncContacts != syncContacts else {
                return
            }
            syncAndSave()
        }
    }
    
    @Published public var blacklist: Set<String> {
        didSet {
            guard Set<String>(userSettings.blacklist.array as? [String] ?? []) != blacklist else {
                return
            }
            syncAndSave()
        }
    }
    
    @Published public var syncExclusionList: [String] {
        didSet {
            guard userSettings.syncExclusionList as? [String] != syncExclusionList else {
                return
            }
            syncAndSave()
        }
    }
    
    @Published public var blockUnknown: Bool {
        didSet {
            guard userSettings.blockUnknown != blockUnknown else {
                return
            }
            syncAndSave()
        }
    }
    
    @Published public var allowOutgoingDonations: Bool {
        didSet {
            userSettings.allowOutgoingDonations = allowOutgoingDonations
            
            // Remove donated INInteractions when being disabled
            if !allowOutgoingDonations {
                removeINInteractions()
            }
        }
    }
    
    @Published public var sendReadReceipts: Bool {
        didSet {
            guard userSettings.sendReadReceipts != sendReadReceipts else {
                return
            }
            syncAndSave()
        }
    }
    
    @Published public var sendTypingIndicator: Bool {
        didSet {
            guard userSettings.sendTypingIndicator != sendTypingIndicator else {
                return
            }
            syncAndSave()
        }
    }
    
    @Published public var choosePOI: Bool {
        didSet {
            guard userSettings.enablePoi != choosePOI else {
                return
            }
            updateUserSettingsAsync()
        }
    }
    
    @Published public var hidePrivateChats: Bool {
        didSet {
            guard userSettings.hidePrivateChats != hidePrivateChats else {
                return
            }
            updateUserSettingsAsync {
                NotificationCenter.default.post(
                    name: Notification.Name(kNotificationChangedHidePrivateChat),
                    object: nil,
                    userInfo: nil
                )
            }
        }
    }
    
    // MARK: Notifications

    @Published public var inAppSounds: Bool {
        didSet {
            guard userSettings.inAppSounds != inAppSounds else {
                return
            }
            updateUserSettingsAsync()
        }
    }
    
    @Published public var inAppVibrate: Bool {
        didSet {
            guard userSettings.inAppVibrate != inAppVibrate else {
                return
            }
            updateUserSettingsAsync()
        }
    }
    
    @Published public var inAppPreview: Bool {
        didSet {
            guard userSettings.inAppPreview != inAppPreview else {
                return
            }
            updateUserSettingsAsync()
        }
    }
    
    @Published public var notificationType: NotificationType {
        didSet {
            guard userSettings.notificationType != NSNumber(integerLiteral: notificationType.userSettingsValue) else {
                return
            }
            updateUserSettingsAsync {
                // We only remove the donated Interactions, if the outgoing are disabled.
                switch self.notificationType {
                case .restrictive, .balanced:
                    if !self.allowOutgoingDonations {
                        self.removeINInteractions()
                    }
                case .complete:
                    return
                }
            }
        }
    }
    
    @Published public var pushShowPreview: Bool {
        didSet {
            guard userSettings.pushDecrypt != pushShowPreview else {
                return
            }
            updateUserSettingsAsync()
        }
    }
    
    @Published public var pushSound: String {
        didSet {
            guard userSettings.pushSound != pushSound else {
                return
            }
            updateUserSettingsAsync()
        }
    }
    
    @Published public var pushGroupSound: String {
        didSet {
            guard userSettings.pushGroupSound != pushGroupSound else {
                return
            }
            updateUserSettingsAsync()
        }
    }
    
    @Published public var enableMasterDnd: Bool {
        didSet {
            guard userSettings.enableMasterDnd != enableMasterDnd else {
                return
            }
            
            // We automatically selects first 5 days if no selection was set
            if enableMasterDnd, masterDndWorkingDays.isEmpty {
                masterDndWorkingDays = preFillWorkingDays()
            }
            
            updateUserSettingsAsync()
        }
    }
    
    @Published public var masterDndWorkingDays: Set<Int> {
        didSet {
            guard Set<Int>(userSettings.masterDndWorkingDays.array as? [Int] ?? []) != masterDndWorkingDays else {
                return
            }
            updateUserSettingsAsync()
        }
    }
    
    @Published public var masterDndStartTime: String? {
        didSet {
            guard userSettings.masterDndStartTime != masterDndStartTime else {
                return
            }
            updateUserSettingsAsync()
        }
    }
    
    @Published public var masterDndEndTime: String? {
        didSet {
            guard userSettings.masterDndEndTime != masterDndEndTime else {
                return
            }
            updateUserSettingsAsync()
        }
    }
    
    // MARK: Chats
    
    @Published public var useBigEmojis: Bool {
        didSet {
            guard userSettings.disableBigEmojis == useBigEmojis else {
                return
            }
            updateUserSettingsAsync()
        }
    }
    
    @Published public var sendMessageFeedback: Bool {
        didSet {
            guard userSettings.sendMessageFeedback != sendMessageFeedback else {
                return
            }
            updateUserSettingsAsync()
        }
    }
    
    // MARK: - Media

    @Published public var imageSize: String {
        didSet {
            guard userSettings.imageSize != imageSize else {
                return
            }
            updateUserSettingsAsync()
        }
    }

    @Published public var videoQuality: String {
        didSet {
            guard userSettings.videoQuality != videoQuality else {
                return
            }
            updateUserSettingsAsync()
        }
    }

    @Published public var autoSaveMedia: Bool {
        didSet {
            guard userSettings.autoSaveMedia != autoSaveMedia else {
                return
            }
            updateUserSettingsAsync()
        }
    }

    // MARK: Threema Calls
    
    @Published public var enableThreemaCall: Bool {
        didSet {
            guard userSettings.enableThreemaCall != enableThreemaCall else {
                return
            }
            syncAndSave()
        }
    }
    
    @Published public var alwaysRelayCalls: Bool {
        didSet {
            guard userSettings.alwaysRelayCalls != alwaysRelayCalls else {
                return
            }
            syncAndSave()
        }
    }
    
    @Published public var includeCallsInRecents: Bool {
        didSet {
            guard userSettings.includeCallsInRecents != includeCallsInRecents else {
                return
            }
            updateUserSettingsAsync()
        }
    }
    
    @Published public var enableVideoCall: Bool {
        didSet {
            guard userSettings.enableVideoCall != enableVideoCall else {
                return
            }
            updateUserSettingsAsync()
        }
    }
    
    @Published public var threemaVideoCallQualitySetting: ThreemaVideoCallQualitySetting {
        didSet {
            guard userSettings.threemaVideoCallQualitySetting != threemaVideoCallQualitySetting else {
                return
            }
            updateUserSettingsAsync()
        }
    }
    
    @Published public var voIPSound: String {
        didSet {
            guard userSettings.voIPSound != voIPSound else {
                return
            }
            updateUserSettingsAsync()
        }
    }
    
    @Published public var enableThreemaGroupCalls: Bool {
        didSet {
            guard userSettings.enableThreemaGroupCalls != enableThreemaGroupCalls else {
                return
            }
            updateUserSettingsAsync()
        }
    }
    
    // MARK: Multi-Device
    
    /// Is multi-device enabled an the this device registered at the mediator?
    @Published public var isMultiDeviceRegistered: Bool {
        didSet {
            guard userSettings.enableMultiDevice != isMultiDeviceRegistered else {
                return
            }
            updateUserSettingsAsync()
        }
    }
            
    // MARK: - Advanced
    
    @Published public var enableIPv6: Bool {
        didSet {
            guard userSettings.enableIPv6 != enableIPv6 else {
                return
            }
            updateUserSettingsAsync()
        }
    }
    
    @Published public var disableProximityMonitoring: Bool {
        didSet {
            guard userSettings.disableProximityMonitoring != disableProximityMonitoring else {
                return
            }
            updateUserSettingsAsync()
        }
    }
    
    @Published public var validationLogging: Bool {
        didSet {
            guard userSettings.validationLogging != validationLogging else {
                return
            }
            updateUserSettingsAsync()
        }
    }
    
    @Published public var sentryAppDevice: String? {
        didSet {
            guard userSettings.sentryAppDevice != sentryAppDevice else {
                return
            }
            updateUserSettingsAsync()
        }
    }
    
    // MARK: - Public Functions
    
    public func flushMessageQueue() {
        DDLogWarn("Manually flushing outgoing task queue")
        TaskManager.flush(queueType: .outgoing)
        let tm = TaskManager()
        tm.spool()
        NotificationPresenterWrapper.shared.present(type: .flushMessageQueueSuccess)
    }
    
    /// Saves changed `Sync_Settings` to UserSettings and updates the SettingsStore
    /// - Parameter syncSettings: Delta updates of user settings
    @MainActor
    func updateSettingsStore(with syncSettings: Sync_Settings) {
        
        /// **IMPORTANT:**
        /// Always update `UserSettings` before the local published variable
        
        if syncSettings.hasBlockedIdentities {
            let newValue = NSOrderedSet(array: syncSettings.blockedIdentities.identities)
            userSettings.blacklist = newValue
            blacklist = Set(syncSettings.blockedIdentities.identities)
        }

        if syncSettings.hasO2OCallConnectionPolicy {
            let newValue = syncSettings.o2OCallConnectionPolicy == .requireRelayedConnection
            userSettings.alwaysRelayCalls = newValue
            alwaysRelayCalls = newValue
        }

        if syncSettings.hasO2OCallPolicy {
            let newValue = syncSettings.o2OCallPolicy == .allowO2OCall
            userSettings.enableThreemaCall = newValue
            enableThreemaCall = newValue
        }

        if syncSettings.hasContactSyncPolicy {
            let newValue = syncSettings.contactSyncPolicy == .sync
            userSettings.syncContacts = newValue
            syncContacts = newValue
        }

        if syncSettings.hasTypingIndicatorPolicy {
            let newValue = syncSettings.typingIndicatorPolicy == .sendTypingIndicator
            userSettings.sendTypingIndicator = newValue
            sendTypingIndicator = newValue
        }

        if syncSettings.hasExcludeFromSyncIdentities {
            userSettings.syncExclusionList = syncSettings.excludeFromSyncIdentities.identities
            syncExclusionList = syncSettings.excludeFromSyncIdentities.identities
        }

        if syncSettings.hasUnknownContactPolicy {
            let newValue = syncSettings.unknownContactPolicy == .blockUnknown
            userSettings.blockUnknown = newValue
            blockUnknown = newValue
        }

        if syncSettings.hasReadReceiptPolicy {
            let newValue = syncSettings.readReceiptPolicy == .sendReadReceipt
            userSettings.sendReadReceipts = newValue
            sendReadReceipts = newValue
        }
    }
    
    /// Saves made changes
    /// 1. Multi-Device disabled: Just updates UserSettings
    /// 2. Multi-Device enabled: Syncs all settings and updates UserSettings if sync succeeds, rejects if sync fails and
    ///   does not update UserSettings, shows alert
    public func syncAndSave() {
            
        guard userSettings.enableMultiDevice else {
            // Save locally
            Task { @MainActor in
                updateUserSettings()
            }
            return
        }
        
        guard serverConnector.connectionState == .loggedIn else {
            DDLogWarn("[SettingsStore] Not logged in.")
            NotificationPresenterWrapper.shared.dismissAllPresentedNotifications()
            isSyncing(false, failed: true)
            return
        }
        
        guard let taskManager else {
            DDLogError("[SettingsStore] TaskManager not set, reverting changes.")
            discardUnsyncedChanges()
            return
        }
            
        isSyncing(true, failed: false)
        NotificationPresenterWrapper().presentIndefinitely(type: .settingsSyncPending)
        
        var hasChanges = false
            
        var syncSettings = Sync_Settings()
            
        let actualBlacklist = userSettings.blacklist ?? NSOrderedSet(array: [String]())
        if !actualBlacklist.isEqual(to: NSOrderedSet(array: Array(blacklist))) {
            syncSettings.blockedIdentities.identities = Array(blacklist)
            hasChanges = true
        }

        if userSettings.alwaysRelayCalls != alwaysRelayCalls {
            syncSettings.o2OCallConnectionPolicy = alwaysRelayCalls ? .requireRelayedConnection : .allowDirectConnection
            hasChanges = true
        }

        if userSettings.enableThreemaCall != enableThreemaCall {
            syncSettings.o2OCallPolicy = enableThreemaCall ? .allowO2OCall : .denyO2OCall
            hasChanges = true
        }

        if userSettings.syncContacts != syncContacts {
            syncSettings.updateContactSyncPolicy(syncContacts: syncContacts)
            hasChanges = true
        }

        if userSettings.sendTypingIndicator != sendTypingIndicator {
            syncSettings
                .typingIndicatorPolicy = sendTypingIndicator ? .sendTypingIndicator : .dontSendTypingIndicator
            hasChanges = true
        }

        if userSettings.syncExclusionList as? [String] != syncExclusionList {
            syncSettings.excludeFromSyncIdentities.identities = syncExclusionList
            hasChanges = true
        }

        if userSettings.blockUnknown != blockUnknown {
            syncSettings.unknownContactPolicy = blockUnknown ? .blockUnknown : .allowUnknown
            hasChanges = true
        }

        if userSettings.sendReadReceipts != sendReadReceipts {
            syncSettings.readReceiptPolicy = sendReadReceipts ? .sendReadReceipt : .dontSendReadReceipt
            hasChanges = true
        }
        
        guard hasChanges else {
            isSyncing(false, failed: false)
            NotificationPresenterWrapper().present(type: .settingsSyncSuccess)
            return
        }

        let task = TaskDefinitionSettingsSync(syncSettings: syncSettings)

        taskManager.add(taskDefinition: task) { _, error in
            guard error == nil else {
                NotificationPresenterWrapper.shared.dismissAllPresentedNotifications()
                self.isSyncing(false, failed: true)
                self.discardUnsyncedChanges()
                return
            }
                
            self.isSyncing(false, failed: false)
            NotificationPresenterWrapper().present(type: .settingsSyncSuccess)
            
            // Inform other SettingsStores
            NotificationCenter.default.post(
                name: NSNotification.Name(rawValue: kNotificationIncomingSettingsSynchronization),
                object: nil
            )
        }
    }
    
    public func discardUnsyncedChanges() {
        // Since the changes have not been saved yet, we simply load the user settings again
        Task { @MainActor in
            updateLocalValues()
        }
    }
    
    /// Removes all INInteractions donated to the OS
    /// - Parameter showNotification: Show a success or error notification pill
    public func removeINInteractions(showNotification: Bool = false) {
        INInteraction.deleteAll { error in
            guard error == nil else {
                DDLogError("[PrivacySettingsViewController] Could not delete INInteractions.")
                
                if showNotification {
                    NotificationPresenterWrapper.shared.present(type: .interactionDeleteError)
                }
                return
            }
            
            if showNotification {
                NotificationPresenterWrapper.shared.present(type: .interactionDeleteSuccess)
            }
        }
    }
    
    /// Removes all INInteractions donated to the OS
    /// - Parameter showNotification: Show a success or error notification pill
    public static func removeINInteractions(for managedObjectID: NSManagedObjectID) {
        Task {
            do {
                try await INInteraction.delete(with: managedObjectID.uriRepresentation().absoluteString)
            }
            catch {
                DDLogError("Donations for group identifier could not be deleted.")
            }
        }
    }
    
    // MARK: - Private Functions
    
    @objc private func incomingUpdate() {
        Task { @MainActor in
            updateLocalValues()
            NotificationPresenterWrapper().present(type: .settingsSyncSuccess)
        }
    }
    
    private func isSyncing(_ syncing: Bool, failed: Bool) {
        Task(priority: .userInitiated) { @MainActor in
            isSyncing = syncing
            syncFailed = failed
        }
    }
    
    private func updateUserSettingsAsync(completion: (() -> Void)? = nil) {
        Task { @MainActor in
            updateUserSettings()
            completion?()
        }
    }
    
    @MainActor
    private func updateUserSettings() {
       
        // Privacy Settings
        compareAndAssign(&userSettings.syncContacts, syncContacts)

        if Set<String>(userSettings.blacklist.array as? [String] ?? []) != blacklist {
            compareAndAssign(&userSettings.blacklist, NSOrderedSet(array: Array(blacklist)))
        }

        compareAndAssign(&userSettings.blockUnknown, blockUnknown)
        
        if userSettings.syncExclusionList as? [String] ?? [] != syncExclusionList {
            userSettings.syncExclusionList = syncExclusionList
        }
        
        compareAndAssign(&userSettings.sendReadReceipts, sendReadReceipts)
        compareAndAssign(&userSettings.sendTypingIndicator, sendTypingIndicator)
        compareAndAssign(&userSettings.enablePoi, choosePOI)
        compareAndAssign(&userSettings.hidePrivateChats, hidePrivateChats)
        
        // Notifications
        compareAndAssign(&userSettings.inAppSounds, inAppSounds)
        compareAndAssign(&userSettings.inAppVibrate, inAppVibrate)
        compareAndAssign(&userSettings.inAppPreview, inAppPreview)
        compareAndAssign(&userSettings.notificationType, NSNumber(integerLiteral: notificationType.userSettingsValue))
        compareAndAssign(&userSettings.pushDecrypt, pushShowPreview)
        compareAndAssign(&userSettings.pushSound, pushSound)
        compareAndAssign(&userSettings.pushGroupSound, pushGroupSound)
        compareAndAssign(&userSettings.enableMasterDnd, enableMasterDnd)

        if Set<Int>(userSettings.masterDndWorkingDays.array as? [Int] ?? []) != masterDndWorkingDays {
            userSettings.masterDndWorkingDays = NSOrderedSet(set: masterDndWorkingDays)
        }
        
        compareAndAssign(&userSettings.masterDndStartTime, masterDndStartTime)
        compareAndAssign(&userSettings.masterDndEndTime, masterDndEndTime)

        // Chat
        compareAndAssign(&userSettings.disableBigEmojis, !useBigEmojis)
        compareAndAssign(&userSettings.sendMessageFeedback, sendMessageFeedback)

        // Media
        compareAndAssign(&userSettings.imageSize, imageSize)
        compareAndAssign(&userSettings.videoQuality, videoQuality)
        compareAndAssign(&userSettings.autoSaveMedia, autoSaveMedia)
        
        // Threema Calls
        compareAndAssign(&userSettings.enableThreemaCall, enableThreemaCall)
        compareAndAssign(&userSettings.alwaysRelayCalls, alwaysRelayCalls)
        compareAndAssign(&userSettings.includeCallsInRecents, includeCallsInRecents)
        compareAndAssign(&userSettings.enableVideoCall, enableVideoCall)
        compareAndAssign(&userSettings.threemaVideoCallQualitySetting, threemaVideoCallQualitySetting)
        compareAndAssign(&userSettings.voIPSound, voIPSound)
        compareAndAssign(&userSettings.enableThreemaGroupCalls, enableThreemaGroupCalls)

        // Advanced
        compareAndAssign(&userSettings.enableIPv6, enableIPv6)
        compareAndAssign(&userSettings.disableProximityMonitoring, disableProximityMonitoring)
        compareAndAssign(&userSettings.validationLogging, validationLogging)
        compareAndAssign(&userSettings.sentryAppDevice, sentryAppDevice)
        
        // Multi-Device
        compareAndAssign(&userSettings.enableMultiDevice, isMultiDeviceRegistered)
        
        // Inform other SettingsStores
        NotificationCenter.default.post(
            name: NSNotification.Name(rawValue: kNotificationSettingStoreSynchronization),
            object: nil
        )
    }
    
    @objc private func updateLocalValuesAsyncObjC() {
        Task { @MainActor in
            updateLocalValues()
        }
    }
    
    @MainActor
    private func updateLocalValues() {
        // Privacy Settings
        compareAndAssign(&syncContacts, userSettings.syncContacts)
        compareAndAssign(&blacklist, Set<String>(userSettings.blacklist.array as? [String] ?? []))
        compareAndAssign(&blockUnknown, userSettings.blockUnknown)
        compareAndAssign(&syncExclusionList, userSettings.syncExclusionList as? [String] ?? [])
        compareAndAssign(&sendReadReceipts, userSettings.sendReadReceipts)
        compareAndAssign(&sendTypingIndicator, userSettings.sendTypingIndicator)
        compareAndAssign(&choosePOI, userSettings.enablePoi)
        compareAndAssign(&hidePrivateChats, userSettings.hidePrivateChats)

        // Notifications
        compareAndAssign(&inAppSounds, userSettings.inAppSounds)
        compareAndAssign(&inAppVibrate, userSettings.inAppVibrate)
        compareAndAssign(&inAppPreview, userSettings.inAppPreview)
        compareAndAssign(&notificationType, NotificationType.type(for: userSettings.notificationType))
        compareAndAssign(&pushShowPreview, userSettings.pushDecrypt)
        compareAndAssign(&pushSound, userSettings.pushSound)
        compareAndAssign(&pushGroupSound, userSettings.pushGroupSound)
        compareAndAssign(&enableMasterDnd, userSettings.enableMasterDnd)
        compareAndAssign(&masterDndWorkingDays, Set<Int>(userSettings.masterDndWorkingDays.array as? [Int] ?? []))
        compareAndAssign(&masterDndStartTime, userSettings.masterDndStartTime)
        compareAndAssign(&masterDndEndTime, userSettings.masterDndEndTime)
        
        // Chat
        compareAndAssign(&useBigEmojis, !userSettings.disableBigEmojis)
        compareAndAssign(&sendMessageFeedback, userSettings.sendMessageFeedback)

        // Media
        compareAndAssign(&userSettings.imageSize, imageSize)
        compareAndAssign(&userSettings.videoQuality, videoQuality)
        compareAndAssign(&userSettings.autoSaveMedia, autoSaveMedia)
        
        // Threema Calls
        compareAndAssign(&enableThreemaCall, userSettings.enableThreemaCall)
        compareAndAssign(&alwaysRelayCalls, userSettings.alwaysRelayCalls)
        compareAndAssign(&includeCallsInRecents, userSettings.includeCallsInRecents)
        compareAndAssign(&enableVideoCall, userSettings.enableVideoCall)
        compareAndAssign(&threemaVideoCallQualitySetting, userSettings.threemaVideoCallQualitySetting)
        compareAndAssign(&voIPSound, userSettings.voIPSound)
        compareAndAssign(&enableThreemaGroupCalls, userSettings.enableThreemaGroupCalls)

        // Multi-Device
        compareAndAssign(&isMultiDeviceRegistered, userSettings.enableMultiDevice)
        
        // Advanced
        compareAndAssign(&enableIPv6, userSettings.enableIPv6)
        compareAndAssign(&disableProximityMonitoring, userSettings.disableProximityMonitoring)
        compareAndAssign(&validationLogging, userSettings.validationLogging)
        compareAndAssign(&sentryAppDevice, userSettings.sentryAppDevice)
    }
    
    private func compareAndAssign<T: Equatable>(_ valueToUpdate: inout T, _ comparing: T) {
        if valueToUpdate != comparing {
            valueToUpdate = comparing
        }
    }
    
    private func preFillWorkingDays() -> Set<Int> {
        var days = Set<Int>()
        
        for index in 2...6 {
            days.insert(index)
        }
        
        return days
    }
}
