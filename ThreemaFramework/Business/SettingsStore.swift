//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

import Foundation
import PromiseKit

public class SettingsStore {
    
    public struct Settings {
        public var syncContacts: Bool
        public var sendReadReceipts: Bool
        public var blockUnknown: Bool
        public var sendTypingIndicator: Bool
        public var enableThreemaCall: Bool
        public var alwaysRelayCalls: Bool
        public var blacklist: Set<String>
        public var syncExclusionList: [String]
    }
    
    private let serverConnector: ServerConnectorProtocol
    private let myIdentityStore: MyIdentityStoreProtocol
    private let contactStore: ContactStoreProtocol
    private let userSettings: UserSettingsProtocol
    private let taskManager: TaskManagerProtocol?
    
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
    }
    
    public convenience init() {
        self.init(
            serverConnector: ServerConnector.shared(),
            myIdentityStore: MyIdentityStore.shared(),
            contactStore: ContactStore.shared(),
            userSettings: UserSettings.shared(),
            taskManager: TaskManager()
        )
    }
    
    public var settings: Settings {
        let blockList = Set<String>(userSettings.blacklist.array as? [String] ?? [])
        
        return Settings(
            syncContacts: userSettings.syncContacts,
            sendReadReceipts: userSettings.sendReadReceipts,
            blockUnknown: userSettings.blockUnknown,
            sendTypingIndicator: userSettings.sendTypingIndicator,
            enableThreemaCall: userSettings.enableThreemaCall,
            alwaysRelayCalls: userSettings.alwaysRelayCalls,
            blacklist: blockList,
            syncExclusionList: userSettings.syncExclusionList as! [String]
        )
    }
    
    /// Sync changes of user settings and save if multi device activated otherwise just save
    /// - Parameter settings: User settings data
    public func syncAndSave(_ settings: Settings) -> Promise<Void> {
        Promise { seal in
            if serverConnector.isMultiDeviceActivated,
               let taskManager = taskManager {
                var syncSettings = Sync_Settings()

                let actualBlacklist = userSettings.blacklist ?? NSOrderedSet(array: [String]())
                if !actualBlacklist.isEqual(to: NSOrderedSet(array: Array(settings.blacklist))) {
                    syncSettings.blockedIdentities.identities = Array(settings.blacklist)
                }

                if userSettings.alwaysRelayCalls != settings.alwaysRelayCalls {
                    syncSettings.callConnectionPolity = settings.alwaysRelayCalls ? .requireRelay : .allowDirect
                }

                if userSettings.enableThreemaCall != settings.enableThreemaCall {
                    syncSettings.callPolicy = settings.enableThreemaCall ? .allowCall : .denyCall
                }

                if userSettings.syncContacts != settings.syncContacts {
                    syncSettings.contactSyncPolicy = settings.syncContacts ? .sync : .notSynced
                }

                if userSettings.sendTypingIndicator != settings.sendTypingIndicator {
                    syncSettings.typingIndicatorPolicy = settings
                        .sendTypingIndicator ? .sendTypingIndicator : .dontSendTypingIndicator
                }

                if userSettings.syncExclusionList as? [String] != settings.syncExclusionList {
                    syncSettings.excludeFromSyncIdentities.identities = settings.syncExclusionList
                }

                if userSettings.blockUnknown != settings.blockUnknown {
                    syncSettings.unknownContactPolicy = settings.blockUnknown ? .blockUnknown : .allowUnknown
                }

                if userSettings.sendReadReceipts != settings.sendReadReceipts {
                    syncSettings.readReceiptPolicy = settings.sendReadReceipts ? .sendReadReceipt : .dontSendReadReceipt
                }

                let task = TaskDefinitionSettingsSync(syncSettings: syncSettings)

                taskManager.add(taskDefinition: task) { _, error in
                    if let error = error {
                        seal.reject(error)
                        return
                    }
                    seal.fulfill_()
                }
            }
            else {
                save(settings)
                seal.fulfill_()
            }
        }
    }
    
    public func save(_ settings: Settings) {
        userSettings.syncContacts = settings.syncContacts
        userSettings.blockUnknown = settings.blockUnknown
        userSettings.sendReadReceipts = settings.sendReadReceipts
        userSettings.sendTypingIndicator = settings.sendTypingIndicator
        userSettings.enableThreemaCall = settings.enableThreemaCall
        userSettings.alwaysRelayCalls = settings.alwaysRelayCalls
        userSettings.blacklist = NSOrderedSet(array: Array(settings.blacklist))
        userSettings.syncExclusionList = settings.syncExclusionList
    }

    /// Save only changed form synced user settings
    /// - Parameter syncSettings: Delta updates of user settings
    func save(syncSettings: Sync_Settings) {
        if syncSettings.hasBlockedIdentities {
            userSettings.blacklist = NSOrderedSet(array: syncSettings.blockedIdentities.identities)
        }

        if syncSettings.hasCallConnectionPolity {
            userSettings.alwaysRelayCalls = syncSettings.callConnectionPolity == .requireRelay
        }

        if syncSettings.hasCallPolicy {
            userSettings.enableThreemaCall = syncSettings.callPolicy == .allowCall
        }

        if syncSettings.hasContactSyncPolicy {
            userSettings.syncContacts = syncSettings.contactSyncPolicy == .sync
        }

        if syncSettings.hasTypingIndicatorPolicy {
            userSettings.sendTypingIndicator = syncSettings.typingIndicatorPolicy == .sendTypingIndicator
        }

        if syncSettings.hasExcludeFromSyncIdentities {
            userSettings.syncExclusionList = syncSettings.excludeFromSyncIdentities.identities
        }

        if syncSettings.hasUnknownContactPolicy {
            userSettings.blockUnknown = syncSettings.unknownContactPolicy == .blockUnknown
        }

        if syncSettings.hasReadReceiptPolicy {
            userSettings.sendReadReceipts = syncSettings.readReceiptPolicy == .sendReadReceipt
        }
    }
}
