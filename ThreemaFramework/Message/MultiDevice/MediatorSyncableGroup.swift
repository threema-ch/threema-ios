//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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
import ThreemaEssentials
import ThreemaProtocols

actor MediatorSyncableGroup {
    private let userSettings: UserSettingsProtocol
    private let pushSettingManager: PushSettingManagerProtocol
    private let taskManager: TaskManagerProtocol
    private let groupManager: GroupManagerProtocol

    private var task: TaskDefinitionGroupSync?

    init(
        _ userSettings: UserSettingsProtocol,
        _ pushSettingManager: PushSettingManagerProtocol,
        _ taskManager: TaskManagerProtocol,
        _ groupManager: GroupManagerProtocol
    ) {
        self.userSettings = userSettings
        self.pushSettingManager = pushSettingManager
        self.taskManager = taskManager
        self.groupManager = groupManager
    }

    init() {
        self.init(
            UserSettings.shared(),
            PushSettingManager(),
            TaskManager(),
            GroupManager()
        )
    }

    func updateAll(identity: GroupIdentity) {
        guard userSettings.enableMultiDevice else {
            return
        }

        guard let group = groupManager.getGroup(identity.id, creator: identity.creator.string) else {
            return
        }

        // update(identity: identity, createdAt: nil) -> TODO: IOS-2825
        update(identity: identity, conversationCategory: group.conversationCategory)
        update(identity: identity, conversationVisibility: group.conversationVisibility)
        update(identity: identity, members: Set(group.allActiveMemberIdentitiesWithoutCreator))
        update(identity: identity, name: group.name)

        var pushSetting = pushSettingManager.find(forGroup: identity)
        updateNotificationSound(identity: identity, isMuted: pushSetting.muted)
        updateNotificationTrigger(
            identity: identity,
            type: pushSetting.type,
            expiresAt: pushSetting.periodOffTillDate,
            mentioned: pushSetting.mentioned
        )

        update(identity: identity, profilePicture: group.profilePicture)
        update(identity: identity, state: group.state)
    }

    func update(identity: GroupIdentity, conversationCategory: ConversationCategory?) {
        guard userSettings.enableMultiDevice else {
            return
        }

        var sGroup = getSyncGroup(identity)
        sGroup.update(conversationCategory: conversationCategory)
        setSyncGroup(sGroup)
    }

    func update(identity: GroupIdentity, conversationVisibility: ConversationVisibility?) {
        guard userSettings.enableMultiDevice else {
            return
        }

        var sGroup = getSyncGroup(identity)
        sGroup.update(conversationVisibility: conversationVisibility)
        setSyncGroup(sGroup)
    }

    func update(identity: GroupIdentity, createdAt: Date?) {
        guard userSettings.enableMultiDevice else {
            return
        }

        var sGroup = getSyncGroup(identity)
        sGroup.update(createdAt: createdAt)
        setSyncGroup(sGroup)
    }

    func update(identity: GroupIdentity, members: Set<String>) {
        guard userSettings.enableMultiDevice else {
            return
        }

        var sGroup = getSyncGroup(identity)
        sGroup.memberIdentities.identities = Array(members)
        setSyncGroup(sGroup)
    }

    func update(identity: GroupIdentity, name: String?) {
        guard userSettings.enableMultiDevice else {
            return
        }

        var sGroup = getSyncGroup(identity)
        sGroup.update(name: name)
        setSyncGroup(sGroup)
    }

    func update(identity: GroupIdentity, profilePicture: Data?) {
        guard userSettings.enableMultiDevice else {
            return
        }

        let sGroup = getSyncGroup(identity)
        setSyncGroup(sGroup)
        task?.profilePicture = profilePicture != nil ? .updated : .removed
        task?.image = profilePicture
    }

    func update(identity: GroupIdentity, state: GroupState) {
        guard userSettings.enableMultiDevice else {
            return
        }

        var sGroup = getSyncGroup(identity)
        sGroup.update(state: state)
        setSyncGroup(sGroup)
    }

    func updateNotificationSound(identity: GroupIdentity, isMuted: Bool?) {
        guard userSettings.enableMultiDevice else {
            return
        }

        var sGroup = getSyncGroup(identity)
        sGroup.update(notificationSoundIsMuted: isMuted)
        setSyncGroup(sGroup)
    }

    func updateNotificationTrigger(
        identity: GroupIdentity,
        type: PushSetting.PushSettingType?,
        expiresAt: Date?,
        mentioned: Bool
    ) {
        guard userSettings.enableMultiDevice else {
            return
        }

        var sGroup = getSyncGroup(identity)
        sGroup.update(
            notificationTriggerType: type,
            notificationTriggerExpiresAt: expiresAt,
            notificationTriggerMentioned: mentioned
        )
        setSyncGroup(sGroup)
    }

    func deleteAndSync(_ identity: GroupIdentity) {
        guard userSettings.enableMultiDevice else {
            return
        }

        let sGroup = getSyncGroup(identity)
        setSyncGroup(sGroup)

        sync(syncAction: .delete)
    }

    func sync(syncAction: TaskDefinitionGroupSync.SyncAction) {
        if let task {
            task.syncAction = syncAction
            taskManager.add(taskDefinition: task)
        }
    }

    // MARK: Private functions

    private func getSyncGroup(_ identity: GroupIdentity) -> Sync_Group {
        if let task,
           task.syncGroup.groupIdentity.groupID == identity.id.paddedLittleEndian(),
           task.syncGroup.groupIdentity.creatorIdentity == identity.creator.string {
            return task.syncGroup
        }
        else {
            var sGroup = Sync_Group()
            sGroup.groupIdentity = Common_GroupIdentity.from(identity)
            return sGroup
        }
    }

    private func setSyncGroup(_ syncGroup: Sync_Group) {
        if task == nil {
            task = TaskDefinitionGroupSync(syncGroup: syncGroup, syncAction: .update)
        }
        task?.syncGroup = syncGroup
    }
}
