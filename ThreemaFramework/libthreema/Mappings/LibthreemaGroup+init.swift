import libthreemaSwift
import ThreemaEssentials

extension LibthreemaGroup {
    init(
        groupEntity: GroupEntity,
        conversationEntity: ConversationEntity?,
        userIdentity: ThreemaIdentity,
        pushSettingManager: any PushSettingManagerProtocol
    ) throws {
        #if DEBUG
            if let conversationEntity {
                assert(groupEntity.managedObjectContext === conversationEntity.managedObjectContext)
            }
        #endif

        guard let conversationCategory = LibthreemaConversationCategory(conversationEntity?.conversationCategory) else {
            throw MappingError.conversationCategory
        }

        guard let conversationVisibility = LibthreemaConversationVisibility(conversationEntity?.conversationVisibility)
        else {
            throw MappingError.conversationVisibility
        }

        let groupIdentity = try GroupIdentity(
            id: groupEntity.groupID,
            creator: ThreemaIdentity(identity: groupEntity.groupCreator ?? userIdentity.rawValue)
        )

        var pushSetting = pushSettingManager.find(forGroup: groupIdentity)
        let notificationTriggerPolicyOverride: GroupNotificationTriggerPolicyOverride? =
            switch pushSetting.type {
            case .off:
                GroupNotificationTriggerPolicyOverride(
                    policy: .never,
                    expiresAt: nil
                )
            case .offPeriod:
                GroupNotificationTriggerPolicyOverride(
                    policy: .never,
                    expiresAt: pushSetting.periodOffTillDate?.millisecondsSince1970
                )
            case .on:
                nil
            }

        let membersIdentity: [LibthreemaThreemaID] =
            if let members = conversationEntity?.members {
                members.map { LibthreemaThreemaID($0.identity) }
            }
            else {
                []
            }

        // TODO: (IOS-6243) We haven't a created at for the group so far!
        let createdAt = conversationEntity?.lastUpdate ?? Date.now

        let lastUpdateAt = conversationEntity?.lastUpdate

        guard let groupState = GroupEntity.GroupState(rawValue: groupEntity.state.intValue) else {
            throw MappingError.groupState
        }

        try self.init(
            identity: LibthreemaGroupIdentity(groupIdentity: groupIdentity),
            name: conversationEntity?.groupName ?? String.empty,
            createdAt: createdAt.millisecondsSince1970,
            lastUpdateAt: lastUpdateAt?.millisecondsSince1970,
            userState: UserState(groupState: groupState),
            members: membersIdentity,
            notificationTriggerPolicyOverride: notificationTriggerPolicyOverride,
            conversationCategory: conversationCategory,
            conversationVisibility: conversationVisibility
        )
    }
}
