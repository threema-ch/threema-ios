import libthreemaSwift
import Testing
import ThreemaEssentials
@testable import ThreemaFramework

struct LibthreemaContactTests {

    @Test("Convert libthreema Contact to ContactEntity", arguments: [
        ("First name", "Last name", "Nickname"),
        (String.empty, String.empty, String.empty),
    ])
    func convertLibthreemaContactToContactEntityAndConversationEntity(
        expectedFirstName: String,
        expectedLastName: String,
        expectedNickname: String,
    ) async throws {
        let testDatabase = TestDatabase()

        let expectedIdentity = "ECHOECHO"
        let expectedPublicKey = BytesUtility.generatePublicKey()
        let expectedCreateAtDate = Date.now.addingTimeInterval(-10)
        let expectedLastUpdateAtDate = Date.now
        let expectedFeatureMask = UInt64(101)

        // Prepare

        let contact = LibthreemaContact(
            identity: LibthreemaThreemaID(expectedIdentity),
            publicKey: PublicKey(expectedPublicKey),
            createdAt: expectedCreateAtDate.millisecondsSince1970,
            lastUpdateAt: expectedLastUpdateAtDate.millisecondsSince1970,
            firstName: expectedFirstName,
            lastName: expectedLastName,
            nickname: expectedNickname,
            verificationLevel: .fullyVerified,
            workVerificationLevel: .workSubscriptionVerified,
            identityType: .work,
            acquaintanceLevel: .direct,
            activityState: .active,
            featureMask: expectedFeatureMask,
            syncState: .initial,
            workLastFullSyncAt: nil,
            workAvailabilityStatus: nil,
            readReceiptPolicyOverride: .sendReadReceipt,
            typingIndicatorPolicyOverride: .sendTypingIndicator,
            notificationTriggerPolicyOverride: .none,
            conversationCategory: .protected,
            conversationVisibility: .archived
        )

        // Act

        let contactEntity = ContactEntity(
            context: testDatabase.context.current,
            identity: expectedIdentity,
            publicKey: expectedPublicKey,
            sortOrderFirstName: true
        )
        try contactEntity.update(with: contact, sortOrderFirstName: true)

        #expect(contactEntity.identity == expectedIdentity)
        #expect(contactEntity.publicKey.elementsEqual(expectedPublicKey))
        #expect(contactEntity.createdAt?.millisecondsSince1970 == expectedCreateAtDate.millisecondsSince1970)
        #expect(contactEntity.firstName == (expectedFirstName.isEmpty ? nil : expectedFirstName))
        #expect(contactEntity.lastName == (expectedLastName.isEmpty ? nil : expectedLastName))
        #expect(contactEntity.publicNickname == (expectedNickname.isEmpty ? nil : expectedNickname))
        #expect(contactEntity.contactVerificationLevel == .fullyVerified)
        #expect(contactEntity.isWorkContact)
        #expect(!contactEntity.isHidden)
        #expect(contactEntity.contactState == .active)
        #expect(contactEntity.featureMask.uint64Value == expectedFeatureMask)
        #expect(contactEntity.contactImportStatus == .initial)
        #expect(contactEntity.readReceipt == .send)
        #expect(contactEntity.typingIndicator == .send)
        #expect(contactEntity.workLastFullSyncAt == nil)
        #expect(contactEntity.workAvailabilityStatus == nil)

        let conversationEntity = ConversationEntity(context: testDatabase.context.current, contact: contactEntity)
        try conversationEntity.update(with: contact)

        #expect(conversationEntity.contact == contactEntity)
        #expect(conversationEntity.lastUpdate?.millisecondsSince1970 == expectedLastUpdateAtDate.millisecondsSince1970)
        #expect(conversationEntity.conversationCategory == .private)
        #expect(conversationEntity.conversationVisibility == .archived)
    }

    @Test func convertContactEntityToLibthreemaContact() async throws {
        let testDatabase = TestDatabase()
        let userSettingsMock = UserSettingsMock()

        let expectedIdentity = "ECHOECHO"
        let expectedPublicKey = BytesUtility.generatePublicKey()

        // Prepare

        let contactEntity = ContactEntity(
            context: testDatabase.context.current,
            identity: expectedIdentity,
            publicKey: expectedPublicKey,
            sortOrderFirstName: true
        )

        // Act

        let contact = try LibthreemaContact(
            contactEntity: contactEntity,
            userSettings: userSettingsMock,
            pushSettingManager: PushSettingManagerMock()
        )

        #expect(contact.identity == expectedIdentity)
        #expect(contact.publicKey.elementsEqual(expectedPublicKey))
        #expect(contact.createdAt != 0)
        #expect(contact.firstName.isEmpty)
        #expect(contact.lastName.isEmpty)
        #expect(contact.nickname.isEmpty)
        #expect(contact.verificationLevel == .unverified)
        #expect(contact.workVerificationLevel == .none)
        #expect(contact.identityType == .regular)
        #expect(contact.acquaintanceLevel == .direct)
        #expect(contact.activityState == .active)
        #expect(contact.featureMask == 0)
        #expect(contact.syncState == .initial)
        #expect(contact.readReceiptPolicyOverride == nil)
        #expect(contact.typingIndicatorPolicyOverride == nil)
        #expect(contact.notificationTriggerPolicyOverride == nil)
        #expect(contact.conversationCategory == .default)
        #expect(contact.conversationVisibility == .normal)
        #expect(contact.workAvailabilityStatus == nil)
        #expect(contact.workLastFullSyncAt == nil)
    }

    @Test func convertContactEntityAndConversationEntityToLibthreemaContact() async throws {
        let testDatabase = TestDatabase()
        let userSettingsMock = UserSettingsMock()

        let expectedIdentity = "ECHOECHO"
        let expectedImportStatus: ContactEntity.ImportStatus = .imported
        let expectedPublicKey = BytesUtility.generatePublicKey()
        let expectedCreateAtDate = Date.now.addingTimeInterval(-10)
        let expectedLastUpdateAtDate = Date.now
        let expectedFirstName = "First name"
        let expectedLastName = "Last name"
        let expectedNickname = "Nick name"
        let expectedJobTitle = "Job title"
        let expectedDepartment = "Department"
        let expectedFeatureMask = 101
        let expectedReadReceipt: ContactEntity.ReadReceipt = .doNotSend
        let expectedTypingIndicator: ContactEntity.TypingIndicator = .doNotSend
        let expectedVerificationLevel: ContactEntity.VerificationLevel = .serverVerified
        let expectedWorkAvailabilityStatus = ThreemaFramework.WorkAvailabilityStatus.Category.busy
        let expectedWorkAvailabilityStatusText = "Holiday"
        let expectedWorkLastFullSyncAt = Date()

        userSettingsMock.workIdentities = [expectedIdentity]

        // Prepare

        let contactEntity = ContactEntity(
            context: testDatabase.context.current,
            createdAt: expectedCreateAtDate,
            department: expectedDepartment,
            featureMask: expectedFeatureMask,
            firstName: expectedFirstName,
            forwardSecurityState: NSNumber(integerLiteral: Int(ForwardSecurityState.off.rawValue)),
            identity: expectedIdentity,
            importStatus: NSNumber(integerLiteral: expectedImportStatus.rawValue),
            jobTitle: expectedJobTitle,
            lastName: expectedLastName,
            publicKey: expectedPublicKey,
            publicNickname: expectedNickname,
            readReceipts: NSNumber(integerLiteral: expectedReadReceipt.rawValue),
            typingIndicators: NSNumber(integerLiteral: expectedTypingIndicator.rawValue),
            verificationLevel: NSNumber(integerLiteral: expectedVerificationLevel.rawValue),
            sortOrderFirstName: true,
            workLastFullSyncAt: expectedWorkLastFullSyncAt
        )

        _ = WorkAvailabilityStatusEntity(
            context: testDatabase.context.current,
            value: expectedWorkAvailabilityStatus.rawValue,
            text: expectedWorkAvailabilityStatusText,
            contact: contactEntity
        )

        let conversationEntity = ConversationEntity(
            context: testDatabase.context.current,
            category: .private,
            lastUpdate: expectedLastUpdateAtDate,
            visibility: .pinned
        )

        // Act

        let contact = try LibthreemaContact(
            contactEntity: contactEntity,
            conversationEntity: conversationEntity,
            userSettings: userSettingsMock,
            pushSettingManager: PushSettingManagerMock()
        )

        #expect(contact.identity == expectedIdentity)

        #expect(contact.publicKey.elementsEqual(expectedPublicKey))
        #expect(contact.createdAt == expectedCreateAtDate.millisecondsSince1970)
        #expect(contact.firstName == expectedFirstName)
        #expect(contact.lastName == expectedLastName)
        #expect(contact.nickname == expectedNickname)
        #expect(contact.verificationLevel == .serverVerified)
        #expect(contact.workVerificationLevel == .none)
        #expect(contact.identityType == .work)
        #expect(contact.acquaintanceLevel == .direct)
        #expect(contact.activityState == .inactive)
        #expect(contact.featureMask == expectedFeatureMask)
        #expect(contact.syncState == .imported)
        #expect(contact.readReceiptPolicyOverride == .dontSendReadReceipt)
        #expect(contact.typingIndicatorPolicyOverride == .dontSendTypingIndicator)
        #expect(contact.notificationTriggerPolicyOverride == nil)
        #expect(contact.conversationCategory == .protected)
        #expect(contact.conversationVisibility == .pinned)
        #expect(contact.workAvailabilityStatus == .busy(expectedWorkAvailabilityStatusText))
        #expect(contact.workLastFullSyncAt == expectedWorkLastFullSyncAt.millisecondsSince1970.littleEndian)
    }

    @Test("Update ContactEntity with LibthreemaContactEntity", arguments: [
        (
            nil,
            nil,
            nil,
            nil,
            nil,
            nil,
            nil,
            nil,
            nil,
            DeltaReadReceiptPolicy.unchanged,
            DeltaTypingIndicatorPolicy.unchanged,
            nil,
            nil
        ),
        (
            String.empty,
            String.empty,
            String.empty,
            LibthreemaVerificationLevel.unverified,
            LibthreemaWorkVerificationLevel.none,
            LibthreemaAcquaintanceLevel.groupOrDeleted,
            LibthreemaActivityState.inactive,
            libthreemaSwift.FeatureMask(101),
            LibthreemaSyncState.initial,
            DeltaReadReceiptPolicy.remove,
            DeltaTypingIndicatorPolicy.remove,
            ConversationCategory.default,
            ConversationVisibility.normal
        ),
        (
            "First name updated",
            "Last name updated",
            "Nickname updated",
            LibthreemaVerificationLevel.fullyVerified,
            LibthreemaWorkVerificationLevel.workSubscriptionVerified,
            LibthreemaAcquaintanceLevel.direct,
            LibthreemaActivityState.active,
            libthreemaSwift.FeatureMask(102),
            LibthreemaSyncState.imported,
            DeltaReadReceiptPolicy.update(.dontSendReadReceipt),
            DeltaTypingIndicatorPolicy.update(.dontSendTypingIndicator),
            ConversationCategory.protected,
            ConversationVisibility.pinned
        ),
    ])
    func unpdateContactEntityWithLibthreemaContactUpdate(
        updatedFirstName: String?,
        updatedLastName: String?,
        updatedNickname: String?,
        updatedVerificationLevel: LibthreemaVerificationLevel?,
        updatedWorkVerificationLevel: LibthreemaWorkVerificationLevel?,
        updatedAcquaintanceLevel: LibthreemaAcquaintanceLevel?,
        updatedActivityState: LibthreemaActivityState?,
        updatedFeatureMask: libthreemaSwift.FeatureMask?,
        updatedSyncState: LibthreemaSyncState?,
        updatedReadReceiptPolicyOverride: DeltaReadReceiptPolicy,
        updatedTypingIndicatorPolicyOverride: DeltaTypingIndicatorPolicy,
        updatedConversationCategory: ConversationCategory?,
        updatedConversationVisibility: ConversationVisibility?
    ) async throws {
        let testDatabase = TestDatabase()
        let userSettingsMock = UserSettingsMock()

        let expectedIdentity = "ECHOECHO"
        let expectedPublicKey = BytesUtility.generatePublicKey()
        let expectedCreateAtDate = Date.now.addingTimeInterval(-10)
        let expectedLastUpdateAtDate = Date.now
        let expectedJobTitle = "Job title"
        let expectedDepartment = "Department"

        // Inital field values of the `ContactEntity`
        let expectedFirstName = "First name"
        let expectedLastName = "Last name"
        let expectedNickname = "Nickname"
        let expectedVerificationLevel: ContactEntity.VerificationLevel = .serverVerified
        let expectedWorkContact: WorkContact = false
        let expectedHiddenContact: HiddenContact = true
        let expectedContactState: ContactEntity.ContactState = .invalid
        let expectedFeatureMask: UInt64 = 100
        let expectedImportStatus: ContactEntity.ImportStatus = .imported
        let expectedReadReceipt: ContactEntity.ReadReceipt = .send
        let expectedTypingIndicator: ContactEntity.TypingIndicator = .send

        // Inital field values of the `ConversationEntity`
        let expectedCategory: ConversationEntity.Category = .private
        let expectedVisibility: ConversationEntity.Visibility = .archived

        // Prepare

        let contactEntity = ContactEntity(
            context: testDatabase.context.current,
            createdAt: expectedCreateAtDate,
            department: expectedDepartment,
            featureMask: Int(expectedFeatureMask),
            firstName: expectedFirstName,
            forwardSecurityState: NSNumber(integerLiteral: Int(ForwardSecurityState.off.rawValue)),
            hidden: NSNumber(booleanLiteral: expectedHiddenContact),
            identity: expectedIdentity,
            importStatus: NSNumber(integerLiteral: expectedImportStatus.rawValue),
            jobTitle: expectedJobTitle,
            lastName: expectedLastName,
            publicKey: expectedPublicKey,
            publicNickname: expectedNickname,
            readReceipts: NSNumber(integerLiteral: expectedReadReceipt.rawValue),
            state: NSNumber(integerLiteral: expectedContactState.rawValue),
            typingIndicators: NSNumber(integerLiteral: expectedTypingIndicator.rawValue),
            verificationLevel: NSNumber(integerLiteral: expectedVerificationLevel.rawValue),
            workContact: NSNumber(booleanLiteral: expectedWorkContact),
            sortOrderFirstName: userSettingsMock.sortOrderFirstName
        )

        let conversationEntity = ConversationEntity(
            context: testDatabase.context.current,
            category: expectedCategory,
            lastUpdate: expectedLastUpdateAtDate,
            visibility: expectedVisibility
        )

        let contact = LibthreemaContactUpdate(
            identity: expectedIdentity,
            firstName: updatedFirstName,
            lastName: updatedLastName,
            nickname: updatedNickname,
            verificationLevel: updatedVerificationLevel,
            workVerificationLevel: updatedWorkVerificationLevel,
            identityType: nil,
            acquaintanceLevel: updatedAcquaintanceLevel,
            activityState: updatedActivityState,
            featureMask: updatedFeatureMask,
            syncState: updatedSyncState,
            readReceiptPolicyOverride: updatedReadReceiptPolicyOverride,
            typingIndicatorPolicyOverride: updatedTypingIndicatorPolicyOverride,
            notificationTriggerPolicyOverride: .unchanged,
            conversationCategory: updatedConversationCategory,
            conversationVisibility: updatedConversationVisibility,
        )

        // Act

        try contactEntity.update(with: contact, sortOrderFirstName: userSettingsMock.sortOrderFirstName)

        #expect(contactEntity.identity == expectedIdentity)
        #expect(contactEntity.publicKey.elementsEqual(expectedPublicKey))
        #expect(contactEntity.createdAt?.millisecondsSince1970 == expectedCreateAtDate.millisecondsSince1970)
        #expect(contactEntity.jobTitle == expectedJobTitle)
        #expect(contactEntity.department == expectedDepartment)

        // Test updated fields of the `ContactEntity`

        if let updatedFirstName {
            #expect(contactEntity.firstName == (updatedFirstName.isEmpty ? nil : updatedFirstName))
        }
        else {
            #expect(contactEntity.firstName == expectedFirstName)
        }

        if let updatedLastName {
            #expect(contactEntity.lastName == (updatedLastName.isEmpty ? nil : updatedLastName))
        }
        else {
            #expect(contactEntity.lastName == expectedLastName)
        }

        if let updatedNickname {
            #expect(contactEntity.publicNickname == (updatedNickname.isEmpty ? nil : updatedNickname))
        }
        else {
            #expect(contactEntity.publicNickname == expectedNickname)
        }

        if let updatedVerificationLevel {
            #expect(contactEntity.contactVerificationLevel == ContactEntity.VerificationLevel(updatedVerificationLevel))
        }
        else {
            #expect(contactEntity.contactVerificationLevel == expectedVerificationLevel)
        }

        if let updatedWorkVerificationLevel {
            #expect(contactEntity.workContact?.boolValue == WorkContact(updatedWorkVerificationLevel))
        }
        else {
            #expect(contactEntity.workContact?.boolValue == expectedWorkContact)
        }

        if let updatedAcquaintanceLevel {
            #expect(contactEntity.isHidden == HiddenContact(updatedAcquaintanceLevel))
        }
        else {
            #expect(contactEntity.isHidden == expectedHiddenContact)
        }

        if let updatedActivityState {
            #expect(contactEntity.contactState == ContactEntity.ContactState(updatedActivityState))
        }
        else {
            #expect(contactEntity.contactState == expectedContactState)
        }

        if let updatedFeatureMask {
            #expect(contactEntity.featureMask.uint64Value == updatedFeatureMask)
        }
        else {
            #expect(contactEntity.featureMask.uint64Value == expectedFeatureMask)
        }

        if let updatedSyncState {
            #expect(contactEntity.contactImportStatus == ContactEntity.ImportStatus(updatedSyncState))
        }
        else {
            #expect(contactEntity.contactImportStatus == expectedImportStatus)
        }

        switch updatedReadReceiptPolicyOverride {
        case .remove:
            #expect(contactEntity.readReceipt == .default)
        case .unchanged:
            #expect(contactEntity.readReceipt == expectedReadReceipt)
        case let .update(readReceiptPolicy):
            #expect(contactEntity.readReceipt == ContactEntity.ReadReceipt(readReceiptPolicy))
        }

        switch updatedTypingIndicatorPolicyOverride {
        case .remove:
            #expect(contactEntity.typingIndicator == .default)
        case .unchanged:
            #expect(contactEntity.typingIndicator == expectedTypingIndicator)
        case let .update(typingIndicatorPolicy):
            #expect(contactEntity.typingIndicator == ContactEntity.TypingIndicator(typingIndicatorPolicy))
        }

        // Test updated fields of the `ConversationEntity`

        try conversationEntity.update(with: contact)

        if let updatedConversationCategory {
            #expect(conversationEntity.conversationCategory == ConversationEntity.Category(updatedConversationCategory))
        }
        else {
            #expect(conversationEntity.conversationCategory == expectedCategory)
        }

        if let updatedConversationVisibility {
            #expect(
                conversationEntity.conversationVisibility == ConversationEntity.Visibility(updatedConversationVisibility)
            )
        }
        else {
            #expect(conversationEntity.conversationVisibility == expectedVisibility)
        }
    }
}
