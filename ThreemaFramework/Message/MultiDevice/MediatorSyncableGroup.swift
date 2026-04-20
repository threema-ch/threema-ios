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
        userSettings: UserSettingsProtocol,
        pushSettingManager: PushSettingManagerProtocol,
        taskManager: TaskManagerProtocol,
        groupManager: GroupManagerProtocol
    ) {
        self.userSettings = userSettings
        self.pushSettingManager = pushSettingManager
        self.taskManager = taskManager
        self.groupManager = groupManager
    }

    init(entityManager: EntityManager, taskManager: TaskManagerProtocol) {
        self.init(
            userSettings: UserSettings.shared(),
            pushSettingManager: PushSettingManager(entityManager: entityManager, taskManager: taskManager),
            taskManager: taskManager,
            groupManager: GroupManager(entityManager: entityManager, taskManager: taskManager)
        )
    }

    func updateAll(identity: GroupIdentity) {
        guard userSettings.enableMultiDevice else {
            return
        }

        guard let group = groupManager.getGroup(identity.id, creator: identity.creator.rawValue) else {
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

        update(identity: identity, profilePicture: group.old_ProfilePicture)
        update(identity: identity, state: group.state)
    }

    func update(identity: GroupIdentity, conversationCategory: ConversationEntity.Category?) {
        guard userSettings.enableMultiDevice else {
            return
        }

        var sGroup = getSyncGroup(identity)
        sGroup.update(conversationCategory: conversationCategory)
        setSyncGroup(sGroup)
    }

    func update(identity: GroupIdentity, conversationVisibility: ConversationEntity.Visibility?) {
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

    func update(identity: GroupIdentity, state: GroupEntity.GroupState) {
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
           task.syncGroup.groupIdentity.creatorIdentity == identity.creator.rawValue {
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
