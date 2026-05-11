import ThreemaProtocols

// TODO: Implement (IOS-3869)

extension D2dSync_Group {
    static func from(group: Group) -> D2dSync_Group {
        var syncGroup = D2dSync_Group()

        syncGroup.update(state: group.state)

        return syncGroup
    }

    mutating func update(conversationCategory: ConversationEntity.Category?) {
        if let conversationCategory,
           let category = D2dSync_ConversationCategory(rawValue: conversationCategory.rawValue) {
            self.conversationCategory = category
        }
        else if hasConversationCategory {
            clearConversationCategory()
        }
    }

    mutating func update(conversationVisibility: ConversationEntity.Visibility?) {
        if let conversationVisibility,
           let visibility = D2dSync_ConversationVisibility(rawValue: conversationVisibility.rawValue) {
            self.conversationVisibility = visibility
        }
        else if hasConversationVisibility {
            clearConversationVisibility()
        }
    }

    mutating func update(createdAt: Date?) {
        if let createdAt {
            self.createdAt = createdAt.millisecondsSince1970.littleEndian
        }
        else if hasCreatedAt {
            clearCreatedAt()
        }
    }

    mutating func update(members: Set<String>) {
        memberIdentities.identities = Array(members)
    }

    mutating func update(name: String?) {
        if let name {
            self.name = name
        }
        else if hasName {
            clearName()
        }
    }

    mutating func update(state: GroupEntity.GroupState) {
        switch state {
        case .active:
            userState = .member
        case .forcedLeft:
            userState = .kicked
        case .left:
            userState = .left
        case .requestedSync:
            // No state to sync
            break
        }
    }

    mutating func update(
        notificationTriggerType: PushSetting.PushSettingType?,
        notificationTriggerExpiresAt: Date?,
        notificationTriggerMentioned: Bool
    ) {
        if let notificationTriggerType {
            switch notificationTriggerType {
            case .on:
                notificationTriggerPolicyOverride.override = .default(Common_Unit())
            case .offPeriod:
                if let notificationTriggerExpiresAt {
                    var triggerPolicy = D2dSync_Group.NotificationTriggerPolicyOverride.Policy()
                    triggerPolicy.expiresAt = notificationTriggerExpiresAt.millisecondsSince1970.littleEndian
                    triggerPolicy.policy = notificationTriggerMentioned ? .mentioned : .never
                    notificationTriggerPolicyOverride.override = .policy(triggerPolicy)
                }
            case .off:
                var triggerPolicy = D2dSync_Group.NotificationTriggerPolicyOverride.Policy()
                triggerPolicy.clearExpiresAt()
                triggerPolicy.policy = notificationTriggerMentioned ? .mentioned : .never
                notificationTriggerPolicyOverride.override = .policy(triggerPolicy)
            }
        }
        else if hasNotificationTriggerPolicyOverride {
            clearNotificationTriggerPolicyOverride()
        }
    }
}
