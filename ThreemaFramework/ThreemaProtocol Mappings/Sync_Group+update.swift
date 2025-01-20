//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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

import ThreemaProtocols

// TODO: Implement (IOS-3869)

extension Sync_Group {
    static func from(group: Group) -> Sync_Group {
        var syncGroup = Sync_Group()

        syncGroup.update(state: group.state)

        return syncGroup
    }

    mutating func update(conversationCategory: ConversationEntity.Category?) {
        if let conversationCategory,
           let category = Sync_ConversationCategory(rawValue: conversationCategory.rawValue) {
            self.conversationCategory = category
        }
        else if hasConversationCategory {
            clearConversationCategory()
        }
    }

    mutating func update(conversationVisibility: ConversationEntity.Visibility?) {
        if let conversationVisibility,
           let visibility = Sync_ConversationVisibility(rawValue: conversationVisibility.rawValue) {
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

    mutating func update(notificationSoundIsMuted: Bool?) {
        if let notificationSoundIsMuted {
            notificationSoundPolicyOverride
                .override = notificationSoundIsMuted ? .policy(.muted) : .default(Common_Unit())
        }
        else if hasNotificationSoundPolicyOverride {
            clearNotificationSoundPolicyOverride()
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
                    var triggerPolicy = Sync_Group.NotificationTriggerPolicyOverride.Policy()
                    triggerPolicy.expiresAt = notificationTriggerExpiresAt.millisecondsSince1970.littleEndian
                    triggerPolicy.policy = notificationTriggerMentioned ? .mentioned : .never
                    notificationTriggerPolicyOverride.override = .policy(triggerPolicy)
                }
            case .off:
                var triggerPolicy = Sync_Group.NotificationTriggerPolicyOverride.Policy()
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
