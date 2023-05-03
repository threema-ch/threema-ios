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

actor MediatorSyncableGroup {
    private let serverConnector: ServerConnectorProtocol
    private let taskManager: TaskManagerProtocol
    private let groupManager: GroupManagerProtocol

    private var task: TaskDefinitionGroupSync?

    init(
        _ serverConnector: ServerConnectorProtocol,
        _ taskManager: TaskManagerProtocol,
        _ groupManager: GroupManagerProtocol
    ) {
        self.serverConnector = serverConnector
        self.taskManager = taskManager
        self.groupManager = groupManager
    }

    init() {
        self.init(
            ServerConnector.shared(),
            TaskManager(),
            GroupManager()
        )
    }

    func updateAll(identity: GroupIdentity) {
        guard serverConnector.isMultiDeviceActivated else {
            return
        }

        guard let group = groupManager.getGroup(identity.id, creator: identity.creator) else {
            return
        }

        update(identity: identity, members: group.allMemberIdentities, state: group.state)

        update(identity: identity, name: group.name)

        update(identity: identity, profilePicture: group.photo?.data)

        update(identity: identity, conversationCategory: group.conversationCategory)

        update(identity: identity, conversationVisibility: group.conversationVisibility)

        // TODO: IOS-2825
//        Sync_Group.createdAt
//        Sync_Group.notificationSoundPolicyOverride
//        Sync_Group.notificationTriggerPolicyOverride
    }

    func update(identity: GroupIdentity, members: Set<String>, state: GroupState) {
        guard serverConnector.isMultiDeviceActivated else {
            return
        }

        var sGroup = getSyncGroup(identity: identity)

        sGroup.memberIdentities.identities = Array(members)

        switch state {
        case .active:
            sGroup.userState = .member
        case .forcedLeft:
            sGroup.userState = .kicked
        case .left:
            sGroup.userState = .left
        case .requestedSync:
            sGroup.clearUserState()
        }
        setSyncGroup(syncGroup: sGroup)
    }

    func update(identity: GroupIdentity, name: String?) {
        guard serverConnector.isMultiDeviceActivated else {
            return
        }

        var sGroup = getSyncGroup(identity: identity)
        if let name = name {
            sGroup.name = name
        }
        else {
            sGroup.clearName()
        }
        setSyncGroup(syncGroup: sGroup)
    }

    func update(identity: GroupIdentity, profilePicture: Data?) {
        guard serverConnector.isMultiDeviceActivated else {
            return
        }

        let sGroup = getSyncGroup(identity: identity)
        setSyncGroup(syncGroup: sGroup)
        task?.profilePicture = profilePicture != nil ? .updated : .removed
        task?.image = profilePicture
    }

    func update(identity: GroupIdentity, conversationCategory: ConversationCategory?) {
        guard serverConnector.isMultiDeviceActivated else {
            return
        }

        var sGroup = getSyncGroup(identity: identity)
        if let conversationCategory,
           let category = Sync_ConversationCategory(rawValue: conversationCategory.rawValue) {
            sGroup.conversationCategory = category
        }
        else {
            sGroup.clearConversationCategory()
        }
        setSyncGroup(syncGroup: sGroup)
    }

    func update(identity: GroupIdentity, conversationVisibility: ConversationVisibility?) {
        guard serverConnector.isMultiDeviceActivated else {
            return
        }

        var sGroup = getSyncGroup(identity: identity)
        if let conversationVisibility,
           let visibility = Sync_ConversationVisibility(rawValue: conversationVisibility.rawValue) {
            sGroup.conversationVisibility = visibility
        }
        else {
            sGroup.clearConversationVisibility()
        }
        setSyncGroup(syncGroup: sGroup)
    }

    func deleteAndSync(identity: GroupIdentity) {
        guard serverConnector.isMultiDeviceActivated else {
            return
        }

        let sGroup = getSyncGroup(identity: identity)
        setSyncGroup(syncGroup: sGroup)

        sync(syncAction: .delete)
    }

    func sync(syncAction: TaskDefinitionGroupSync.SyncAction) {
        if let task = task {
            task.syncAction = syncAction
            taskManager.add(taskDefinition: task)
        }
    }

    // MARK: Private functions

    private func getSyncGroup(identity: GroupIdentity) -> Sync_Group {
        if let task = task,
           task.syncGroup.groupIdentity.groupID == identity.id.convert(),
           task.syncGroup.groupIdentity.creatorIdentity == identity.creator {
            return task.syncGroup
        }
        else {
            var sGroup = Sync_Group()
            var sGroupIdentity = Common_GroupIdentity()
            sGroupIdentity.groupID = identity.id.convert()
            sGroupIdentity.creatorIdentity = identity.creator
            sGroup.groupIdentity = sGroupIdentity
            return sGroup
        }
    }

    private func setSyncGroup(syncGroup: Sync_Group) {
        if task == nil {
            task = TaskDefinitionGroupSync(syncGroup: syncGroup, syncAction: .update)
        }
        task?.syncGroup = syncGroup
    }
}
