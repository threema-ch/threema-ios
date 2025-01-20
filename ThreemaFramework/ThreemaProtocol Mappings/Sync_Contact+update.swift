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

import Foundation
import ThreemaProtocols

extension Sync_Contact {
    mutating func update(contact: ContactEntity, pushSetting: PushSetting) {
        let activitySate = contact.state != nil ? ActivityState(rawValue: contact.state!.intValue) : nil
        update(activityState: activitySate)

        update(acquaintanceLevel: contact.isContactHidden ? .groupOrDeleted : .direct)
        update(createdAt: contact.createdAt ?? Date(millisecondsSince1970: 0))
        update(featureMask: contact.featureMask.uint64Value)
        update(firstName: contact.firstName)
        update(identity: contact.identity)
        update(lastName: contact.lastName)
        update(publicKey: contact.publicKey)
        update(nickname: contact.publicNickname)

        var pushSetting = pushSetting
        update(notificationSoundIsMuted: pushSetting.muted)
        update(notificationTriggerType: pushSetting.type, notificationTriggerExpiresAt: pushSetting.periodOffTillDate)

        update(readReceipt: contact.readReceipt)
        update(syncState: SyncState(rawValue: contact.importedStatus.rawValue))
        update(typingIndicator: contact.typingIndicator)
        update(verificationLevel: Sync_Contact.VerificationLevel(rawValue: contact.verificationLevel.intValue))
        update(
            workVerificationLevel: contact.isWorkContact() ? .workSubscriptionVerified : Sync_Contact
                .WorkVerificationLevel.none
        )
    }

    mutating func update(conversation: ConversationEntity) {
        update(conversationCategory: Sync_ConversationCategory(rawValue: conversation.conversationCategory.rawValue))
        update(conversationVisibility: Sync_ConversationVisibility(
            rawValue: conversation.conversationVisibility
                .rawValue
        ))
    }

    mutating func update(acquaintanceLevel: AcquaintanceLevel?) {
        if let acquaintanceLevel {
            self.acquaintanceLevel = acquaintanceLevel
        }
        else if hasAcquaintanceLevel {
            clearAcquaintanceLevel()
        }
    }

    mutating func update(activityState: ActivityState?) {
        if let activityState {
            self.activityState = activityState
        }
        else if hasActivityState {
            clearActivityState()
        }
    }

    mutating func update(conversationCategory: Sync_ConversationCategory?) {
        if let conversationCategory {
            self.conversationCategory = conversationCategory
        }
        else if hasConversationCategory {
            clearConversationCategory()
        }
    }

    mutating func update(conversationVisibility: Sync_ConversationVisibility?) {
        if let conversationVisibility {
            self.conversationVisibility = conversationVisibility
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

    mutating func update(featureMask: UInt64?) {
        if let featureMask {
            self.featureMask = featureMask
        }
        else if hasFeatureMask {
            clearFeatureMask()
        }
    }

    mutating func update(firstName: String?) {
        if let firstName {
            self.firstName = firstName
        }
        else if hasFirstName {
            clearFirstName()
        }
    }

    mutating func update(identity: String) {
        self.identity = identity
    }

    mutating func update(identityType: IdentityType?) {
        if let identityType {
            self.identityType = identityType
        }
        else if hasIdentityType {
            clearIdentityType()
        }
    }

    mutating func update(lastName: String?) {
        if let lastName {
            self.lastName = lastName
        }
        else if hasLastName {
            clearLastName()
        }
    }

    mutating func update(nickname: String?) {
        if let nickname {
            self.nickname = nickname
        }
        else if hasNickname {
            clearNickname()
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

    mutating func update(notificationTriggerType: PushSetting.PushSettingType?, notificationTriggerExpiresAt: Date?) {
        if let notificationTriggerType {
            switch notificationTriggerType {
            case .on:
                notificationTriggerPolicyOverride.override = .default(Common_Unit())
            case .offPeriod:
                if let notificationTriggerExpiresAt {
                    var triggerPolicy = Sync_Contact.NotificationTriggerPolicyOverride.Policy()
                    triggerPolicy.expiresAt = notificationTriggerExpiresAt.millisecondsSince1970.littleEndian
                    triggerPolicy.policy = .never
                    notificationTriggerPolicyOverride.override = .policy(triggerPolicy)
                }
            case .off:
                var triggerPolicy = Sync_Contact.NotificationTriggerPolicyOverride.Policy()
                triggerPolicy.clearExpiresAt()
                triggerPolicy.policy = .never
                notificationTriggerPolicyOverride.override = .policy(triggerPolicy)
            }
        }
        else if hasNotificationTriggerPolicyOverride {
            clearNotificationTriggerPolicyOverride()
        }
    }

    mutating func update(publicKey: Data?) {
        if let publicKey {
            self.publicKey = publicKey
        }
        else if hasPublicKey {
            clearPublicKey()
        }
    }

    mutating func update(readReceipt: ReadReceipt?) {
        if let readReceipt {
            switch readReceipt {
            case .default:
                readReceiptPolicyOverride.override = .default(Common_Unit())
            case .send:
                readReceiptPolicyOverride.override = .policy(.sendReadReceipt)
            case .doNotSend:
                readReceiptPolicyOverride.override = .policy(.dontSendReadReceipt)
            }
        }
        else if hasReadReceiptPolicyOverride {
            clearReadReceiptPolicyOverride()
        }
    }

    mutating func update(syncState: SyncState?) {
        if let syncState {
            self.syncState = syncState
        }
        else if hasSyncState {
            clearSyncState()
        }
    }

    mutating func update(typingIndicator: TypingIndicator?) {
        if let typingIndicator {
            switch typingIndicator {
            case .default:
                typingIndicatorPolicyOverride.override = .default(Common_Unit())
            case .send:
                typingIndicatorPolicyOverride.override = .policy(.sendTypingIndicator)
            case .doNotSend:
                typingIndicatorPolicyOverride.override = .policy(.dontSendTypingIndicator)
            }
        }
        else if hasTypingIndicatorPolicyOverride {
            clearTypingIndicatorPolicyOverride()
        }
    }

    mutating func update(verificationLevel: VerificationLevel?) {
        if let verificationLevel {
            self.verificationLevel = verificationLevel
        }
        else if hasVerificationLevel {
            clearVerificationLevel()
        }
    }

    mutating func update(workVerificationLevel: WorkVerificationLevel?) {
        if let workVerificationLevel {
            self.workVerificationLevel = workVerificationLevel
        }
        else if hasWorkVerificationLevel {
            clearWorkVerificationLevel()
        }
    }
}
