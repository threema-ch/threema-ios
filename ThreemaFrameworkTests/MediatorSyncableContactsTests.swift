//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

import XCTest
@testable import ThreemaFramework

class MediatorSyncableContactsTests: XCTestCase {
    private var databasePreparer: DatabasePreparer!
    private var databaseBackgroundCnx: DatabaseContext!
    let testBundle = Bundle(for: MediatorSyncableContactsTests.self)
    
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
            ServerConnectorMock(
                connectionState: .loggedIn,
                deviceID: BytesUtility.generateRandomBytes(length: Int(8))!,
                deviceGroupPathKey: BytesUtility.generateRandomBytes(length: Int(kDeviceGroupPathKeyLen))!
            ),
            taskManagerMock,
            EntityManager(databaseContext: databaseBackgroundCnx, myIdentityStore: MyIdentityStoreMock())
        )

        let noContacts = 500
        for _ in 0..<noContacts {
            let contact = getMinimalContact()

            mediatorSyncableContacts.updateAll(identity: contact.identity, withoutProfileImage: true)
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
            let serverConnectorMock = ServerConnectorMock()
            serverConnectorMock.deviceGroupPathKey = BytesUtility
                .generateRandomBytes(length: Int(kDeviceGroupPathKeyLen))!
            let taskManagerMock = TaskManagerMock()
            
            let mediatorSyncableContacts = MediatorSyncableContacts(
                serverConnectorMock,
                taskManagerMock,
                EntityManager(databaseContext: databaseBackgroundCnx)
            )
            for _ in 0..<contactCount {
                let contact = getMinimalContact()
                mediatorSyncableContacts.updateAll(identity: contact.identity, withoutProfileImage: true)
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
        let serverConnectorMock = ServerConnectorMock()
        serverConnectorMock.deviceGroupPathKey = BytesUtility.generateRandomBytes(length: Int(kDeviceGroupPathKeyLen))!
        let taskManagerMock = TaskManagerMock()
        
        let mediatorSyncableContacts = MediatorSyncableContacts(
            serverConnectorMock,
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
        struct TestInput {
            var contact: Contact
        }
        struct TestOutput {
            var delta: DeltaSyncContact
        }
        
        var table = [(name: String, input: TestInput, output: TestOutput)]()
        
        // Test 1: Basic Test
        let testContact1 = getBaseContact(setProfilePicture: true, setContactProfilePicture: true)
        let test1 = (
            "Basic Test",
            TestInput(contact: testContact1),
            TestOutput(delta: getDeltaSyncContact(from: testContact1))
        )
        table.append(test1)
        
        // Test 2: No Profile Picture Test
        let testContact2 = getBaseContact(setProfilePicture: false, setContactProfilePicture: false)
        let test2 = (
            "No Profile Picture Test",
            TestInput(contact: testContact2),
            TestOutput(delta: getDeltaSyncContact(from: testContact2))
        )
        table.append(test2)

        // Test 3: Only User Profile Picture Test
        let testContact3 = getBaseContact(setProfilePicture: true, setContactProfilePicture: false)
        let test3 = (
            "Only User Profile Picture Test",
            TestInput(contact: testContact3),
            TestOutput(delta: getDeltaSyncContact(from: testContact3))
        )
        table.append(test3)

        // Test 4: Only Contact Profile Picture Test
        let testContact4 = getBaseContact(setProfilePicture: false, setContactProfilePicture: true)
        let test4 = (
            "Only Contact Profile Picture Test",
            TestInput(contact: testContact4),
            TestOutput(delta: getDeltaSyncContact(from: testContact4))
        )
        table.append(test4)
        
        let serverConnectorMock = ServerConnectorMock()
        serverConnectorMock.deviceGroupPathKey = BytesUtility.generateRandomBytes(length: Int(kDeviceGroupPathKeyLen))!
        
        for test in table {
            let taskManagerMock = TaskManagerMock()
            let mediatorSyncableContacts = MediatorSyncableContacts(
                serverConnectorMock,
                taskManagerMock,
                EntityManager(databaseContext: databaseBackgroundCnx)
            )
            
            let expec =
                XCTestExpectation(description: "Completion is executed immediately if multi device is not enabled")
            
            mediatorSyncableContacts.updateAll(identity: test.input.contact.identity, withoutProfileImage: false)

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
                            XCTAssertEqual(
                                delta.syncContact.identity,
                                test.output.delta.syncContact.identity,
                                "\(test.name)"
                            )
                            XCTAssertEqual(
                                delta.syncContact.publicKey,
                                test.output.delta.syncContact.publicKey,
                                "\(test.name)"
                            )
                            XCTAssertEqual(
                                delta.syncContact.nickname,
                                test.output.delta.syncContact.nickname,
                                "\(test.name)"
                            )
                            XCTAssertEqual(
                                delta.syncContact.firstName,
                                test.output.delta.syncContact.firstName,
                                "\(test.name)"
                            )
                            XCTAssertEqual(
                                delta.syncContact.lastName,
                                test.output.delta.syncContact.lastName,
                                "\(test.name)"
                            )
                            XCTAssertEqual(
                                delta.syncContact.activityState,
                                test.output.delta.syncContact.activityState,
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
                                delta.syncContact.identityType,
                                test.output.delta.syncContact.identityType,
                                "\(test.name)"
                            )
                            XCTAssertEqual(
                                delta.syncContact.syncState,
                                test.output.delta.syncContact.syncState,
                                "\(test.name)"
                            )
                            XCTAssertEqual(
                                delta.syncContact.verificationLevel,
                                test.output.delta.syncContact.verificationLevel,
                                "\(test.name)"
                            )
                            XCTAssertEqual(
                                delta.syncContact.createdAt,
                                test.output.delta.syncContact.createdAt,
                                "\(test.name)"
                            )
                            XCTAssertFalse(delta.syncContact.hasAcquaintanceLevel, "\(test.name)")
                            XCTAssertFalse(delta.syncContact.hasUserDefinedProfilePicture, "\(test.name)")
                            XCTAssertFalse(delta.syncContact.hasContactDefinedProfilePicture, "\(test.name)")

                            XCTAssertEqual(delta.profilePicture, test.output.delta.profilePicture, "\(test.name)")
                            XCTAssertEqual(
                                delta.contactProfilePicture,
                                test.output.delta.contactProfilePicture,
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

    // Implementation like MediatorSyncableContacts.updateAll(...) -> makes this sence for testing???
    private func getDeltaSyncContact(from contact: Contact) -> DeltaSyncContact {
        let conversation = contact.conversations!.first as? Conversation
        
        var delta = DeltaSyncContact(syncContact: Sync_Contact())
        delta.syncContact.identity = contact.identity
        delta.syncContact.publicKey = contact.publicKey

        if let firstName = contact.firstName {
            delta.syncContact.firstName = firstName
        }
        else {
            delta.syncContact.clearFirstName()
        }

        if let lastName = contact.lastName {
            delta.syncContact.lastName = lastName
        }
        else {
            delta.syncContact.clearLastName()
        }

        delta.syncContact.identityType = contact.workContact.boolValue ? .work : .regular

        if let nickname = contact.publicNickname {
            delta.syncContact.nickname = nickname
        }
        else {
            delta.syncContact.clearNickname()
        }

        if let createAt = contact.createdAt {
            delta.syncContact.createdAt = UInt64(createAt.millisecondsSince1970)
        }
        else {
            delta.syncContact.clearCreatedAt()
        }

        delta.syncContact.verificationLevel = Sync_Contact
            .VerificationLevel(rawValue: Int(truncating: contact.verificationLevel))!

        switch contact.state?.intValue {
        case kStateActive:
            delta.syncContact.activityState = .active
        case kStateInactive:
            delta.syncContact.activityState = .inactive
        case kStateInvalid:
            delta.syncContact.activityState = .invalid
        default:
            delta.syncContact.clearActivityState()
        }

        switch contact.importedStatus {
        case .initial:
            delta.syncContact.syncState = .initial
        case .imported:
            delta.syncContact.syncState = .imported
        case .custom:
            delta.syncContact.syncState = .custom
        }

        if let visibility = conversation?.conversationVisibility {
            switch visibility {
            case .archived:
                delta.syncContact.conversationVisibility = .archive
            default:
                delta.syncContact.conversationVisibility = .show
            }
        }
        else {
            delta.syncContact.clearConversationVisibility()
        }

        if let category = conversation?.conversationCategory {
            switch category {
            case .default:
                delta.syncContact.conversationCategory = .default
            case .private:
                delta.syncContact.conversationCategory = .protected
            default:
                delta.syncContact.conversationCategory = .protected
            }
        }
        else {
            delta.syncContact.clearConversationCategory()
        }

        delta.profilePicture = contact.imageData != nil ? .updated : .removed
        delta.contactProfilePicture = contact.contactImage?.data != nil ? .updated : .removed
        delta.image = contact.imageData
        delta.contactImage = contact.contactImage?.data
        
        return delta
    }
    
    private func getBaseContact(setProfilePicture: Bool, setContactProfilePicture: Bool) -> Contact {
        let contact: Contact = getMinimalContact()
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
            contact.hidden = NSNumber(value: 0)
            // Optional
            contact.importedStatus = .initial
            // Optional
            databasePreparer.createConversation(
                marked: false,
                typing: false,
                unreadMessageCount: 0,
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
        }
        return contact
    }
    
    private func getMinimalContact() -> Contact {
        var contact: Contact!
        databasePreparer.save {
            let publicKey = BytesUtility.generateRandomBytes(length: 32)!
            let identity = SwiftUtils.pseudoRandomString(length: 7)
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
