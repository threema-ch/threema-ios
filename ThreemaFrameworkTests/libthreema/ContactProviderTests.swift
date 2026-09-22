import libthreemaSwift
import Testing
import ThreemaEssentials
import UIKit
@testable import ThreemaFramework

@Suite("Test libthreema ContactProvider")
struct ContactProviderTests {

    @Test func `is explicitly blocked throws invalid parameter when identity equals user identity`() throws {
        let myIdentityStore = MyIdentityStoreMock()
        myIdentityStore.identity = "AAAAAAAA"

        let (contactProvider, _, _, _, _, _) = try makeSUT(myIdentityStoreMock: myIdentityStore)

        let expectedError = ProviderError.InvalidParameter(
            "Identity must not be the user's own identity."
        )

        #expect(throws: expectedError) { try contactProvider.isExplicitlyBlocked(identity: "AAAAAAAA") }
    }

    @Test func `is explicitly blocked returns true when identity in blacklist`() throws {
        let myIdentityStore = MyIdentityStoreMock()
        myIdentityStore.identity = "AAAAAAAA"

        let userSettings = UserSettingsMock()
        userSettings.blacklist = NSOrderedSet(array: ["BBBBBBBB", "CCCCCCCC"])

        let (contactProvider, _, _, _, _, _) = try makeSUT(
            myIdentityStoreMock: myIdentityStore,
            userSettingsMock: userSettings
        )

        #expect(try contactProvider.isExplicitlyBlocked(identity: "BBBBBBBB") == true)
    }

    @Test func `is explicitly blocked returns false when identity not in blacklist`() throws {
        let myIdentityStore = MyIdentityStoreMock()
        myIdentityStore.identity = "AAAAAAAA"

        let userSettings = UserSettingsMock()
        userSettings.blacklist = NSOrderedSet(array: ["CCCCCCCC"])

        let (contactProvider, _, _, _, _, _) = try makeSUT(
            myIdentityStoreMock: myIdentityStore,
            userSettingsMock: userSettings
        )

        #expect(try contactProvider.isExplicitlyBlocked(identity: "BBBBBBBB") == false)
    }

    @Test func `is explicitly blocked returns false when blacklist empty`() throws {
        let myIdentityStore = MockMyIdentityStore()
        myIdentityStore.identity = "AAAAAAAA"

        let userSettings = UserSettingsMock()
        userSettings.blacklist = NSOrderedSet()

        let (contactProvider, _, _, _, _, _) = try makeSUT(
            myIdentityStoreMock: myIdentityStore,
            userSettingsMock: userSettings
        )

        #expect(try contactProvider.isExplicitlyBlocked(identity: "BBBBBBBB") == false)
    }

    @Test("Has identity", arguments: [
        (LibthreemaThreemaID("TESTID01"), true),
        (LibthreemaThreemaID("TESTID02"), false),
    ])
    func has(expectedIdentity: LibthreemaThreemaID, isExists: Bool) async throws {
        let (contactProvider, _, _, _, _, testDatabase) = try makeSUT()

        testDatabase.preparer.createContact(identity: "TESTID01")

        let result = try contactProvider.has(identity: expectedIdentity)

        #expect(result == isExists)
    }

    @Test("Count of exists identities", arguments: [
        (["TESTID01"], 1),
        (["TESTID01", "TESTID02"], 2),
        (["TESTID01", "TESTID02", "TESTID03"], 2),
    ])
    func countExisting(expectedIdentities: [String], countExisting: Int) async throws {
        let (contactProvider, _, _, _, _, testDatabase) = try makeSUT()

        testDatabase.preparer.createContact(identity: "TESTID01")
        testDatabase.preparer.createContact(identity: "TESTID02")

        let result = try contactProvider.countExisting(
            identities: expectedIdentities.map { LibthreemaThreemaID($0) }
        )

        #expect(result == countExisting)
    }

    @Test
    func getAllIdentities() async throws {
        let (contactProvider, _, _, _, _, testDatabase) = try makeSUT()

        testDatabase.preparer.save {
            testDatabase.preparer.createContact(identity: "TESTID01")
            testDatabase.preparer.createContact(identity: "TESTID02")
        }

        let identities = try contactProvider.getIdentities()

        #expect(identities.count(where: { $0 == "TESTID01" || $0 == "TESTID02" }) == 2)
    }

    @Test("Get contact", arguments: [
        ("TESTID01", true),
        ("TESTID02", false),
    ])
    func get(getIdentity: String, isRequired: Bool) async throws {
        let (contactProvider, _, _, _, _, testDatabase) = try makeSUT()

        let expectedIdentity = LibthreemaThreemaID("TESTID01")

        testDatabase.preparer.save {
            testDatabase.preparer.createContact(identity: expectedIdentity)
        }

        let result = try contactProvider.get(identity: LibthreemaThreemaID(getIdentity))

        if isRequired {
            let contact = try #require(result)
            #expect(contact.identity == getIdentity)
        }
        else {
            #expect(result == nil)
        }
    }

    @Test("Get contact with profile pictures", arguments: [
        ("TESTID01", true),
        ("TESTID02", false),
    ])
    func getWithProfilePictures(getIdentity: String, isRequred: Bool) async throws {
        let (contactProvider, _, _, _, _, testDatabase) = try makeSUT()

        let expectedIdentity = LibthreemaThreemaID("TESTID01")

        testDatabase.preparer.save {
            testDatabase.preparer.createContact(identity: expectedIdentity)
        }

        let result = try contactProvider.getWithProfilePictures(identity: getIdentity)

        if isRequred {
            let contactWithProfilePictures = try #require(result)
            #expect(contactWithProfilePictures.contact.identity == getIdentity)
            #expect(contactWithProfilePictures.contactDefinedProfilePicture == nil)
            #expect(contactWithProfilePictures.userDefinedProfilePicture == nil)
        }
        else {
            #expect(result == nil)
        }
    }

    @Test("Add contact")
    func add() async throws {
        let (contactProvider, _, _, contactStoreMock, pushSettingManagerMock, testDatabase) = try makeSUT()

        let expectedIdentity1 = "TESTID01"
        let expectedPublicKey1 = BytesUtility.generatePublicKey()
        let expectedCreatedAt1 = Date()
        let expectedLastUpdateAt1 = Date()
        let expectedFirstName1 = "First name 1"
        let expectedLastName1 = "Last name 1"
        let expectedNickname1 = "Nickname 1"
        let expectedVerificationLevel1: LibthreemaVerificationLevel = .fullyVerified
        let expectedWorkVerificationLevel1: LibthreemaWorkVerificationLevel = .none
        let expectedIdentityType1: IdentityType = .regular
        let expectedAcquaintanceLevel1: LibthreemaAcquaintanceLevel = .direct
        let expectedActivityState1: LibthreemaActivityState = .active
        let expectedFeatureMask1: UInt64 = 1
        let expectedSyncState1: LibthreemaSyncState = .initial
        let expectedReadReceiptPolicyOverride1: LibthreemaReadReceiptPolicy = .dontSendReadReceipt
        let expectedTypingIndicatorPolicyOverride1: LibthreemaTypingIndicatorPolicy = .dontSendTypingIndicator
        let expectedNotificationTriggerPolicyOverride1: LibthreemaContactNotificationTriggerPolicyOverride? = nil
        let expectedConversationCategory1: LibthreemaConversationCategory = .default
        let expectedConversationVisibility1: LibthreemaConversationVisibility = .normal

        let expectedIdentity2 = "TESTID02"
        let expectedPublicKey2 = BytesUtility.generatePublicKey()
        let expectedCreatedAt2 = Date()
        let expectedLastUpdateAt2 = Date()
        let expectedFirstName2 = "First name 2"
        let expectedLastName2 = "Last name 2"
        let expectedNickname2 = "Nickname 2"
        let expectedVerificationLevel2: LibthreemaVerificationLevel = .serverVerified
        let expectedWorkVerificationLevel2: LibthreemaWorkVerificationLevel = .workSubscriptionVerified
        let expectedIdentityType2: IdentityType = .work
        let expectedAcquaintanceLevel2: LibthreemaAcquaintanceLevel = .groupOrDeleted
        let expectedActivityState2: LibthreemaActivityState = .inactive
        let expectedFeatureMask2: UInt64 = 2
        let expectedSyncState2: LibthreemaSyncState = .imported
        let expectedReadReceiptPolicyOverride2: LibthreemaReadReceiptPolicy = .sendReadReceipt
        let expectedTypingIndicatorPolicyOverride2: LibthreemaTypingIndicatorPolicy = .sendTypingIndicator
        let expectedNotificationTriggerPolicyOverride2 = LibthreemaContactNotificationTriggerPolicyOverride(
            policy: .never,
            expiresAt: Date.now.millisecondsSince1970
        )
        let expectedConversationCategory2: LibthreemaConversationCategory = .protected
        let expectedConversationVisibility2: LibthreemaConversationVisibility = .normal

        let addContacts = [
            LibthreemaContact(
                identity: LibthreemaThreemaID(expectedIdentity1),
                publicKey: PublicKey(expectedPublicKey1),
                createdAt: expectedCreatedAt1.millisecondsSince1970,
                lastUpdateAt: expectedLastUpdateAt1.millisecondsSince1970,
                firstName: expectedFirstName1,
                lastName: expectedLastName1,
                nickname: expectedNickname1,
                verificationLevel: expectedVerificationLevel1,
                workVerificationLevel: expectedWorkVerificationLevel1,
                identityType: expectedIdentityType1,
                acquaintanceLevel: expectedAcquaintanceLevel1,
                activityState: expectedActivityState1,
                featureMask: expectedFeatureMask1,
                syncState: expectedSyncState1,
                workLastFullSyncAt: nil,
                workAvailabilityStatus: nil,
                readReceiptPolicyOverride: expectedReadReceiptPolicyOverride1,
                typingIndicatorPolicyOverride: expectedTypingIndicatorPolicyOverride1,
                notificationTriggerPolicyOverride: expectedNotificationTriggerPolicyOverride1,
                conversationCategory: expectedConversationCategory1,
                conversationVisibility: expectedConversationVisibility1
            ),
            LibthreemaContact(
                identity: LibthreemaThreemaID(expectedIdentity2),
                publicKey: PublicKey(expectedPublicKey2),
                createdAt: expectedCreatedAt2.millisecondsSince1970,
                lastUpdateAt: expectedLastUpdateAt2.millisecondsSince1970,
                firstName: expectedFirstName2,
                lastName: expectedLastName2,
                nickname: expectedNickname2,
                verificationLevel: expectedVerificationLevel2,
                workVerificationLevel: expectedWorkVerificationLevel2,
                identityType: expectedIdentityType2,
                acquaintanceLevel: expectedAcquaintanceLevel2,
                activityState: expectedActivityState2,
                featureMask: expectedFeatureMask2,
                syncState: expectedSyncState2,
                workLastFullSyncAt: nil,
                workAvailabilityStatus: nil,
                readReceiptPolicyOverride: expectedReadReceiptPolicyOverride2,
                typingIndicatorPolicyOverride: expectedTypingIndicatorPolicyOverride2,
                notificationTriggerPolicyOverride: expectedNotificationTriggerPolicyOverride2,
                conversationCategory: expectedConversationCategory2,
                conversationVisibility: expectedConversationVisibility2
            ),
        ]

        // Act

        try contactProvider.add(contacts: addContacts)

        // Regular contact

        let contactEntity1 = try #require(
            testDatabase.entityManager.entityFetcher
                .contactEntity(for: expectedIdentity1)
        )
        #expect(contactEntity1.identity == expectedIdentity1)
        #expect(contactEntity1.publicKey.elementsEqual(expectedPublicKey1))
        #expect(contactEntity1.createdAt?.millisecondsSince1970 == expectedCreatedAt1.millisecondsSince1970)
        #expect(contactEntity1.firstName == expectedFirstName1)
        #expect(contactEntity1.lastName == expectedLastName1)
        #expect(contactEntity1.publicNickname == expectedNickname1)
        #expect(
            contactEntity1.contactVerificationLevel.rawValue == ContactEntity
                .VerificationLevel(expectedVerificationLevel1)?
                .rawValue
        )
        #expect(contactEntity1.isHidden == HiddenContact(expectedWorkVerificationLevel1))
        // Identity type: regular
        #expect(contactStoreMock.addAsWorkCalls.count(where: { $0 == expectedIdentity1 }) == 0)
        #expect(contactEntity1.workContact?.boolValue == WorkContact(expectedAcquaintanceLevel1))
        #expect(contactEntity1.contactState == ContactEntity.ContactState(expectedActivityState1))
        #expect(contactEntity1.featureMask.uint64Value == expectedFeatureMask1)
        #expect(contactEntity1.contactImportStatus == ContactEntity.ImportStatus(expectedSyncState1))
        #expect(contactEntity1.readReceipt == ContactEntity.ReadReceipt(expectedReadReceiptPolicyOverride1))
        #expect(contactEntity1.typingIndicator == ContactEntity.TypingIndicator(expectedTypingIndicatorPolicyOverride1))
        // Notification policy override
        #expect(
            pushSettingManagerMock.findForContactCalls
                .count(where: { $0 == ThreemaIdentity(expectedIdentity1) }) == 1
        )

        let conversationEntity1 = try #require(
            testDatabase.entityManager.entityFetcher
                .conversationEntity(for: expectedIdentity1)
        )
        #expect(conversationEntity1.lastUpdate?.millisecondsSince1970 == expectedLastUpdateAt1.millisecondsSince1970)
        #expect(conversationEntity1.conversationCategory == ConversationEntity.Category(expectedConversationCategory1))
        #expect(
            conversationEntity1.conversationVisibility == ConversationEntity
                .Visibility(expectedConversationVisibility1)
        )

        // Work contact

        let contactEntity2 = try #require(
            testDatabase.entityManager.entityFetcher
                .contactEntity(for: expectedIdentity2)
        )
        #expect(contactEntity2.identity == expectedIdentity2)
        #expect(contactEntity2.publicKey.elementsEqual(expectedPublicKey2))
        #expect(contactEntity2.createdAt?.millisecondsSince1970 == expectedCreatedAt2.millisecondsSince1970)
        #expect(contactEntity2.firstName == expectedFirstName2)
        #expect(contactEntity2.lastName == expectedLastName2)
        #expect(contactEntity2.publicNickname == expectedNickname2)
        #expect(
            contactEntity2.contactVerificationLevel.rawValue == ContactEntity
                .VerificationLevel(expectedVerificationLevel2)?
                .rawValue
        )
        #expect(contactEntity2.isHidden == HiddenContact(expectedWorkVerificationLevel2))
        // Identity type: work
        #expect(contactStoreMock.addAsWorkCalls.count(where: { $0 == expectedIdentity2 }) == 1)
        #expect(contactEntity2.workContact?.boolValue == WorkContact(expectedAcquaintanceLevel2))
        #expect(contactEntity2.contactState == ContactEntity.ContactState(expectedActivityState2))
        #expect(contactEntity2.featureMask.uint64Value == expectedFeatureMask2)
        #expect(contactEntity2.contactImportStatus == ContactEntity.ImportStatus(expectedSyncState2))
        #expect(contactEntity2.readReceipt == ContactEntity.ReadReceipt(expectedReadReceiptPolicyOverride2))
        #expect(contactEntity2.typingIndicator == ContactEntity.TypingIndicator(expectedTypingIndicatorPolicyOverride2))
        // Notification policy override
        #expect(
            pushSettingManagerMock.findForContactCalls
                .count(where: { $0 == ThreemaIdentity(expectedIdentity2) }) == 1
        )

        let conversationEntity2 = try #require(
            testDatabase.entityManager.entityFetcher
                .conversationEntity(for: expectedIdentity2)
        )
        #expect(conversationEntity2.lastUpdate?.millisecondsSince1970 == expectedLastUpdateAt2.millisecondsSince1970)
        #expect(conversationEntity2.conversationCategory == ConversationEntity.Category(expectedConversationCategory2))
        #expect(
            conversationEntity2.conversationVisibility == ConversationEntity
                .Visibility(expectedConversationVisibility2)
        )
    }

    @Test func `add with profile pictures with valid contact defined profile picture`() async throws {
        let (contactProvider, _, _, _, _, testDatabase) = try makeSUT()

        let expectedIdentity = "ECHOECHO"

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let validImageData = renderer.jpegData(withCompressionQuality: 1.0) { _ in }
        let validImageSize = try #require(UIImage(data: validImageData)).size
        let profilePicture = ProfilePicture(mediaType: .jpeg, data: validImageData)

        let libthreemaContact = ContactWithProfilePictures(
            contact: getLibthreemaContact(identity: LibthreemaThreemaID(expectedIdentity)),
            contactDefinedProfilePicture: profilePicture,
            userDefinedProfilePicture: nil
        )

        try contactProvider.addWithProfilePictures(contacts: [libthreemaContact])

        let contactImage = try #require(
            testDatabase.entityManager.entityFetcher.contactEntity(for: expectedIdentity)?.contactImage
        )
        #expect(contactImage.data.elementsEqual(validImageData))
        #expect(contactImage.height == Int16(validImageSize.height))
        #expect(contactImage.width == Int16(validImageSize.width))
    }

    @Test func `add with profile pictures with ivalid contact defined profile picture`() async throws {
        let (contactProvider, _, _, _, _, testDatabase) = try makeSUT()

        let expectedIdentity = "ECHOECHO"

        let invalidImageData = Data([0x00, 0x01, 0x02, 0x03])
        let profilePicture = ProfilePicture(mediaType: .jpeg, data: invalidImageData)

        let libthreemaContact = ContactWithProfilePictures(
            contact: getLibthreemaContact(identity: LibthreemaThreemaID(expectedIdentity)),
            contactDefinedProfilePicture: profilePicture,
            userDefinedProfilePicture: nil
        )

        #expect(throws: ContactProviderError.loadUIImageFailed) {
            try contactProvider.addWithProfilePictures(contacts: [libthreemaContact])
        }

        #expect(testDatabase.entityManager.entityFetcher.contactEntity(for: expectedIdentity) == nil)
    }

    @Test("Add contact user's Threema ID")
    func addMySelf() async throws {
        let (contactProvider, myIdentityStoreMock, _, _, _, testDatabase) = try makeSUT()

        let expectedIdentity = myIdentityStoreMock.identity!

        let contact = getLibthreemaContact(identity: LibthreemaThreemaID(expectedIdentity))

        // Act

        let expectedErrorMessage = "Identities must not contain the user's own identity."
        #expect(throws: ProviderError.InvalidParameter(expectedErrorMessage)) {
            try contactProvider.add(contacts: [contact])
        }

        #expect(testDatabase.entityManager.entityFetcher.contactEntities()?.isEmpty ?? true)
    }

    @Test("Add contact that already exists")
    func addAlreadyExists() async throws {
        let (contactProvider, _, _, _, _, testDatabase) = try makeSUT()

        let expectedIdentity = ThreemaIdentity("TESTID01")

        let contact = getLibthreemaContact(identity: LibthreemaThreemaID(threemaIdentity: expectedIdentity))

        testDatabase.preparer.save {
            testDatabase.preparer.createContact(
                identity: expectedIdentity.rawValue
            )
        }

        // Act

        let expectedErrorMessage = "Some contacts are already existing"
        #expect(throws: ProviderError.InvalidState(expectedErrorMessage)) {
            try contactProvider.add(contacts: [contact])
        }

        #expect(testDatabase.entityManager.entityFetcher.contactEntities()?.count ?? 0 > 0)
    }

    @Test("Update contact")
    func update() async throws {
        let (contactProvider, _, _, contactStoreMock, pushSettingManagerMock, testDatabase) = try makeSUT()

        let expectedIdentity = "TESTID01"
        let expectedPublicKey = BytesUtility.generatePublicKey()
        let expectedCreatedAt = Date()

        let updatedFirstName = "First name inserted"
        let updatedLastName = "Last name inserted"
        let updatedNickname = "Nickname inserted"
        let updatedVerificationLevel: LibthreemaVerificationLevel = .fullyVerified
        let updatedWorkVerificationLevel: LibthreemaWorkVerificationLevel = .none
        let updatedIdentityType: IdentityType = .regular
        let updatedAcquaintanceLevel: LibthreemaAcquaintanceLevel = .direct
        let updatedActivityState: LibthreemaActivityState = .active
        let updatedFeatureMask: UInt64 = 1
        let updatedSyncState: LibthreemaSyncState = .initial
        let updatedReadReceiptPolicyOverride: LibthreemaReadReceiptPolicy = .dontSendReadReceipt
        let updatedTypingIndicatorPolicyOverride: LibthreemaTypingIndicatorPolicy = .dontSendTypingIndicator
        let updatedNotificationTriggerPolicyOverride = LibthreemaContactNotificationTriggerPolicyOverride(
            policy: .never,
            expiresAt: nil
        )
        let updatedConversationCategory: LibthreemaConversationCategory = .protected
        let updatedConversationVisibility: LibthreemaConversationVisibility = .normal

        let updateContact = LibthreemaContactUpdate(
            identity: LibthreemaThreemaID(expectedIdentity),
            firstName: updatedFirstName,
            lastName: updatedLastName,
            nickname: updatedNickname,
            verificationLevel: updatedVerificationLevel,
            workVerificationLevel: updatedWorkVerificationLevel,
            identityType: updatedIdentityType,
            acquaintanceLevel: updatedAcquaintanceLevel,
            activityState: updatedActivityState,
            featureMask: updatedFeatureMask,
            syncState: updatedSyncState,
            readReceiptPolicyOverride: .update(updatedReadReceiptPolicyOverride),
            typingIndicatorPolicyOverride: .update(updatedTypingIndicatorPolicyOverride),
            notificationTriggerPolicyOverride: .update(updatedNotificationTriggerPolicyOverride),
            conversationCategory: updatedConversationCategory,
            conversationVisibility: updatedConversationVisibility
        )

        testDatabase.preparer.save {
            testDatabase.preparer.createContact(
                publicKey: expectedPublicKey,
                identity: expectedIdentity,
                createdAt: expectedCreatedAt
            )
        }

        // Act

        try contactProvider.update(updates: [updateContact])

        let contactEntity = try #require(
            testDatabase.entityManager.entityFetcher
                .contactEntity(for: expectedIdentity)
        )
        #expect(contactEntity.identity == expectedIdentity)
        #expect(contactEntity.publicKey.elementsEqual(expectedPublicKey))
        #expect(contactEntity.createdAt?.millisecondsSince1970 == expectedCreatedAt.millisecondsSince1970)

        #expect(contactEntity.firstName == updatedFirstName)
        #expect(contactEntity.lastName == updatedLastName)
        #expect(contactEntity.publicNickname == (updatedNickname.isEmpty ? nil : updatedNickname))
        #expect(contactEntity.publicNickname == updatedNickname)
        #expect(
            contactEntity.contactVerificationLevel.rawValue == ContactEntity
                .VerificationLevel(updatedVerificationLevel)?
                .rawValue
        )
        #expect(contactEntity.isHidden == HiddenContact(updatedWorkVerificationLevel))
        // Identity type: regular
        #expect(contactStoreMock.addAsWorkCalls.count(where: { $0 == expectedIdentity }) == 0)
        #expect(contactEntity.workContact?.boolValue == WorkContact(updatedAcquaintanceLevel))
        #expect(contactEntity.contactState == ContactEntity.ContactState(updatedActivityState))
        #expect(contactEntity.featureMask.uint64Value == updatedFeatureMask)
        #expect(contactEntity.contactImportStatus == ContactEntity.ImportStatus(updatedSyncState))
        #expect(contactEntity.readReceipt == ContactEntity.ReadReceipt(updatedReadReceiptPolicyOverride))
        #expect(contactEntity.typingIndicator == ContactEntity.TypingIndicator(updatedTypingIndicatorPolicyOverride))
        // Notification policy override
        #expect(
            pushSettingManagerMock.findForContactCalls
                .count(where: { $0 == ThreemaIdentity(expectedIdentity) }) == 1
        )

        let conversationEntity = try #require(
            testDatabase.entityManager.entityFetcher
                .conversationEntity(for: expectedIdentity)
        )
        #expect(conversationEntity.conversationCategory == ConversationEntity.Category(updatedConversationCategory))
        #expect(
            conversationEntity.conversationVisibility == ConversationEntity
                .Visibility(updatedConversationVisibility)
        )
    }

    @Test("Update contact my self")
    func updateMySelf() async throws {
        let (contactProvider, myIdentityStoreMock, _, _, _, testDatabase) = try makeSUT()

        let expectedIdentity = myIdentityStoreMock.identity!

        let updateContact = getLibthreemaContactUpdate(identity: LibthreemaThreemaID(expectedIdentity))

        // Act

        let expectedErrorMessage = "Identities must not contain the user\'s own identity."
        #expect(throws: ProviderError.InvalidParameter(expectedErrorMessage)) {
            try contactProvider.update(updates: [updateContact])
        }

        #expect(testDatabase.entityManager.entityFetcher.contactEntities()?.isEmpty ?? true)
    }

    @Test("Update contact not found")
    func updateContactNotFound() async throws {
        let (contactProvider, _, _, _, _, testDatabase) = try makeSUT()

        let expectedIdentity = ThreemaIdentity("TESTID01")

        let updateContact = getLibthreemaContactUpdate(identity: LibthreemaThreemaID(threemaIdentity: expectedIdentity))

        // Act

        let expectedErrorMessage = "Contact TESTID01 not exists"
        #expect(throws: ProviderError.InvalidState(expectedErrorMessage)) {
            try contactProvider.update(updates: [updateContact])
        }

        #expect(testDatabase.entityManager.entityFetcher.contactEntities()?.isEmpty ?? true)
    }

    // MARK: setContactDefinedProfilePicture

    @Test func `set contact defined profile picture throws invalid parameter when identity equals user identity`() throws {
        let myIdentityStore = MyIdentityStoreMock()
        myIdentityStore.identity = "AAAAAAAA"

        let (contactProvider, _, _, _, _, _) = try makeSUT(myIdentityStoreMock: myIdentityStore)

        #expect(throws: ProviderError.InvalidParameter("Identity must not be the user's own identity.")) {
            try contactProvider.setContactDefinedProfilePicture(identity: "AAAAAAAA", profilePicture: nil)
        }
    }

    @Test func `set contact defined profile picture throws invalid state when contact not found`() throws {
        let (contactProvider, _, _, _, _, _) = try makeSUT()

        #expect(throws: ProviderError.InvalidState("Contact not found for identity")) {
            try contactProvider.setContactDefinedProfilePicture(identity: "TESTID01", profilePicture: nil)
        }
    }

    @Test func `set contact defined profile picture sets contact image when profile picture is valid`() throws {
        let (contactProvider, _, _, _, _, testDatabase) = try makeSUT()

        let identity = "TESTID01"
        testDatabase.preparer.save {
            testDatabase.preparer.createContact(identity: identity)
        }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let validImageData = renderer.jpegData(withCompressionQuality: 1.0) { _ in }
        let profilePicture = ProfilePicture(mediaType: .jpeg, data: validImageData)

        try contactProvider.setContactDefinedProfilePicture(identity: identity, profilePicture: profilePicture)

        let contactEntity = try #require(testDatabase.entityManager.entityFetcher.contactEntity(for: identity))
        let contactImage = try #require(contactEntity.contactImage)
        #expect(contactImage.data == validImageData)
    }

    @Test func `set contact defined profile picture throws contact provider error when data is invalid`() throws {
        let (contactProvider, _, _, _, _, testDatabase) = try makeSUT()

        let identity = "TESTID01"
        testDatabase.preparer.save {
            testDatabase.preparer.createContact(identity: identity)
        }

        let invalidImageData = Data([0x00, 0x01, 0x02, 0x03])
        let profilePicture = ProfilePicture(mediaType: .jpeg, data: invalidImageData)

        #expect(throws: ContactProviderError.loadUIImageFailed) {
            try contactProvider.setContactDefinedProfilePicture(identity: identity, profilePicture: profilePicture)
        }
    }

    @Test func `set contact defined profile picture removes contact image when profile picture is nil`() throws {
        let (contactProvider, _, _, _, _, testDatabase) = try makeSUT()

        let identity = "TESTID01"
        testDatabase.preparer.save {
            let contact = testDatabase.preparer.createContact(identity: identity)
            contact.contactImage = testDatabase.preparer.createImageDataEntity(
                data: Data([0xFF, 0xD8, 0xFF]),
                height: 1,
                width: 1
            )
        }

        try contactProvider.setContactDefinedProfilePicture(identity: identity, profilePicture: nil)

        let contactEntity = try #require(testDatabase.entityManager.entityFetcher.contactEntity(for: identity))
        #expect(contactEntity.contactImage == nil)
    }

    @Test func `set contact defined profile picture does nothing when profile picture is nil and no contact image exists`(
    ) throws {
        let (contactProvider, _, _, _, _, testDatabase) = try makeSUT()

        let identity = "TESTID01"
        testDatabase.preparer.save {
            testDatabase.preparer.createContact(identity: identity)
        }

        try contactProvider.setContactDefinedProfilePicture(identity: identity, profilePicture: nil)

        let contactEntity = try #require(testDatabase.entityManager.entityFetcher.contactEntity(for: identity))
        #expect(contactEntity.contactImage == nil)
    }

    // MARK: setUserDefinedProfilePicture

    @Test func `set user defined profile picture throws invalid parameter when identity equals user identity`() throws {
        let myIdentityStore = MyIdentityStoreMock()
        myIdentityStore.identity = "AAAAAAAA"

        let (contactProvider, _, _, _, _, _) = try makeSUT(myIdentityStoreMock: myIdentityStore)

        #expect(throws: ProviderError.InvalidParameter("Identity must not be the user's own identity.")) {
            try contactProvider.setUserDefinedProfilePicture(identity: "AAAAAAAA", profilePicture: nil)
        }
    }

    @Test func `set user defined profile picture throws invalid state when contact not found`() throws {
        let (contactProvider, _, _, _, _, _) = try makeSUT()

        #expect(throws: ProviderError.InvalidState("Contact not found for identity")) {
            try contactProvider.setUserDefinedProfilePicture(identity: "TESTID01", profilePicture: nil)
        }
    }

    @Test func `set user defined profile picture sets contact image when profile picture is valid`() throws {
        let (contactProvider, _, _, _, _, testDatabase) = try makeSUT()

        let identity = "TESTID01"
        testDatabase.preparer.save {
            testDatabase.preparer.createContact(identity: identity)
        }

        let validImageData = Data([0xFF, 0xD8, 0xFF])
        let profilePicture = ProfilePicture(mediaType: .jpeg, data: validImageData)

        try contactProvider.setUserDefinedProfilePicture(identity: identity, profilePicture: profilePicture)

        let contactEntity = try #require(testDatabase.entityManager.entityFetcher.contactEntity(for: identity))
        let imageData = try #require(contactEntity.imageData)
        #expect(imageData == validImageData)
    }

    @Test func `set user defined profile picture removes contact image when profile picture is nil`() throws {
        let (contactProvider, _, _, _, _, testDatabase) = try makeSUT()

        let identity = "TESTID01"
        testDatabase.preparer.save {
            let contact = testDatabase.preparer.createContact(identity: identity)
            contact.imageData = Data([0xFF, 0xD8, 0xFF])
        }

        try contactProvider.setUserDefinedProfilePicture(identity: identity, profilePicture: nil)

        let contactEntity = try #require(testDatabase.entityManager.entityFetcher.contactEntity(for: identity))
        #expect(contactEntity.contactImage == nil)
    }

    @Test func `set user defined profile picture does nothing when profile picture is nil and no contact image exists`() throws {
        let (contactProvider, _, _, _, _, testDatabase) = try makeSUT()

        let identity = "TESTID01"
        testDatabase.preparer.save {
            testDatabase.preparer.createContact(identity: identity)
        }

        try contactProvider.setUserDefinedProfilePicture(identity: identity, profilePicture: nil)

        let contactEntity = try #require(testDatabase.entityManager.entityFetcher.contactEntity(for: identity))
        #expect(contactEntity.imageData == nil)
    }

    // MARK: Private functions

    private func getLibthreemaContact(
        identity: LibthreemaThreemaID,
        publicKey: PublicKey = PublicKey(BytesUtility.generatePublicKey()),
        createdAt: Date = .now,
        lastUpdateAt: Date? = nil,
        firstName: String = String.empty,
        lastName: String = String.empty,
        nickname: String = String.empty,
        verificationLevel: LibthreemaVerificationLevel = .unverified,
        workVerificationLevel: LibthreemaWorkVerificationLevel = .none,
        identityType: IdentityType = .regular,
        acquaintanceLevel: LibthreemaAcquaintanceLevel = .direct,
        activityState: LibthreemaActivityState = .inactive,
        featureMask: UInt64 = 1,
        syncState: LibthreemaSyncState = .imported,
        readReceiptPolicyOverride: LibthreemaReadReceiptPolicy? = nil,
        typingIndicatorPolicyOverride: LibthreemaTypingIndicatorPolicy? = nil,
        notificationTriggerPolicyOverride: ContactNotificationTriggerPolicyOverride? = nil,
        conversationCategory: LibthreemaConversationCategory = .default,
        conversationVisibility: LibthreemaConversationVisibility = .archived
    ) -> LibthreemaContact {
        LibthreemaContact(
            identity: identity,
            publicKey: publicKey,
            createdAt: createdAt.millisecondsSince1970,
            lastUpdateAt: lastUpdateAt?.millisecondsSince1970,
            firstName: firstName,
            lastName: lastName,
            nickname: nickname,
            verificationLevel: verificationLevel,
            workVerificationLevel: workVerificationLevel,
            identityType: identityType,
            acquaintanceLevel: acquaintanceLevel,
            activityState: activityState,
            featureMask: featureMask,
            syncState: syncState,
            workLastFullSyncAt: nil,
            workAvailabilityStatus: nil,
            readReceiptPolicyOverride: readReceiptPolicyOverride,
            typingIndicatorPolicyOverride: typingIndicatorPolicyOverride,
            notificationTriggerPolicyOverride: notificationTriggerPolicyOverride,
            conversationCategory: conversationCategory,
            conversationVisibility: conversationVisibility
        )
    }

    private func getLibthreemaContactUpdate(identity: LibthreemaThreemaID) -> LibthreemaContactUpdate {
        LibthreemaContactUpdate(
            identity: identity,
            firstName: nil,
            lastName: nil,
            nickname: nil,
            verificationLevel: .unverified,
            workVerificationLevel: nil,
            identityType: .regular,
            acquaintanceLevel: .direct,
            activityState: .active,
            featureMask: 1,
            syncState: .initial,
            readReceiptPolicyOverride: .unchanged,
            typingIndicatorPolicyOverride: .unchanged,
            notificationTriggerPolicyOverride: .unchanged,
            conversationCategory: .default,
            conversationVisibility: .normal
        )
    }

    private func makeSUT(
        myIdentityStoreMock: any MyIdentityStoreProtocol = MyIdentityStoreMock(),
        userSettingsMock: any UserSettingsProtocol = UserSettingsMock()
    ) throws -> (
        contactProvider: ThreemaFramework.ContactProvider,
        myIdentityStoreMock: any MyIdentityStoreProtocol,
        userSettingsMock: any UserSettingsProtocol,
        contactStoreMock: ContactStoreMock,
        pushSettingManager: PushSettingManagerMock,
        testDatabase: TestDatabase
    ) {
        let testDatabase = TestDatabase()
        let contactStoreMock = ContactStoreMock()
        let pushSettingManagerMock = PushSettingManagerMock()

        return try (
            ContactProvider(
                userIdentity: ThreemaIdentity(identity: myIdentityStoreMock.identity),
                userSettings: userSettingsMock,
                contactStore: contactStoreMock,
                pushSettingManager: pushSettingManagerMock,
                entityManager: testDatabase.backgroundEntityManager
            ),
            myIdentityStoreMock,
            userSettingsMock,
            contactStoreMock,
            pushSettingManagerMock,
            testDatabase
        )
    }
}
