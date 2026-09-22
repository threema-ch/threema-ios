import libthreemaSwift
import ThreemaEssentials

extension LibthreemaContact {
    init(
        contactEntity: ContactEntity,
        conversationEntity: ConversationEntity? = nil,
        userSettings: UserSettingsProtocol,
        pushSettingManager: PushSettingManagerProtocol
    ) throws {
        #if DEBUG
            if let conversationEntity {
                assert(contactEntity.managedObjectContext === conversationEntity.managedObjectContext)
            }
        #endif

        let identityType: IdentityType =
            if let workIdentities = userSettings.workIdentities,
            workIdentities.contains(contactEntity.identity) {
                .work
            }
            else {
                .regular
            }

        var notificationTriggerPolicyOverride: LibthreemaContactNotificationTriggerPolicyOverride?
        var pushSetting = pushSettingManager.find(forContact: contactEntity.threemaIdentity)
        switch pushSetting.type {
        case .off:
            notificationTriggerPolicyOverride = LibthreemaContactNotificationTriggerPolicyOverride(
                policy: .never,
                expiresAt: nil
            )
        case .offPeriod:
            if let periodOffTillDate = pushSetting.periodOffTillDate {
                notificationTriggerPolicyOverride = LibthreemaContactNotificationTriggerPolicyOverride(
                    policy: .never,
                    expiresAt: periodOffTillDate.millisecondsSince1970
                )
            }
            else {
                notificationTriggerPolicyOverride = LibthreemaContactNotificationTriggerPolicyOverride(
                    policy: .never,
                    expiresAt: nil
                )
            }
        case .on:
            notificationTriggerPolicyOverride = nil
        }

        guard let verificationLevel = LibthreemaVerificationLevel(contactEntity.contactVerificationLevel) else {
            throw MappingError.verificationLevel
        }

        guard let workVersificationLevel = LibthreemaWorkVerificationLevel(contactEntity.isWorkContact) else {
            throw MappingError.workVersificationLevel
        }

        guard let acquaintanceLevel = LibthreemaAcquaintanceLevel(contactEntity.isHidden) else {
            throw MappingError.acquaintanceLevel
        }

        guard let activityState = LibthreemaActivityState(contactEntity.contactState) else {
            throw MappingError.activityState
        }

        guard let syncState = LibthreemaSyncState(contactEntity.contactImportStatus) else {
            throw MappingError.syncState
        }

        guard let conversationCategory = LibthreemaConversationCategory(conversationEntity?.conversationCategory) else {
            throw MappingError.conversationCategory
        }

        guard let conversationVisibility = LibthreemaConversationVisibility(conversationEntity?.conversationVisibility)
        else {
            throw MappingError.conversationVisibility
        }

        self.init(
            identity: LibthreemaThreemaID(contactEntity.identity),
            publicKey: PublicKey(contactEntity.publicKey),
            createdAt: contactEntity.createdAt?.millisecondsSince1970 ?? Date.now.millisecondsSince1970,
            lastUpdateAt: conversationEntity?.lastUpdate?.millisecondsSince1970,
            firstName: contactEntity.firstName ?? String.empty,
            lastName: contactEntity.lastName ?? String.empty,
            nickname: contactEntity.publicNickname ?? String.empty,
            verificationLevel: verificationLevel,
            workVerificationLevel: workVersificationLevel,
            identityType: identityType,
            acquaintanceLevel: acquaintanceLevel,
            activityState: activityState,
            featureMask: contactEntity.featureMask.uint64Value,
            syncState: syncState,
            workLastFullSyncAt: nil,
            workAvailabilityStatus: nil,
            readReceiptPolicyOverride: LibthreemaReadReceiptPolicy(contactEntity.readReceipt),
            typingIndicatorPolicyOverride: LibthreemaTypingIndicatorPolicy(contactEntity.typingIndicator),
            notificationTriggerPolicyOverride: notificationTriggerPolicyOverride,
            conversationCategory: conversationCategory,
            conversationVisibility: conversationVisibility
        )
    }
}
