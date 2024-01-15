//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2024 Threema GmbH
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
import XCTest
@testable import ThreemaFramework

class MediatorSyncableContactsTests: XCTestCase {
    private let testBundle = Bundle(for: MediatorSyncableContactsTests.self)

    private var databasePreparer: DatabasePreparer!
    private var databaseBackgroundCnx: DatabaseContext!

    private var blobDict = [Data: Data]()
    
    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        let (_, mainCnx, backgroundCnx) = DatabasePersistentContext.devNullContext()
        databasePreparer = DatabasePreparer(context: mainCnx)
        databaseBackgroundCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)
    }

    func testUpdateAllSyncChunkCount() {
        let taskManagerMock = TaskManagerMock()

        let mediatorSyncableContacts = MediatorSyncableContacts(
            UserSettingsMock(enableMultiDevice: true),
            PushSettingManagerMock(),
            taskManagerMock,
            EntityManager(databaseContext: databaseBackgroundCnx, myIdentityStore: MyIdentityStoreMock())
        )

        let noContacts = 500
        for _ in 0..<noContacts {
            let contact = getMinimalContact()

            mediatorSyncableContacts.updateAll(identity: contact.identity, added: false, withoutProfileImage: true)
        }

        let expec = expectation(description: "Sync")

        mediatorSyncableContacts.sync()
            .done {
                expec.fulfill()
            }
            .catch { error in
                XCTFail(error.localizedDescription)
            }

        wait(for: [expec], timeout: 6)

        XCTAssertEqual(taskManagerMock.addedTasks.count, 5)
    }
    
    func testUpdateAllSync() {
        for contactCount in [1, 2, 5, 50, 100, 1000] {
            let taskManagerMock = TaskManagerMock()
            
            let mediatorSyncableContacts = MediatorSyncableContacts(
                UserSettingsMock(enableMultiDevice: true),
                PushSettingManagerMock(),
                taskManagerMock,
                EntityManager(databaseContext: databaseBackgroundCnx)
            )
            for _ in 0..<contactCount {
                let contact = getMinimalContact()
                mediatorSyncableContacts.updateAll(identity: contact.identity, added: false, withoutProfileImage: true)
            }

            let expec = XCTestExpectation(description: "Sync completes successfully")
            
            mediatorSyncableContacts.sync()
                .done {
                    let expectedTaskCount: Int = contactCount < mediatorSyncableContacts
                        .getChunkSize() ? 1 : contactCount / mediatorSyncableContacts.getChunkSize()
                    let taskCount = taskManagerMock.addedTasks.count

                    XCTAssertEqual(expectedTaskCount, taskCount)

                    for task in taskManagerMock.addedTasks {
                        if !(task is TaskDefinitionUpdateContactSync) {
                            XCTFail("Created an unexpected task")
                        }
                    }
                    expec.fulfill()
                }
                .catch { error in
                    XCTFail("Sync failed: \(error)")
                }
            
            wait(for: [expec], timeout: 6)
        }
    }
    
    func testDeleteContact() {
        let taskManagerMock = TaskManagerMock()
        
        let mediatorSyncableContacts = MediatorSyncableContacts(
            UserSettingsMock(enableMultiDevice: true),
            PushSettingManagerMock(),
            taskManagerMock,
            EntityManager(databaseContext: databaseBackgroundCnx)
        )
        let contact = getMinimalContact()

        let expec = XCTestExpectation(description: "Sync completes successfully")
        
        mediatorSyncableContacts.deleteAndSync(identity: contact.identity)
            .done {
                let taskCount = taskManagerMock.addedTasks.count
                XCTAssertEqual(1, taskCount)

                for task in taskManagerMock.addedTasks {
                    if !(task is TaskDefinitionDeleteContactSync) {
                        XCTFail("Created an unexpected task")
                    }
                }
                expec.fulfill()
            }
            .catch { error in
                XCTFail("Delete and sync failed: \(error)")
            }
        
        wait(for: [expec], timeout: 6)
    }

    func testIntegrationWithTaskExecution() {
        let userSettingsMock = UserSettingsMock(enableMultiDevice: true)

        struct TestInput {
            var contact: ContactEntity
        }
        struct TestOutput {
            var delta: DeltaSyncContact
        }
        
        var table = [(name: String, input: TestInput, output: TestOutput)]()
        
        // Test 1: Basic Test
        let testContact1 = getBaseContact(setProfilePicture: true, setContactProfilePicture: true, isWorkContact: false)
        let test1 = (
            "Basic Test",
            TestInput(contact: testContact1),
            TestOutput(delta: expectedDeltaSyncContact(from: testContact1, userSettings: userSettingsMock))
        )
        table.append(test1)
        
        // Test 2: No Profile Picture Test
        let testContact2 = getBaseContact(
            setProfilePicture: false,
            setContactProfilePicture: false,
            isWorkContact: false
        )
        let test2 = (
            "No Profile Picture Test",
            TestInput(contact: testContact2),
            TestOutput(delta: expectedDeltaSyncContact(from: testContact2, userSettings: userSettingsMock))
        )
        table.append(test2)

        // Test 3: Only User Profile Picture Test
        let testContact3 = getBaseContact(setProfilePicture: true, setContactProfilePicture: false, isWorkContact: true)
        let test3 = (
            "Only User Profile Picture Test",
            TestInput(contact: testContact3),
            TestOutput(delta: expectedDeltaSyncContact(from: testContact3, userSettings: userSettingsMock))
        )
        table.append(test3)

        // Test 4: Only Contact Profile Picture Test
        let testContact4 = getBaseContact(setProfilePicture: false, setContactProfilePicture: true, isWorkContact: true)
        let test4 = (
            "Only Contact Profile Picture Test",
            TestInput(contact: testContact4),
            TestOutput(delta: expectedDeltaSyncContact(from: testContact4, userSettings: userSettingsMock))
        )
        table.append(test4)
        
        for test in table {
            let taskManagerMock = TaskManagerMock()
            let mediatorSyncableContacts = MediatorSyncableContacts(
                userSettingsMock,
                PushSettingManagerMock(),
                taskManagerMock,
                EntityManager(databaseContext: databaseBackgroundCnx)
            )
            
            let expec =
                XCTestExpectation(description: "Completion is executed immediately if multi device is not enabled")
            
            mediatorSyncableContacts.updateAll(
                identity: test.input.contact.identity,
                added: false,
                withoutProfileImage: false
            )

            mediatorSyncableContacts.sync()
                .done {
                    XCTAssertEqual(taskManagerMock.addedTasks.count, 1, "\(test.name)")

                    for i in 0..<taskManagerMock.addedTasks.count {
                        guard let contactUpdateTask = taskManagerMock.addedTasks[i] as? TaskDefinitionUpdateContactSync
                        else {
                            XCTFail("Wrong task type")
                            expec.fulfill()
                            return
                        }

                        for delta in contactUpdateTask.deltaSyncContacts {

                            XCTAssertTrue(delta.syncContact.hasAcquaintanceLevel, "\(test.name)")
                            XCTAssertTrue(delta.syncContact.hasActivityState, "\(test.name)")
                            XCTAssertFalse(delta.syncContact.hasContactDefinedProfilePicture, "\(test.name)")
                            XCTAssertTrue(delta.syncContact.hasConversationCategory, "\(test.name)")
                            XCTAssertTrue(delta.syncContact.hasConversationVisibility, "\(test.name)")
                            XCTAssertTrue(delta.syncContact.hasCreatedAt, "\(test.name)")
                            XCTAssertTrue(delta.syncContact.hasFeatureMask, "\(test.name)")
                            XCTAssertTrue(delta.syncContact.hasFirstName, "\(test.name)")
                            XCTAssertTrue(delta.syncContact.hasIdentityType, "\(test.name)")
                            XCTAssertTrue(delta.syncContact.hasLastName, "\(test.name)")
                            XCTAssertTrue(delta.syncContact.hasNickname, "\(test.name)")
                            XCTAssertTrue(delta.syncContact.hasNotificationSoundPolicyOverride, "\(test.name)")
                            XCTAssertTrue(delta.syncContact.hasNotificationTriggerPolicyOverride, "\(test.name)")
                            XCTAssertTrue(delta.syncContact.hasPublicKey, "\(test.name)")
                            XCTAssertFalse(delta.syncContact.hasUserDefinedProfilePicture, "\(test.name)")
                            XCTAssertTrue(delta.syncContact.hasReadReceiptPolicyOverride, "\(test.name)")
                            XCTAssertTrue(delta.syncContact.hasSyncState, "\(test.name)")
                            XCTAssertTrue(delta.syncContact.hasTypingIndicatorPolicyOverride, "\(test.name)")
                            XCTAssertTrue(delta.syncContact.hasVerificationLevel, "\(test.name)")
                            XCTAssertTrue(delta.syncContact.hasWorkVerificationLevel, "\(test.name)")

                            XCTAssertEqual(
                                delta.syncContact.acquaintanceLevel,
                                test.output.delta.syncContact.acquaintanceLevel,
                                "\(test.name)"
                            )
                            XCTAssertEqual(
                                delta.syncContact.activityState,
                                test.output.delta.syncContact.activityState,
                                "\(test.name)"
                            )
                            XCTAssertEqual(
                                delta.contactProfilePicture,
                                test.output.delta.contactProfilePicture,
                                "\(test.name)"
                            )
                            XCTAssertEqual(
                                delta.syncContact.conversationCategory,
                                test.output.delta.syncContact.conversationCategory,
                                "\(test.name)"
                            )
                            XCTAssertEqual(
                                delta.syncContact.conversationVisibility,
                                test.output.delta.syncContact.conversationVisibility,
                                "\(test.name)"
                            )
                            XCTAssertEqual(
                                delta.syncContact.createdAt,
                                test.output.delta.syncContact.createdAt,
                                "\(test.name)"
                            )
                            XCTAssertEqual(delta.syncContact.featureMask, test.output.delta.syncContact.featureMask)
                            XCTAssertEqual(
                                delta.syncContact.firstName,
                                test.output.delta.syncContact.firstName,
                                "\(test.name)"
                            )
                            XCTAssertEqual(
                                delta.syncContact.identity,
                                test.output.delta.syncContact.identity,
                                "\(test.name)"
                            )
                            XCTAssertEqual(
                                delta.syncContact.identityType,
                                test.output.delta.syncContact.identityType,
                                "\(test.name)"
                            )
                            XCTAssertEqual(
                                delta.syncContact.lastName,
                                test.output.delta.syncContact.lastName,
                                "\(test.name)"
                            )
                            XCTAssertEqual(
                                delta.syncContact.nickname,
                                test.output.delta.syncContact.nickname,
                                "\(test.name)"
                            )
                            XCTAssertEqual(
                                delta.syncContact.notificationSoundPolicyOverride,
                                test.output.delta.syncContact.notificationSoundPolicyOverride
                            )
                            XCTAssertEqual(
                                delta.syncContact.notificationTriggerPolicyOverride,
                                test.output.delta.syncContact.notificationTriggerPolicyOverride
                            )
                            XCTAssertEqual(
                                delta.syncContact.publicKey,
                                test.output.delta.syncContact.publicKey,
                                "\(test.name)"
                            )
                            XCTAssertEqual(delta.profilePicture, test.output.delta.profilePicture, "\(test.name)")
                            XCTAssertEqual(
                                delta.syncContact.syncState,
                                test.output.delta.syncContact.syncState,
                                "\(test.name)"
                            )
                            XCTAssertEqual(
                                delta.syncContact.typingIndicatorPolicyOverride,
                                test.output.delta.syncContact.typingIndicatorPolicyOverride,
                                "\(test.name)"
                            )
                            XCTAssertEqual(
                                delta.syncContact.verificationLevel,
                                test.output.delta.syncContact.verificationLevel,
                                "\(test.name)"
                            )
                        }
                        expec.fulfill()
                    }
                }
                .catch { error in
                    XCTFail("Sync failed: \(error)")
                }

            wait(for: [expec], timeout: 6)
            
            // Clean tasks for next test
            taskManagerMock.addedTasks.removeAll()
        }
    }
    
    func testReadReceiptPolicyOverrideDefault() throws {
        let contactEntity = getMinimalContact()
        contactEntity.readReceipt = .default
        
        let mediatorSyncableContacts = MediatorSyncableContacts(
            UserSettingsMock(),
            PushSettingManagerMock(),
            TaskManagerMock(),
            EntityManager(databaseContext: databaseBackgroundCnx)
        )
        
        let allSyncableContacts = mediatorSyncableContacts.getAllDeltaSyncContacts()
        let deltaSyncContact = try XCTUnwrap(
            allSyncableContacts
                .first(where: { $0.syncContact.identity == contactEntity.identity })
        )
        
        XCTAssertTrue(deltaSyncContact.syncContact.hasReadReceiptPolicyOverride)
        XCTAssertEqual(deltaSyncContact.syncContact.readReceiptPolicyOverride.override, .default(Common_Unit()))
    }
    
    func testReadReceiptPolicyOverrideOverrideDoNotSend() throws {
        let contactEntity = getMinimalContact()
        contactEntity.readReceipt = .doNotSend
        
        let mediatorSyncableContacts = MediatorSyncableContacts(
            UserSettingsMock(),
            PushSettingManagerMock(),
            TaskManagerMock(),
            EntityManager(databaseContext: databaseBackgroundCnx)
        )
        
        let allSyncableContacts = mediatorSyncableContacts.getAllDeltaSyncContacts()
        let deltaSyncContact = try XCTUnwrap(
            allSyncableContacts
                .first(where: { $0.syncContact.identity == contactEntity.identity })
        )

        XCTAssertTrue(deltaSyncContact.syncContact.hasReadReceiptPolicyOverride)
        XCTAssertEqual(
            deltaSyncContact.syncContact.readReceiptPolicyOverride.override,
            .policy(.dontSendReadReceipt)
        )
    }
    
    func testReadReceiptPolicyOverrideSend() throws {
        let contactEntity = getMinimalContact()
        contactEntity.readReceipt = .send
        
        let mediatorSyncableContacts = MediatorSyncableContacts(
            UserSettingsMock(),
            PushSettingManagerMock(),
            TaskManagerMock(),
            EntityManager()
        )
        
        let allSyncableContacts = mediatorSyncableContacts.getAllDeltaSyncContacts()
        let deltaSyncContact = try XCTUnwrap(
            allSyncableContacts
                .first(where: { $0.syncContact.identity == contactEntity.identity })
        )
        
        XCTAssertTrue(deltaSyncContact.syncContact.hasReadReceiptPolicyOverride)
        XCTAssertEqual(
            deltaSyncContact.syncContact.readReceiptPolicyOverride.override,
            .policy(.sendReadReceipt)
        )
    }

    // MARK: - Helper
    
    // Expected result of `MediatorSyncableContacts.updateAll(...)` implementation -> makes this sense for testing???
    private func expectedDeltaSyncContact(
        from contact: ContactEntity,
        userSettings: UserSettingsProtocol
    ) -> DeltaSyncContact {
        var delta = DeltaSyncContact(syncContact: Sync_Contact(), syncAction: .update)

        delta.syncContact.update(contact: contact, pushSetting: PushSetting(identity: contact.threemaIdentity))

        let workIdentities = userSettings.workIdentities ?? NSOrderedSet(array: [String]())
        delta.syncContact.update(identityType: workIdentities.contains(contact.identity) ? .work : .regular)

        delta.profilePicture = contact.imageData != nil ? .updated : .removed
        delta.contactProfilePicture = contact.contactImage?.data != nil ? .updated : .removed
        delta.image = contact.imageData
        delta.contactImage = contact.contactImage?.data

        if let conversation = contact.conversations!.first as? Conversation {
            delta.syncContact.update(conversation: conversation)
        }

        return delta
    }
    
    private func getBaseContact(
        setProfilePicture: Bool,
        setContactProfilePicture: Bool,
        isWorkContact: Bool
    ) -> ContactEntity {
        let contact: ContactEntity = getMinimalContact()
        databasePreparer.save {
            let imageURL = testBundle.url(forResource: "Bild-1-0", withExtension: "jpg")
            let imageData = (try? Data(contentsOf: imageURL!))!
            let image = UIImage(data: imageData)!
            let contactImage: ImageData = databasePreparer.createImageData(
                data: imageData,
                height: Int(image.size.height),
                width: Int(image.size.width)
            )

            contact.createdAt = Date()
            contact.isContactHidden = false
            // Optional
            contact.importedStatus = .initial
            // Optional
            databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: { conversation in
                    _ = contact.conversations!.insert(conversation)
                    conversation.conversationVisibility = .default
                    conversation.conversationCategory = .default
                }
            )
            contact.publicNickname = "Nickname"
            contact.firstName = "John"
            contact.lastName = "Appleseed"
            contact.imageData = setProfilePicture ? imageData : nil
            contact.contactImage = setContactProfilePicture ? contactImage : nil
            contact.readReceipt = .send
            contact.typingIndicator = .default
            contact.workContact = NSNumber(booleanLiteral: isWorkContact)
        }
        return contact
    }
    
    private func getMinimalContact() -> ContactEntity {
        var contact: ContactEntity!
        databasePreparer.save {
            let publicKey = MockData.generatePublicKey()
            let identity = SwiftUtils.pseudoRandomString(length: 8)
            let verificationLevel = 0

            contact = databasePreparer.createContact(
                publicKey: publicKey,
                identity: identity,
                verificationLevel: verificationLevel
            )
        }
        return contact
    }
}
