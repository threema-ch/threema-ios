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

public class SettingsStore: SettingsStoreInternalProtocol, SettingsStoreProtocol, ObservableObject {
    
    static let shared = SettingsStore()
    
    // MARK: Private Attributes

    private let serverConnector: ServerConnectorProtocol
    private let myIdentityStore: MyIdentityStoreProtocol
    private let contactStore: ContactStoreProtocol
    private let userSettings: UserSettingsProtocol
    private let taskManager: TaskManagerProtocol?
    
    // MARK: - Lifecycle

    public convenience init() {
        self.init(
            serverConnector: ServerConnector(),
            myIdentityStore: MyIdentityStore(),
            contactStore: ContactStore(),
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
        self.sendReadReceipts = userSettings.sendReadReceipts
        self.sendTypingIndicator = userSettings.sendTypingIndicator
        self.choosePOI = userSettings.enablePoi
        self.hidePrivateChats = userSettings.hidePrivateChats
        
        // Chat
        self.wallpaper = userSettings.wallpaper
        
        // Threema Calls
        self.enableThreemaCall = userSettings.enableThreemaCall
        self.alwaysRelayCalls = userSettings.alwaysRelayCalls
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(incomingUpdate),
            name: NSNotification.Name(rawValue: kNotificationIncomingSettingsSynchronization),
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
            if userSettings.syncContacts == syncContacts {
                return
            }
            syncAndSave()
        }
    }
    
    @Published public var blacklist: Set<String> {
        didSet {
            if userSettings.blacklist == NSOrderedSet(array: Array(blacklist)) {
                return
            }
            syncAndSave()
        }
    }
    
    @Published public var syncExclusionList: [String] {
        didSet {
            if userSettings.syncExclusionList as? [String] == syncExclusionList {
                return
            }
            syncAndSave()
        }
    }
    
    @Published public var blockUnknown: Bool {
        didSet {
            if userSettings.blockUnknown == blockUnknown {
                return
            }
            syncAndSave()
        }
    }
    
    @Published public var sendReadReceipts: Bool {
        didSet {
            if userSettings.sendReadReceipts == sendReadReceipts {
                return
            }
            syncAndSave()
        }
    }
    
    @Published public var sendTypingIndicator: Bool {
        didSet {
            if userSettings.sendTypingIndicator == sendTypingIndicator {
                return
            }
            syncAndSave()
        }
    }
    
    @Published public var choosePOI: Bool {
        didSet {
            // This setting is not synced across devices
            userSettings.enablePoi = choosePOI
        }
    }
    
    @Published public var hidePrivateChats: Bool {
        didSet {
            // This setting is not synced across devices
            userSettings.hidePrivateChats = hidePrivateChats
            
            NotificationCenter.default.post(
                name: Notification.Name(kNotificationChangedHidePrivateChat),
                object: nil,
                userInfo: nil
            )
        }
    }
    
    // MARK: Chats
    
    @Published public var wallpaper: UIImage? {
        didSet {
            userSettings.wallpaper = wallpaper
        }
    }

    // MARK: Threema Calls
    
    @Published public var enableThreemaCall: Bool {
        didSet {
            if userSettings.enableThreemaCall == enableThreemaCall {
                return
            }
            syncAndSave()
        }
    }
    
    @Published public var alwaysRelayCalls: Bool {
        didSet {
            if userSettings.alwaysRelayCalls == alwaysRelayCalls {
                return
            }
            syncAndSave()
        }
    }
    
    // MARK: - Public Functions
    
    /// Saves changed `Sync_Settings` to UserSettings and updates the SettingsStore
    /// - Parameter syncSettings: Delta updates of user settings
    func updateSettingsStore(with syncSettings: Sync_Settings) {
        
        /// **IMPORTANT:**
        /// Always update `UserSettings` before the local published variable
        
        if syncSettings.hasBlockedIdentities {
            let newValue = NSOrderedSet(array: syncSettings.blockedIdentities.identities)
            userSettings.blacklist = newValue
            blacklist = Set(syncSettings.blockedIdentities.identities)
        }

        if syncSettings.hasCallConnectionPolity {
            let newValue = syncSettings.callConnectionPolity == .requireRelay
            userSettings.alwaysRelayCalls = newValue
            alwaysRelayCalls = newValue
        }

        if syncSettings.hasCallPolicy {
            let newValue = syncSettings.callPolicy == .allowCall
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
    /// 2. Multi-Device enabled: Syncs all settings and updates UserSettings if sync succeeds, rejects if sync fails and does not update UserSettings, shows alert
    public func syncAndSave() {
            
        guard serverConnector.isMultiDeviceActivated else {
            // Save locally
            updateUserSettings()
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
            updateLocalValues()
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
            syncSettings.callConnectionPolity = alwaysRelayCalls ? .requireRelay : .allowDirect
            hasChanges = true
        }

        if userSettings.enableThreemaCall != enableThreemaCall {
            syncSettings.callPolicy = enableThreemaCall ? .allowCall : .denyCall
            hasChanges = true
        }

        if userSettings.syncContacts != syncContacts {
            syncSettings.contactSyncPolicy = syncContacts ? .sync : .notSynced
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
                return
            }
                
            self.isSyncing(false, failed: false)
            NotificationPresenterWrapper().present(type: .settingsSyncSuccess)
        }
    }
    
    public func discardUnsyncedChanges() {
        // Since the changes have not been saved yet, we simply load the user settings again
        updateLocalValues()
    }
    
    // MARK: - Private Functions
    
    @objc private func incomingUpdate() {
        updateLocalValues()
        NotificationPresenterWrapper().present(type: .settingsSyncSuccess)
    }
    
    private func isSyncing(_ syncing: Bool, failed: Bool) {
        Task(priority: .userInitiated) { @MainActor in
            isSyncing = syncing
            syncFailed = failed
        }
    }
    
    private func updateUserSettings() {
        userSettings.syncContacts = syncContacts
        userSettings.blockUnknown = blockUnknown
        userSettings.blacklist = NSOrderedSet(array: Array(blacklist))
        userSettings.syncExclusionList = syncExclusionList
        userSettings.sendReadReceipts = sendReadReceipts
        userSettings.sendTypingIndicator = sendTypingIndicator
        
        userSettings.enableThreemaCall = enableThreemaCall
        userSettings.alwaysRelayCalls = alwaysRelayCalls
    }
    
    private func updateLocalValues() {
        syncContacts = userSettings.syncContacts
        blockUnknown = userSettings.blockUnknown
        blacklist = Set<String>(userSettings.blacklist.array as? [String] ?? [])
        syncExclusionList = userSettings.syncExclusionList as? [String] ?? []
        sendReadReceipts = userSettings.sendReadReceipts
        sendTypingIndicator = userSettings.sendTypingIndicator
        
        enableThreemaCall = userSettings.enableThreemaCall
        alwaysRelayCalls = userSettings.alwaysRelayCalls
    }
}
