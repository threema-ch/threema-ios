//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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
import ThreemaEssentials

public protocol PushSettingManagerProtocol {
    func find(forContact identity: ThreemaIdentity) -> PushSetting
    func find(forGroup groupIdentity: GroupIdentity) -> PushSetting
    func pushSetting(for pendingUserNotification: PendingUserNotification) -> PushSetting?
    func save(pushSetting: PushSetting, sync: Bool) async
    func delete(forContact identity: ThreemaIdentity) async
    func canSendPush(for message: BaseMessageEntity) -> Bool
    func canMasterDndSendPush() -> Bool
}

public actor PushSettingManager: PushSettingManagerProtocol {

    enum PushSettingManagerError: Error {
        case decodingFailed
    }

    private typealias TimeOfDay = (hour: Int, minute: Int)

    private let userSettings: UserSettingsProtocol
    private let groupManager: GroupManagerProtocol
    private let entityManager: EntityManager
    private let taskManager: TaskManagerProtocol
    private let isWorkApp: Bool

    init(
        _ userSettings: UserSettingsProtocol,
        _ groupManager: GroupManagerProtocol,
        _ entityManager: EntityManager,
        _ taskManager: TaskManagerProtocol,
        _ isWorkApp: Bool
    ) {
        self.userSettings = userSettings
        self.groupManager = groupManager
        self.entityManager = entityManager
        self.taskManager = taskManager
        self.isWorkApp = isWorkApp
    }

    init(entityManager: EntityManager = EntityManager(), taskManager: TaskManagerProtocol = TaskManager()) {
        self.init(
            UserSettings.shared(),
            GroupManager(entityManager: entityManager, taskManager: taskManager),
            entityManager,
            taskManager,
            TargetManager.isBusinessApp
        )
    }

    /// Get stored or default push setting for contact
    public nonisolated func find(forContact identity: ThreemaIdentity) -> PushSetting {
        var pushSetting: PushSetting?

        do {
            let pushSettings = try decode()
            pushSetting = pushSettings.first(where: { $0.identity == identity })
            if pushSetting?.updatePeriodOffTillDateIsExpired() ?? false {
                if let pushSetting {
                    Task {
                        await save(pushSetting: pushSetting, sync: false)
                    }
                }
            }
        }
        catch {
            DDLogError("Error while looking push settings for '\(identity)': \(error)")
        }

        return pushSetting ?? PushSetting(identity: identity)
    }

    /// Get stored or default push setting for group
    public nonisolated func find(forGroup groupIdentity: GroupIdentity) -> PushSetting {
        var pushSetting: PushSetting?

        do {
            let pushSettings = try decode()
            pushSetting = pushSettings.first(where: { $0.groupIdentity == groupIdentity })
            if pushSetting?.updatePeriodOffTillDateIsExpired() ?? false {
                if let pushSetting {
                    Task {
                        await save(pushSetting: pushSetting, sync: false)
                    }
                }
            }
        }
        catch {
            DDLogError("Error while looking push settings for '\(groupIdentity)': \(error)")
        }

        return pushSetting ?? PushSetting(groupIdentity: groupIdentity)
    }
    
    /// Computes the `PushSetting` for a given `PendingUserNotification`
    /// - Parameter pendingUserNotification: `PendingUserNotification` to find `PushSetting` for
    /// - Returns: `PushSetting1
    public nonisolated func pushSetting(for pendingUserNotification: PendingUserNotification) -> PushSetting? {
        
        if let isGroupMessage = pendingUserNotification.isGroupMessage, isGroupMessage,
           let baseMessage = pendingUserNotification.baseMessage,
           let group = entityManager.entityFetcher.groupEntity(for: baseMessage.conversation) {
            let creator = group.groupCreator ?? MyIdentityStore.shared().identity
            // swiftformat:disable:next acronyms
            return find(forGroup: GroupIdentity(id: group.groupId, creator: ThreemaIdentity(creator!)))
        }
        
        else if let groupCallMessage = pendingUserNotification.abstractMessage as? GroupCallStartMessage {
            return find(forGroup: GroupIdentity(
                id: groupCallMessage.groupID,
                creator: ThreemaIdentity(groupCallMessage.groupCreator)
            ))
        }
        
        else if let senderIdentity = pendingUserNotification.senderIdentity {
            return find(forContact: ThreemaIdentity(senderIdentity))
        }
        
        assertionFailure("This should not happen.")
        return nil
    }

    /// Save push setting
    ///
    /// - Parameters:
    /// - pushSetting: Setting to save
    /// - sync: If true setting will be synced if multi device enabled
    public func save(pushSetting: PushSetting, sync: Bool) async {
        do {
            var pushSettings = try decode()
            pushSettings.removeAll { item in
                if let identity = pushSetting.identity {
                    return item.identity == identity
                }
                else if let groupIdentity = pushSetting.groupIdentity {
                    return item.groupIdentity == groupIdentity
                }
                return false
            }
            pushSettings.append(pushSetting)
            try encode(pushSettings)

            if sync {
                if let identity = pushSetting.identity {
                    var pushSetting = pushSetting
                    let mediatorSyncableContacts = MediatorSyncableContacts(
                        userSettings,
                        self,
                        TaskManager(),
                        entityManager
                    )
                    mediatorSyncableContacts.updateNotificationSound(
                        identity: identity.string,
                        isMuted: pushSetting.muted
                    )
                    mediatorSyncableContacts.updateNotificationTrigger(
                        identity: identity.string,
                        type: pushSetting.type,
                        expiresAt: pushSetting.periodOffTillDate
                    )
                    mediatorSyncableContacts.syncAsync()
                }
                else if let groupIdentity = pushSetting.groupIdentity {
                    let mediatorSyncableGroup = MediatorSyncableGroup(
                        userSettings,
                        self,
                        taskManager,
                        groupManager
                    )
                    await mediatorSyncableGroup.updateNotificationSound(
                        identity: groupIdentity,
                        isMuted: pushSetting.muted
                    )
                    var pushSetting = pushSetting
                    await mediatorSyncableGroup.updateNotificationTrigger(
                        identity: groupIdentity,
                        type: pushSetting.type,
                        expiresAt: pushSetting.periodOffTillDate,
                        mentioned: pushSetting.mentioned
                    )
                    await mediatorSyncableGroup.sync(syncAction: .update)
                }
            }

            NotificationCenter.default.post(
                name: NSNotification.Name(rawValue: kNotificationChangedPushSetting),
                object: pushSetting,
                userInfo: nil
            )
        }
        catch {
            DDLogError("Saving of push settings failed: \(error)")
        }
    }

    public func delete(forContact identity: ThreemaIdentity) async {
        do {
            var pushSettings = try decode()
            if !pushSettings.filter({ $0.identity == identity }).isEmpty {
                pushSettings.removeAll { item in
                    item.identity == identity
                }
                try encode(pushSettings)
            }
        }
        catch {
            DDLogError("Deleting of push settings failed: \(error)")
        }
    }

    /// Should we show a notification for this base message?
    public nonisolated func canSendPush(for message: BaseMessageEntity) -> Bool {
        entityManager.performAndWait {
            guard !message.isOwnMessage else {
                return false
            }

            if message.isGroupMessage {
                guard let group = self.groupManager.getGroup(conversation: message.conversation) else {
                    return false
                }

                var pushSetting = self.find(forGroup: group.groupIdentity)
                if pushSetting.type == .offPeriod || pushSetting.type == .off {
                    if pushSetting.mentioned {
                        if !TextStyleUtils.isMeOrAllMention(inText: message.contentToCheckForMentions()) {
                            return false
                        }
                    }
                    else {
                        return false
                    }
                }
            }
            else {
                if let sender = message.sender ?? message.conversation.contact {
                    var pushSetting = self.find(forContact: ThreemaIdentity(sender.identity))
                    return !(pushSetting.type == .offPeriod || pushSetting.type == .off)
                }
            }

            return true
        }
    }

    public nonisolated func canMasterDndSendPush() -> Bool {
        if isWorkApp {
            if userSettings.enableMasterDnd {
                let calendar = Calendar.current
                let currentDate = Date()
                let currentWeekDay = calendar.component(.weekday, from: currentDate)

                if let selectedWorkingDays = userSettings.masterDndWorkingDays,
                   selectedWorkingDays.contains(currentWeekDay) {

                    let currentTime = TimeOfDay(
                        hour: calendar.component(.hour, from: currentDate),
                        minute: calendar.component(.minute, from: currentDate)
                    )
                    let startTime = timeOfDayFromTimeString(timeString: userSettings.masterDndStartTime)
                    let endTime = timeOfDayFromTimeString(timeString: userSettings.masterDndEndTime)

                    if currentTime >= startTime, currentTime <= endTime {
                        return true
                    }
                }
                return false
            }
        }

        return true
    }

    // MARK: private functions

    private nonisolated func timeOfDayFromTimeString(timeString: String) -> TimeOfDay {
        let components: [String] = timeString.components(separatedBy: ":")
        return TimeOfDay(hour: Int(components[0])!, minute: Int(components[1])!)
    }

    private nonisolated func decode() throws -> [PushSetting] {
        let decoder = JSONDecoder()

        return try userSettings.pushSettings.map { item in
            guard let data = item as? Data else {
                throw PushSettingManagerError.decodingFailed
            }

            return try decoder.decode(PushSetting.self, from: data)
        }
    }

    private func encode(_ pushSettings: [PushSetting]) throws {
        let encoder = JSONEncoder()

        let items = try pushSettings.map { item in
            try encoder.encode(item)
        }
        userSettings.pushSettings = items
    }
}

@objc public class PushSettingManagerObjc: NSObject {
    @available(*, deprecated, message: "Use PushSettingManager instead")
    @objc public static func canSendPush(for message: BaseMessageEntity, entityManager: EntityManager) -> Bool {
        BusinessInjector(entityManager: entityManager)
            .pushSettingManager.canSendPush(for: message)
    }

    @available(*, deprecated, message: "Use PushSettingManager instead")
    @objc public static func delete(threemaIdentity identity: String, entityManager: EntityManager) {
        Task {
            await BusinessInjector(entityManager: entityManager)
                .pushSettingManager.delete(forContact: ThreemaIdentity(identity))
        }
    }
}
