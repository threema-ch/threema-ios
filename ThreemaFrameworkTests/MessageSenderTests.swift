//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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
import ThreemaEssentials
import XCTest

@testable import ThreemaFramework

class MessageSenderTests: XCTestCase {
    private var dbMainCnx: DatabaseContext!
    private var dbBackgroundCnx: DatabaseContext!
    private var dbPreparer: DatabasePreparer!
    
    private var ddLoggerMock: DDLoggerMock!
    
    private lazy var taskManagerMock = TaskManagerMock()
    private lazy var entityManager = EntityManager(databaseContext: dbMainCnx)
    private lazy var blobMessageSender = BlobMessageSender(
        businessInjector: BusinessInjectorMock(entityManager: entityManager),
        taskManager: taskManagerMock
    )
    
    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")
        
        let (_, mainCnx, backgroundCnx) = DatabasePersistentContext.devNullContext()
        dbMainCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        dbBackgroundCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)
        dbPreparer = DatabasePreparer(context: mainCnx)
        
        ddLoggerMock = DDLoggerMock()
        DDTTYLogger.sharedInstance?.logFormatter = LogFormatterCustom()
        DDLog.add(ddLoggerMock)
    }
    
    func testSendBlobMessage() async throws {
        // Setup
        
        let testItemData = Data("Test item data.".utf8)
        let testFileName = "Testfile"
        let urlSenderItem = try XCTUnwrap(URLSenderItem(
            data: testItemData,
            fileName: testFileName,
            type: "application/octet-stream",
            renderType: 0,
            sendAsFile: true
        ))
        
        let expectedThreemaIdentity = ThreemaIdentity("ECHOECHO")
        let conversation = dbPreparer.save {
            let contactEntity = dbPreparer.createContact(identity: expectedThreemaIdentity.string)
            return dbPreparer.createConversation(contactEntity: contactEntity)
        }
        
        let blobManagerMock = BlobManagerMock()
        blobManagerMock.syncHandler = { objectID in
            guard let blobData = self.entityManager.entityFetcher.existingObject(with: objectID) as? BlobData else {
                XCTFail("A message should exist")
                return .failed
            }
            
            self.entityManager.performAndWaitSave {
                blobData.blobIdentifier = MockData.generateBlobID()
            }
            
            return .uploaded
        }
        
        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            groupManager: GroupManagerMock(),
            taskManager: taskManagerMock,
            entityManager: entityManager,
            blobManager: blobManagerMock,
            blobMessageSender: blobMessageSender
        )
        
        // Run
        
        try await messageSender.sendBlobMessage(
            for: urlSenderItem,
            in: conversation.objectID,
            correlationID: nil,
            webRequestID: nil
        )
        
        // Validate
        
        XCTAssertEqual(taskManagerMock.addedTasks.count, 1)
        let addedSendBaseMessageTask = try XCTUnwrap(taskManagerMock.addedTasks.first as? TaskDefinitionSendBaseMessage)
        
        XCTAssertEqual(addedSendBaseMessageTask.receiverIdentity, expectedThreemaIdentity.string)
        XCTAssertNil(addedSendBaseMessageTask.groupID)
        XCTAssertNil(addedSendBaseMessageTask.groupCreatorIdentity)
        XCTAssertNil(addedSendBaseMessageTask.groupName)
        XCTAssertNil(addedSendBaseMessageTask.receivingGroupMembers)
        
        // Check that a message with the blob was created
        let blobMessage = try XCTUnwrap(
            entityManager.entityFetcher.ownMessage(
                with: addedSendBaseMessageTask.messageID,
                conversation: conversation
            ) as? FileMessageProvider
        )
        XCTAssertEqual(blobMessage.blobData, testItemData)
    }
    
    func testSendBaseMessage() async throws {
        // Setup
        
        let expectedThreemaIdentity = ThreemaIdentity("ECHOECHO")
        let expectedMessageID = MockData.generateMessageID()

        let message = dbPreparer.save {
            let contactEntity = dbPreparer.createContact(identity: expectedThreemaIdentity.string)

            let conversation = dbPreparer.createConversation(contactEntity: contactEntity)
            let textMessage = dbPreparer.createTextMessage(
                conversation: conversation,
                id: expectedMessageID,
                isOwn: true,
                sender: contactEntity,
                remoteSentDate: Date()
            )
            textMessage.sendFailed = true
            
            return textMessage
        }

        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            groupManager: GroupManagerMock(),
            taskManager: taskManagerMock,
            entityManager: entityManager,
            blobManager: BlobManagerMock(),
            blobMessageSender: blobMessageSender
        )

        // Run
        
        await messageSender.sendBaseMessage(with: message.objectID)
        
        // Validate
        
        XCTAssertEqual(taskManagerMock.addedTasks.count, 1)
        let addedSendBaseMessageTask = try XCTUnwrap(taskManagerMock.addedTasks.first as? TaskDefinitionSendBaseMessage)
        
        XCTAssertEqual(addedSendBaseMessageTask.receiverIdentity, expectedThreemaIdentity.string)
        XCTAssertNil(addedSendBaseMessageTask.groupID)
        XCTAssertNil(addedSendBaseMessageTask.groupCreatorIdentity)
        XCTAssertNil(addedSendBaseMessageTask.groupName)
        XCTAssertNil(addedSendBaseMessageTask.receivingGroupMembers)

        XCTAssertFalse(message.sendFailed?.boolValue ?? false)
    }
    
    func testSendBaseMessageBlob() async throws {
        // Setup
        
        let testItemData = Data("Test item data.".utf8)
        
        let expectedThreemaIdentity = ThreemaIdentity("ECHOECHO")
        let message = dbPreparer.save {
            let contactEntity = dbPreparer.createContact(identity: expectedThreemaIdentity.string)
            let conversation = dbPreparer.createConversation(contactEntity: contactEntity)
            
            let fileDataEntity = dbPreparer.createFileDataEntity(data: testItemData)
            
            return dbPreparer.createFileMessageEntity(
                conversation: conversation,
                data: fileDataEntity,
                mimeType: "application/octet-stream",
                type: 0
            )
        }
        
        let blobManagerMock = BlobManagerMock()
        blobManagerMock.syncHandler = { objectID in
            guard let blobData = self.entityManager.entityFetcher.existingObject(with: objectID) as? BlobData else {
                XCTFail("A message should exist")
                return .failed
            }
            
            self.entityManager.performAndWaitSave {
                blobData.blobIdentifier = MockData.generateBlobID()
            }
            
            return .uploaded
        }

        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            groupManager: GroupManagerMock(),
            taskManager: taskManagerMock,
            entityManager: entityManager,
            blobManager: blobManagerMock,
            blobMessageSender: blobMessageSender
        )
        
        // Run
        
        await messageSender.sendBaseMessage(with: message.objectID)
        
        // Validate
        
        XCTAssertEqual(taskManagerMock.addedTasks.count, 1)
        let addedSendBaseMessageTask = try XCTUnwrap(taskManagerMock.addedTasks.first as? TaskDefinitionSendBaseMessage)
        
        XCTAssertEqual(addedSendBaseMessageTask.receiverIdentity, expectedThreemaIdentity.string)
        XCTAssertNil(addedSendBaseMessageTask.groupID)
        XCTAssertNil(addedSendBaseMessageTask.groupCreatorIdentity)
        XCTAssertNil(addedSendBaseMessageTask.groupName)
        XCTAssertNil(addedSendBaseMessageTask.receivingGroupMembers)

        XCTAssertFalse(message.sendFailed?.boolValue ?? false)
    }
    
    func testSendBaseMessageBlobWithError() async throws {
        // Setup
                
        let expectedThreemaIdentity = ThreemaIdentity("ECHOECHO")
        let message = dbPreparer.save {
            let contactEntity = dbPreparer.createContact(identity: expectedThreemaIdentity.string)
            let conversation = dbPreparer.createConversation(contactEntity: contactEntity)
            return dbPreparer.createFileMessageEntity(conversation: conversation)
        }
        
        let blobManagerMock = BlobManagerMock()
        blobManagerMock.syncHandler = { _ in
            throw BlobManagerError.noData
        }

        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            groupManager: GroupManagerMock(),
            taskManager: taskManagerMock,
            entityManager: entityManager,
            blobManager: blobManagerMock,
            blobMessageSender: blobMessageSender
        )
        
        // Run
        
        await messageSender.sendBaseMessage(with: message.objectID)
        
        // Validate
        
        XCTAssertEqual(taskManagerMock.addedTasks.count, 0)
        XCTAssertTrue(message.sendFailed?.boolValue ?? false)
    }
    
    func testSendBaseMessageToGroup() async throws {
        // Setup
        
        let expectedMessageID = MockData.generateMessageID()
        
        let myIdentityStoreMock = MyIdentityStoreMock()
        
        let expectedGroupID = MockData.generateGroupID()
        let membersWithoutCreator = ["MEMBER01", "MEMBER02", "MEMBER03"]
        let expectedReceivers = Set(membersWithoutCreator)

        // Setup initial group in DB

        let message = dbPreparer.save {
            let members = membersWithoutCreator.map { identityString in
                dbPreparer.createContact(
                    publicKey: MockData.generatePublicKey(),
                    identity: identityString,
                    verificationLevel: 0
                )
            }
            
            _ = dbPreparer.createGroupEntity(
                groupID: expectedGroupID,
                groupCreator: nil
            )
            let conversation = dbPreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default
            ) { conversation in
                // swiftformat:disable:next acronyms
                conversation.groupId = expectedGroupID
                conversation.groupMyIdentity = myIdentityStoreMock.identity
                conversation.members?.formUnion(members)
            }
            
            let textMessage = dbPreparer.createTextMessage(
                conversation: conversation,
                id: expectedMessageID,
                isOwn: true,
                sender: nil,
                remoteSentDate: nil
            )
            textMessage.sendFailed = true
            
            return textMessage
        }

        let userSettingMock = UserSettingsMock()
        
        let groupManager = GroupManager(
            myIdentityStoreMock,
            ContactStoreMock(),
            taskManagerMock,
            userSettingMock,
            entityManager,
            GroupPhotoSenderMock()
        )
        
        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingMock,
            groupManager: groupManager,
            taskManager: taskManagerMock,
            entityManager: entityManager,
            blobManager: BlobManagerMock(),
            blobMessageSender: blobMessageSender
        )

        // Run
        
        await messageSender.sendBaseMessage(with: message.objectID)
        
        // Validate
        
        XCTAssertEqual(taskManagerMock.addedTasks.count, 1)
        let addedSendBaseMessageTask = try XCTUnwrap(taskManagerMock.addedTasks.first as? TaskDefinitionSendBaseMessage)
        
        XCTAssertNil(addedSendBaseMessageTask.receiverIdentity)
        XCTAssertEqual(addedSendBaseMessageTask.groupID, expectedGroupID)
        XCTAssertEqual(addedSendBaseMessageTask.groupCreatorIdentity, myIdentityStoreMock.identity)
        XCTAssertNil(addedSendBaseMessageTask.groupName) // We didn't set a group name
        XCTAssertEqual(addedSendBaseMessageTask.receivingGroupMembers, expectedReceivers)

        XCTAssertFalse(message.sendFailed?.boolValue ?? false)
    }
    
    func testSendBaseMessageToSubsetOfGroupMembers() async throws {
        // Setup
        
        let expectedMessageID = MockData.generateMessageID()
        
        let myIdentityStoreMock = MyIdentityStoreMock()
        
        let expectedGroupID = MockData.generateGroupID()
        let membersWithoutCreator = ["MEMBER01", "MEMBER02", "MEMBER03"]
        let expectedReceivers = Set(membersWithoutCreator[0...1])

        // Setup initial group in DB

        let message = dbPreparer.save {
            let members = membersWithoutCreator.map { identityString in
                dbPreparer.createContact(
                    publicKey: MockData.generatePublicKey(),
                    identity: identityString,
                    verificationLevel: 0
                )
            }
            let rejectedByContacts = members.filter { contact in
                expectedReceivers.contains(contact.identity)
            }
            
            _ = dbPreparer.createGroupEntity(
                groupID: expectedGroupID,
                groupCreator: nil
            )
            let conversation = dbPreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default
            ) { conversation in
                // swiftformat:disable:next acronyms
                conversation.groupId = expectedGroupID
                conversation.groupMyIdentity = myIdentityStoreMock.identity
                conversation.members = Set(members)
            }
            
            let textMessage = dbPreparer.createTextMessage(
                conversation: conversation,
                id: expectedMessageID,
                isOwn: true,
                sender: nil,
                remoteSentDate: nil
            )
            textMessage.sendFailed = true
            textMessage.rejectedBy = Set(rejectedByContacts)
            
            return textMessage
        }

        let userSettingMock = UserSettingsMock()
        
        let groupManager = GroupManager(
            myIdentityStoreMock,
            ContactStoreMock(),
            taskManagerMock,
            userSettingMock,
            entityManager,
            GroupPhotoSenderMock()
        )
        
        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingMock,
            groupManager: groupManager,
            taskManager: taskManagerMock,
            entityManager: entityManager,
            blobManager: BlobManagerMock(),
            blobMessageSender: blobMessageSender
        )

        // Run
        
        await messageSender.sendBaseMessage(
            with: message.objectID,
            to: .groupMembers(expectedReceivers.map { ThreemaIdentity($0) })
        )
        
        // Validate
        
        XCTAssertEqual(taskManagerMock.addedTasks.count, 1)
        let addedSendBaseMessageTask = try XCTUnwrap(taskManagerMock.addedTasks.first as? TaskDefinitionSendBaseMessage)
        
        XCTAssertNil(addedSendBaseMessageTask.receiverIdentity)
        XCTAssertEqual(addedSendBaseMessageTask.groupID, expectedGroupID)
        XCTAssertEqual(addedSendBaseMessageTask.groupCreatorIdentity, myIdentityStoreMock.identity)
        XCTAssertNil(addedSendBaseMessageTask.groupName) // We didn't set a group name
        XCTAssertEqual(addedSendBaseMessageTask.receivingGroupMembers, expectedReceivers)

        XCTAssertFalse(message.sendFailed?.boolValue ?? false)
    }
    
    func testSendBaseMessageToSubsetOfRejectedGroupMembers() async throws {
        // Setup
        
        let expectedMessageID = MockData.generateMessageID()
        
        let myIdentityStoreMock = MyIdentityStoreMock()
        
        let expectedGroupID = MockData.generateGroupID()
        let membersWithoutCreator = ["MEMBER01", "MEMBER02", "MEMBER03", "MEMBER04"]
        let rejectedBy = membersWithoutCreator[1...]
        let expectedReceivers = Set(membersWithoutCreator[2...])

        // Setup initial group in DB

        let message = dbPreparer.save {
            let members = membersWithoutCreator.map { identityString in
                dbPreparer.createContact(
                    publicKey: MockData.generatePublicKey(),
                    identity: identityString,
                    verificationLevel: 0
                )
            }
            let rejectedByContacts = members.filter { contact in
                rejectedBy.contains(contact.identity)
            }
            
            _ = dbPreparer.createGroupEntity(
                groupID: expectedGroupID,
                groupCreator: nil
            )
            let conversation = dbPreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default
            ) { conversation in
                // swiftformat:disable:next acronyms
                conversation.groupId = expectedGroupID
                conversation.groupMyIdentity = myIdentityStoreMock.identity
                conversation.members = Set(members)
            }
            
            let textMessage = dbPreparer.createTextMessage(
                conversation: conversation,
                id: expectedMessageID,
                isOwn: true,
                sender: nil,
                remoteSentDate: nil
            )
            textMessage.sendFailed = true
            textMessage.rejectedBy = Set(rejectedByContacts)
            
            return textMessage
        }

        let userSettingMock = UserSettingsMock()
        
        let groupManager = GroupManager(
            myIdentityStoreMock,
            ContactStoreMock(),
            taskManagerMock,
            userSettingMock,
            entityManager,
            GroupPhotoSenderMock()
        )
        
        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingMock,
            groupManager: groupManager,
            taskManager: taskManagerMock,
            entityManager: entityManager,
            blobManager: BlobManagerMock(),
            blobMessageSender: blobMessageSender
        )

        // Run
        
        await messageSender.sendBaseMessage(
            with: message.objectID,
            to: .groupMembers(expectedReceivers.map { ThreemaIdentity($0) })
        )
        
        // Validate
        
        XCTAssertEqual(taskManagerMock.addedTasks.count, 1)
        let addedSendBaseMessageTask = try XCTUnwrap(taskManagerMock.addedTasks.first as? TaskDefinitionSendBaseMessage)
        
        XCTAssertNil(addedSendBaseMessageTask.receiverIdentity)
        XCTAssertEqual(addedSendBaseMessageTask.groupID, expectedGroupID)
        XCTAssertEqual(addedSendBaseMessageTask.groupCreatorIdentity, myIdentityStoreMock.identity)
        XCTAssertNil(addedSendBaseMessageTask.groupName) // We didn't set a group name
        XCTAssertEqual(addedSendBaseMessageTask.receivingGroupMembers, expectedReceivers)

        XCTAssertTrue(message.sendFailed?.boolValue ?? false)
    }
    
    func testSendTextMessageToDistributionList() async throws {
        // Setup
        
        let recipients = ["MEMBER01", "MEMBER02", "MEMBER03"]

        // Setup initial group in DB

        let conversation = dbPreparer.save {
            let recipients = recipients.map { identityString in
                dbPreparer.createContact(
                    publicKey: MockData.generatePublicKey(),
                    identity: identityString,
                    verificationLevel: 0
                )
            }
            
            // We create one conversation for the recipients, the rest should be auto created.
            dbPreparer.createConversation(contactEntity: recipients.first!)
            
            let distributionList = dbPreparer.createDistributionListEntity(id: 0)
            let conversation = dbPreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default
            ) { conversation in
                conversation.distributionList = distributionList
                conversation.members = Set(recipients)
            }
            
            return conversation
        }

        let userSettingMock = UserSettingsMock()
        
        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: userSettingMock,
            groupManager: GroupManagerMock(),
            taskManager: taskManagerMock,
            entityManager: entityManager,
            blobManager: BlobManagerMock(),
            blobMessageSender: blobMessageSender
        )

        // Run
        
        await messageSender.sendTextMessage(containing: "Test", in: conversation)
        
        // Validate
        
        XCTAssertEqual(taskManagerMock.addedTasks.count, 3)
        let addedSendBaseMessageTask = try XCTUnwrap(taskManagerMock.addedTasks.first as? TaskDefinitionSendBaseMessage)
    }

    func testSendDeliveryReceipt() throws {
        let testMessages: [AbstractMessage] = [
            BoxAudioMessage(),
            BoxBallotCreateMessage(),
            BoxBallotVoteMessage(),
            BoxFileMessage(),
            BoxImageMessage(),
            BoxLocationMessage(),
            BoxTextMessage(),
            BoxVideoMessage(),
            BoxVoIPCallAnswerMessage(),
            BoxVoIPCallHangupMessage(),
            BoxVoIPCallIceCandidatesMessage(),
            BoxVoIPCallOfferMessage(),
            BoxVoIPCallRingingMessage(),
            ContactDeletePhotoMessage(),
            ContactRequestPhotoMessage(),
            ContactSetPhotoMessage(),
            DeliveryReceiptMessage(),
            GroupAudioMessage(),
            GroupBallotCreateMessage(),
            GroupBallotVoteMessage(),
            GroupCreateMessage(),
            GroupDeletePhotoMessage(),
            GroupDeliveryReceiptMessage(),
            GroupFileMessage(),
            GroupImageMessage(),
            GroupLeaveMessage(),
            GroupLocationMessage(),
            GroupRenameMessage(),
            GroupRequestSyncMessage(),
            GroupSetPhotoMessage(),
            GroupTextMessage(),
            GroupVideoMessage(),
            TypingIndicatorMessage(),
            UnknownTypeMessage(),
            GroupCallStartMessage(),
        ]

        for testMessage in testMessages {
            testMessage.fromIdentity = "ECHOECHO"
            taskManagerMock.addedTasks = []
            
            let messageSender = MessageSender(
                serverConnector: ServerConnectorMock(),
                myIdentityStore: MyIdentityStoreMock(),
                userSettings: UserSettingsMock(),
                groupManager: GroupManagerMock(),
                taskManager: taskManagerMock,
                entityManager: entityManager,
                blobManager: BlobManagerMock(),
                blobMessageSender: blobMessageSender
            )

            let expect = expectation(description: "Send delivery receipt")

            _ = messageSender.sendDeliveryReceipt(for: testMessage)
                .done {
                    expect.fulfill()
                }

            wait(for: [expect], timeout: 3)

            XCTAssertEqual(taskManagerMock.addedTasks.count, testMessage.noDeliveryReceiptFlagSet() ? 0 : 1)
        }
    }

    func testSendUserAck() async throws {
        let expectedThreemaIdentity = ThreemaIdentity("ECHOECHO")
        let expectedMessageID = MockData.generateMessageID()
        let expectedReadDate = Date()

        let message = dbPreparer.save {
            let contactEntity = dbPreparer.createContact(identity: expectedThreemaIdentity.string)

            let conversation = dbPreparer.createConversation(contactEntity: contactEntity)
            return dbPreparer.createTextMessage(
                conversation: conversation,
                id: expectedMessageID,
                isOwn: false,
                readDate: expectedReadDate,
                sender: contactEntity,
                remoteSentDate: Date()
            )
        }

        let taskManagerMock = TaskManagerMock()

        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            groupManager: GroupManagerMock(),
            taskManager: taskManagerMock,
            entityManager: EntityManager(databaseContext: dbMainCnx)
        )

        await messageSender.sendUserAck(for: message, toIdentity: expectedThreemaIdentity)

        XCTAssertFalse(taskManagerMock.addedTasks.isEmpty)
        XCTAssertEqual(
            1,
            taskManagerMock.addedTasks.filter { task in
                guard let task = task as? TaskDefinitionSendDeliveryReceiptsMessage else {
                    return false
                }
                return task.receiptType == .ack &&
                    task.toIdentity == expectedThreemaIdentity.string &&
                    task.receiptMessageIDs.contains(expectedMessageID) &&
                    task.receiptReadDates.isEmpty
            }.count
        )
    }

    func testSendReadReceipt() async throws {
        let expectedThreemaIdentity = ThreemaIdentity("ECHOECHO")
        let expectedMessageID = MockData.generateMessageID()
        let expectedReadDate = Date()

        let message = dbPreparer.save {
            let contactEntity = dbPreparer.createContact(identity: expectedThreemaIdentity.string)

            let conversation = dbPreparer.createConversation(contactEntity: contactEntity)
            return dbPreparer.createTextMessage(
                conversation: conversation,
                id: expectedMessageID,
                isOwn: false,
                readDate: expectedReadDate,
                sender: contactEntity,
                remoteSentDate: Date()
            )
        }

        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            groupManager: GroupManagerMock(),
            taskManager: taskManagerMock,
            entityManager: entityManager,
            blobManager: BlobManagerMock(),
            blobMessageSender: blobMessageSender
        )

        await messageSender.sendReadReceipt(for: [message], toIdentity: expectedThreemaIdentity)

        XCTAssertFalse(taskManagerMock.addedTasks.isEmpty)
        XCTAssertEqual(
            1,
            taskManagerMock.addedTasks.filter { task in
                guard let task = task as? TaskDefinitionSendDeliveryReceiptsMessage else {
                    return false
                }
                return task.receiptType == .read &&
                    task.toIdentity == expectedThreemaIdentity.string &&
                    task.receiptMessageIDs.contains(expectedMessageID) &&
                    task.receiptReadDates.contains(expectedReadDate)
            }.count
        )
    }

    func testSendReadReceiptDefaultNoReadReceipt() async throws {
        let expectedThreemaIdentity = ThreemaIdentity("ECHOECHO")

        let message = dbPreparer.save {
            let contactEntity = dbPreparer.createContact(identity: expectedThreemaIdentity.string)
            let conversation = dbPreparer.createConversation(contactEntity: contactEntity)
            return dbPreparer.createTextMessage(
                conversation: conversation,
                isOwn: false,
                sender: contactEntity,
                remoteSentDate: Date()
            )
        }

        let userSettings = UserSettingsMock()
        userSettings.sendReadReceipts = false

        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: userSettings,
            groupManager: GroupManagerMock(),
            taskManager: taskManagerMock,
            entityManager: entityManager,
            blobManager: BlobManagerMock(),
            blobMessageSender: blobMessageSender
        )

        await messageSender.sendReadReceipt(for: [message], toIdentity: expectedThreemaIdentity)
        XCTAssertTrue(taskManagerMock.addedTasks.isEmpty)
    }

    func testSendReadReceiptContactNoReadReceipt() async throws {
        let expectedThreemaIdentity = ThreemaIdentity("ECHOECHO")

        let message = dbPreparer.save {
            let contactEntity = dbPreparer.createContact(identity: expectedThreemaIdentity.string)
            contactEntity.readReceipt = .doNotSend

            let conversation = dbPreparer.createConversation(contactEntity: contactEntity)
            return dbPreparer.createTextMessage(
                conversation: conversation,
                isOwn: false,
                sender: contactEntity,
                remoteSentDate: Date()
            )
        }

        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            groupManager: GroupManagerMock(),
            taskManager: taskManagerMock,
            entityManager: entityManager,
            blobManager: BlobManagerMock(),
            blobMessageSender: blobMessageSender
        )

        await messageSender.sendReadReceipt(for: [message], toIdentity: expectedThreemaIdentity)

        XCTAssertTrue(taskManagerMock.addedTasks.isEmpty)
    }

    func testSendReadReceiptContactNoReadReceiptButMultiDeviceActivated() async throws {
        let expectedThreemaIdentity = ThreemaIdentity("ECHOECHO")
        let expectedMessageID = MockData.generateMessageID()
        let expectedReadDate = Date()

        let message = dbPreparer.save {
            let contactEntity = dbPreparer.createContact(identity: expectedThreemaIdentity.string)
            contactEntity.readReceipt = .doNotSend

            let conversation = dbPreparer.createConversation(contactEntity: contactEntity)
            return dbPreparer.createTextMessage(
                conversation: conversation,
                id: expectedMessageID,
                isOwn: false,
                readDate: expectedReadDate,
                sender: contactEntity,
                remoteSentDate: Date()
            )
        }

        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: MockData.deviceID,
            deviceGroupKeys: MockData.deviceGroupKeys
        )

        let messageSender = MessageSender(
            serverConnector: serverConnectorMock,
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(enableMultiDevice: true),
            groupManager: GroupManagerMock(),
            taskManager: taskManagerMock,
            entityManager: entityManager,
            blobManager: BlobManagerMock(),
            blobMessageSender: blobMessageSender
        )

        await messageSender.sendReadReceipt(for: [message], toIdentity: expectedThreemaIdentity)

        XCTAssertFalse(taskManagerMock.addedTasks.isEmpty)
        XCTAssertEqual(
            1,
            taskManagerMock.addedTasks.filter { task in
                guard let task = task as? TaskDefinitionSendDeliveryReceiptsMessage else {
                    return false
                }
                return task.receiptType == .read &&
                    task.toIdentity == expectedThreemaIdentity.string &&
                    task.receiptMessageIDs.contains(expectedMessageID) &&
                    task.receiptReadDates.contains(expectedReadDate)
            }.count
        )
    }

    func testSendReadReceiptGroup() async throws {
        let expectedGroupIdentity = GroupIdentity(
            id: MockData.generateGroupID(),
            creator: ThreemaIdentity("ECHOECHO")
        )
        let expectedThreemaIdentity = ThreemaIdentity("ECHOECHO")

        let (groupEntity, message) = dbPreparer.save {
            let contactEntity = dbPreparer.createContact(identity: expectedThreemaIdentity.string)

            let groupEntity = dbPreparer.createGroupEntity(
                groupID: expectedGroupIdentity.id,
                groupCreator: nil
            )
            // swiftformat:disable:next acronyms
            let conversation = dbPreparer.createConversation(groupID: groupEntity.groupId)
            return (groupEntity, dbPreparer.createTextMessage(
                conversation: conversation,
                isOwn: false,
                sender: contactEntity,
                remoteSentDate: Date()
            ))
        }

        let groupManagerMock = GroupManagerMock()
        groupManagerMock.getGroupReturns.append(Group(
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            groupEntity: groupEntity,
            conversation: message.conversation,
            lastSyncRequest: nil
        ))

        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            groupManager: groupManagerMock,
            taskManager: taskManagerMock,
            entityManager: entityManager,
            blobManager: BlobManagerMock(),
            blobMessageSender: blobMessageSender
        )

        await messageSender.sendReadReceipt(for: [message], toGroupIdentity: expectedGroupIdentity)

        XCTAssertTrue(taskManagerMock.addedTasks.isEmpty)
    }

    func testSendReadReceiptGroupButMultiDeviceActivated() async throws {
        let expectedGroupIdentity = GroupIdentity(
            id: MockData.generateGroupID(),
            creator: ThreemaIdentity(MyIdentityStoreMock().identity)
        )
        let expectedThreemaIdentity = ThreemaIdentity("ECHOECHO")
        let expectedMessageID = MockData.generateMessageID()
        let expectedReadDate = Date()

        let (groupEntity, message) = dbPreparer.save {
            let contactEntity = dbPreparer.createContact(identity: expectedThreemaIdentity.string)

            let groupEntity = dbPreparer.createGroupEntity(
                groupID: expectedGroupIdentity.id,
                groupCreator: nil
            )
            // swiftformat:disable:next acronyms
            let conversation = dbPreparer.createConversation(groupID: groupEntity.groupId)
            return (groupEntity, dbPreparer.createTextMessage(
                conversation: conversation,
                id: expectedMessageID,
                isOwn: false,
                readDate: expectedReadDate,
                sender: contactEntity,
                remoteSentDate: Date()
            ))
        }

        let userSettingsMock = UserSettingsMock(enableMultiDevice: true)
        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: MockData.deviceID,
            deviceGroupKeys: MockData.deviceGroupKeys
        )
        let groupManagerMock = GroupManagerMock()
        groupManagerMock.getGroupReturns.append(Group(
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: userSettingsMock,
            groupEntity: groupEntity,
            conversation: message.conversation,
            lastSyncRequest: nil
        ))

        let messageSender = MessageSender(
            serverConnector: serverConnectorMock,
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: userSettingsMock,
            groupManager: groupManagerMock,
            taskManager: taskManagerMock,
            entityManager: entityManager,
            blobManager: BlobManagerMock(),
            blobMessageSender: blobMessageSender
        )

        await messageSender.sendReadReceipt(for: [message], toGroupIdentity: expectedGroupIdentity)

        XCTAssertFalse(taskManagerMock.addedTasks.isEmpty)
        XCTAssertEqual(
            1,
            taskManagerMock.addedTasks.filter { task in
                guard let task = task as? TaskDefinitionSendGroupDeliveryReceiptsMessage else {
                    return false
                }
                print(task.groupID == expectedGroupIdentity.id)
                print(task.groupCreatorIdentity == expectedGroupIdentity.creator.string)
                print(task.receiptMessageIDs.contains(expectedMessageID))

                return task.receiptType == .read &&
                    task.groupID == expectedGroupIdentity.id &&
                    task.receiptMessageIDs.contains(expectedMessageID) &&
                    task.receiptReadDates.contains(expectedReadDate)
            }.count
        )
    }

    func testNotAllowedDonateInteractionForOutgoingMessage() throws {
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.allowOutgoingDonations = false

        var objectID: NSManagedObjectID!
        dbPreparer.createConversation(typing: false, unreadMessageCount: 100, visibility: .default) { conversation in
            // swiftformat:disable:next acronyms
            conversation.groupId = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
            objectID = conversation.objectID
        }
        let expectation = XCTestExpectation()

        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: userSettingsMock,
            groupManager: GroupManagerMock(),
            taskManager: taskManagerMock,
            entityManager: entityManager,
            blobManager: BlobManagerMock(),
            blobMessageSender: blobMessageSender
        )

        messageSender.donateInteractionForOutgoingMessage(in: objectID).done { success in
            if success {
                XCTFail("Donations are not allowed")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        DDLog.sharedInstance.flushLog()
        
        XCTAssertTrue(ddLoggerMock.exists(message: "Donations are disabled by the user"))
    }
    
    func testDoNotDonateInteractionForOutgoingMessageIfConversationIsPrivate() throws {
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.allowOutgoingDonations = true

        var objectID: NSManagedObjectID!
        dbPreparer.createConversation(typing: false, unreadMessageCount: 100, visibility: .default) { conversation in
            // swiftformat:disable:next acronyms
            conversation.groupId = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
            conversation.changeCategory(to: .private)
            objectID = conversation.objectID
        }
        let expectation = XCTestExpectation()
        
        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: userSettingsMock,
            groupManager: GroupManagerMock(),
            taskManager: taskManagerMock,
            entityManager: entityManager,
            blobManager: BlobManagerMock(),
            blobMessageSender: blobMessageSender
        )

        messageSender.donateInteractionForOutgoingMessage(
            in: objectID,
            backgroundEntityManager: EntityManager(databaseContext: dbBackgroundCnx)
        ).done { success in
            if success {
                XCTFail("Donations are not allowed")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        DDLog.sharedInstance.flushLog()
        
        XCTAssertTrue(ddLoggerMock.exists(message: "Do not donate for private conversations"))
    }
    
    func testAllowedDonateInteractionForOutgoingMessage() throws {
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.allowOutgoingDonations = true

        var objectID: NSManagedObjectID!
        dbPreparer.createConversation(typing: false, unreadMessageCount: 100, visibility: .default) { conversation in
            // swiftformat:disable:next acronyms
            conversation.groupId = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
            objectID = conversation.objectID
        }
        
        let expectation = XCTestExpectation()
        
        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: userSettingsMock,
            groupManager: GroupManagerMock(),
            taskManager: taskManagerMock,
            entityManager: entityManager,
            blobManager: BlobManagerMock(),
            blobMessageSender: blobMessageSender
        )

        messageSender.donateInteractionForOutgoingMessage(
            in: objectID,
            backgroundEntityManager: EntityManager(
                databaseContext: dbBackgroundCnx
            )
        ).done { _ in
            // We don't care about success here and only check the absence of a certain log message below
            // because we don't have enabled all entitlements in all targets

            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        DDLog.sharedInstance.flushLog()
        XCTAssertFalse(ddLoggerMock.exists(message: "Donations are disabled by the user"))
    }

    func testDoSendReadReceiptToContactEntityIsNil() throws {
        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            groupManager: GroupManagerMock(),
            taskManager: taskManagerMock,
            entityManager: entityManager,
            blobManager: BlobManagerMock(),
            blobMessageSender: blobMessageSender
        )

        XCTAssertFalse(messageSender.doSendReadReceipt(to: nil))
    }
    
    // MARK: - Reaction tests
    
    /// Situation:
    /// Local support: Phase 2
    /// Remote support: Legacy
    /// Action: Apply
    /// Mapping: None
    func testApplyReactionNoMappingYesLocalNoRemote() async throws {
        let expectedThreemaIdentity = ThreemaIdentity("ECHOECHO")
        let expectedMessageID = MockData.generateMessageID()
        let expectedReadDate = Date()
        
        let reaction = Emoji.abacus
        
        let message = dbPreparer.save {
            let contactEntity = dbPreparer.createContact(identity: expectedThreemaIdentity.string)
            contactEntity.featureMask = 1
            
            let conversation = dbPreparer.createConversation(contactEntity: contactEntity)
            return dbPreparer.createTextMessage(
                conversation: conversation,
                id: expectedMessageID,
                isOwn: false,
                readDate: expectedReadDate,
                sender: contactEntity,
                remoteSentDate: Date()
            )
        }
        
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.sendEmojiReactions = true
        
        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: userSettingsMock,
            groupManager: GroupManagerMock(),
            taskManager: taskManagerMock,
            entityManager: EntityManager(databaseContext: dbMainCnx)
        )
        let result = try await messageSender.sendReaction(
            to: message.objectID,
            reaction: EmojiVariant(base: reaction, skintone: nil)
        )
        
        XCTAssertEqual(result, .noSupportRemoteSingle)
        XCTAssertTrue(taskManagerMock.addedTasks.isEmpty)
    }
    
    /// Situation:
    /// Local support: Phase 2
    /// Remote support: Legacy
    /// Action: Apply
    /// Mapping: Success
    func testApplyReactionMappingYesLocalNoRemote() async throws {
        let expectedThreemaIdentity = ThreemaIdentity("ECHOECHO")
        let expectedMessageID = MockData.generateMessageID()
        let expectedReadDate = Date()
        let reaction = Emoji.thumbsUpSign
        
        let message = dbPreparer.save {
            let contactEntity = dbPreparer.createContact(identity: expectedThreemaIdentity.string)
            contactEntity.featureMask = 1
            
            let conversation = dbPreparer.createConversation(contactEntity: contactEntity)
            return dbPreparer.createTextMessage(
                conversation: conversation,
                id: expectedMessageID,
                isOwn: false,
                readDate: expectedReadDate,
                sender: contactEntity,
                remoteSentDate: Date()
            )
        }
        
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.sendEmojiReactions = true
        
        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: userSettingsMock,
            groupManager: GroupManagerMock(),
            taskManager: taskManagerMock,
            entityManager: EntityManager(databaseContext: dbMainCnx)
        )
        let result = try await messageSender.sendReaction(
            to: message.objectID,
            reaction: EmojiVariant(base: reaction, skintone: nil)
        )
        
        let addedTasks = taskManagerMock.addedTasks.filter { task in
            guard task is TaskDefinitionSendDeliveryReceiptsMessage else {
                return false
            }
            return true
        }
        
        let testTask = try XCTUnwrap(addedTasks.first as? TaskDefinitionSendDeliveryReceiptsMessage)
       
        XCTAssertFalse(taskManagerMock.addedTasks.isEmpty)
        XCTAssertEqual(1, addedTasks.count)
        XCTAssertEqual(ReceiptType.ack, testTask.receiptType)
        XCTAssertEqual(expectedThreemaIdentity.string, testTask.toIdentity)
        
        XCTAssertEqual(result, .success)
    }
    
    /// Situation:
    /// Local support: Phase 2
    /// Remote support: Legacy
    /// Action: Withdraw
    /// Mapping: Success
    func testWithdrawReactionMappingYesLocalNoRemote() async throws {
        let expectedThreemaIdentity = ThreemaIdentity("ECHOECHO")
        let expectedMessageID = MockData.generateMessageID()
        let expectedReadDate = Date()
        let reaction = Emoji.thumbsUpSign
        
        let message = dbPreparer.save {
            let contactEntity = dbPreparer.createContact(identity: expectedThreemaIdentity.string)
            contactEntity.featureMask = 1

            let conversation = dbPreparer.createConversation(contactEntity: contactEntity)
            
            let message = dbPreparer.createTextMessage(
                conversation: conversation,
                id: expectedMessageID,
                isOwn: false,
                readDate: expectedReadDate,
                sender: contactEntity,
                remoteSentDate: Date()
            )
            
            let _ = MessageReactionEntity(
                context: dbMainCnx.current,
                reaction: reaction.rawValue,
                message: message
            )
            
            return message
        }
        
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.sendEmojiReactions = true
        
        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: userSettingsMock,
            groupManager: GroupManagerMock(),
            taskManager: taskManagerMock,
            entityManager: EntityManager(databaseContext: dbMainCnx)
        )
        let result = try await messageSender.sendReaction(
            to: message.objectID,
            reaction: EmojiVariant(base: reaction, skintone: nil)
        )
        
        XCTAssertEqual(result, .noSupportRemoteSingle)
    }
    
    /// Situation:
    /// Local support: Phase 2
    /// Remote support: Phase 1 or 2
    /// Action: Apply
    /// Mapping: None
    func testApplyReactionNoMappingYesLocalYesRemote() async throws {
        let expectedThreemaIdentity = ThreemaIdentity("ECHOECHO")
        let expectedMessageID = MockData.generateMessageID()
        let expectedReadDate = Date()
        let reaction = Emoji.abacus
        
        let message = dbPreparer.save {
            let contactEntity = dbPreparer.createContact(identity: expectedThreemaIdentity.string)
            contactEntity.featureMask = 2024
            
            let conversation = dbPreparer.createConversation(contactEntity: contactEntity)
            return dbPreparer.createTextMessage(
                conversation: conversation,
                id: expectedMessageID,
                isOwn: false,
                readDate: expectedReadDate,
                sender: contactEntity,
                remoteSentDate: Date()
            )
        }
        
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.sendEmojiReactions = true
        
        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: userSettingsMock,
            groupManager: GroupManagerMock(),
            taskManager: taskManagerMock,
            entityManager: EntityManager(databaseContext: dbMainCnx)
        )
        let result = try await messageSender.sendReaction(
            to: message.objectID,
            reaction: EmojiVariant(base: reaction, skintone: nil)
        )
        
        let addedTasks = taskManagerMock.addedTasks.filter { task in
            guard task is TaskDefinitionSendReactionMessage else {
                return false
            }
            return true
        }
        
        let testTask = try XCTUnwrap(addedTasks.first as? TaskDefinitionSendReactionMessage)
        XCTAssertEqual(result, .success)
        XCTAssertFalse(taskManagerMock.addedTasks.isEmpty)
        XCTAssertEqual(1, addedTasks.count)
        XCTAssertEqual(reaction.data(), testTask.reaction.apply)
        XCTAssertEqual(Data(), testTask.reaction.withdraw)
        XCTAssertEqual(expectedThreemaIdentity.string, testTask.receiverIdentity)
    }
    
    /// Situation:
    /// Local support: Phase 2
    /// Remote support: Phase 1 or 2
    /// Action: Withdraw
    /// Mapping: None
    func testWithdrawReactionNoMappingYesLocalYesRemote() async throws {
        let expectedThreemaIdentity = ThreemaIdentity("ECHOECHO")
        let expectedMessageID = MockData.generateMessageID()
        let expectedReadDate = Date()
        let reaction = Emoji.abacus
        
        let message = dbPreparer.save {
            let contactEntity = dbPreparer.createContact(identity: expectedThreemaIdentity.string)
            contactEntity.featureMask = 2024

            let conversation = dbPreparer.createConversation(contactEntity: contactEntity)
            
            let message = dbPreparer.createTextMessage(
                conversation: conversation,
                id: expectedMessageID,
                isOwn: false,
                readDate: expectedReadDate,
                sender: contactEntity,
                remoteSentDate: Date()
            )
            
            let _ = MessageReactionEntity(
                context: dbMainCnx.current,
                reaction: reaction.rawValue,
                message: message
            )
            
            return message
        }
        
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.sendEmojiReactions = true
        
        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: userSettingsMock,
            groupManager: GroupManagerMock(),
            taskManager: taskManagerMock,
            entityManager: EntityManager(databaseContext: dbMainCnx)
        )
        
        let result = try await messageSender.sendReaction(
            to: message.objectID,
            reaction: EmojiVariant(base: reaction, skintone: nil)
        )
        
        let addedTasks = taskManagerMock.addedTasks.filter { task in
            guard task is TaskDefinitionSendReactionMessage else {
                return false
            }
            return true
        }
        
        let testTask = try XCTUnwrap(addedTasks.first as? TaskDefinitionSendReactionMessage)
        
        XCTAssertEqual(result, .success)
        XCTAssertFalse(taskManagerMock.addedTasks.isEmpty)
        XCTAssertEqual(1, addedTasks.count)
        XCTAssertEqual(Data(), testTask.reaction.apply)
        XCTAssertEqual(reaction.data(), testTask.reaction.withdraw)
        XCTAssertEqual(expectedThreemaIdentity.string, testTask.receiverIdentity)
    }
    
    /// Situation:
    /// Local support: Phase 1 or 2
    /// Remote support: All legacy
    /// Action: Apply
    /// Mapping: None
    func testApplyReactionNoMappingYesLocalNoneRemote() async throws {
        let membersWithoutCreator = ["MEMBER01", "MEMBER02"]
        let expectedGroupID = MockData.generateGroupID()
        let expectedMessageID = MockData.generateMessageID()
        
        let reaction = Emoji.abacus
        
        let myIdentityStoreMock = MyIdentityStoreMock()
        let userSettingMock = UserSettingsMock()
        userSettingMock.sendEmojiReactions = true
        
        let (message, group) = dbPreparer.save {
            let members = membersWithoutCreator.map { identityString in
                let contactEntity = dbPreparer.createContact(identity: identityString)
                contactEntity.featureMask = 1
                return contactEntity
            }
            
            let groupEntity = dbPreparer.createGroupEntity(
                groupID: expectedGroupID,
                groupCreator: nil
            )
            
            let conversation = dbPreparer.createConversation(groupID: expectedGroupID) { conversation in
                conversation.groupMyIdentity = myIdentityStoreMock.identity
                conversation.members?.formUnion(members)
            }
            
            let group = Group(
                myIdentityStore: myIdentityStoreMock,
                userSettings: userSettingMock,
                groupEntity: groupEntity,
                conversation: conversation,
                lastSyncRequest: nil
            )
            
            let message = dbPreparer.createTextMessage(
                conversation: conversation,
                id: expectedMessageID,
                isOwn: false,
                sender: members.first,
                remoteSentDate: Date()
            )
            
            return (message, group)
        }
        
        let groupManager = GroupManagerMock()
        groupManager.getGroupReturns = [group]
    
        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingMock,
            groupManager: groupManager,
            taskManager: taskManagerMock,
            entityManager: entityManager
        )
        
        let result = try await messageSender.sendReaction(
            to: message.objectID,
            reaction: EmojiVariant(base: reaction, skintone: nil)
        )
        
        XCTAssertEqual(result, .noSupportRemoteGroup)
        XCTAssertTrue(taskManagerMock.addedTasks.isEmpty)
    }
    
    /// Situation:
    /// Local support: Phase 1 or 2
    /// Remote support: All legacy
    /// Action: Apply
    /// Mapping: Success
    func testApplyReactionMappingYesLocalNoneRemote() async throws {
        let membersWithoutCreator = ["MEMBER01", "MEMBER02"]
        let expectedGroupID = MockData.generateGroupID()
        let expectedMessageID = MockData.generateMessageID()
        
        let reaction = Emoji.thumbsUpSign
        
        let myIdentityStoreMock = MyIdentityStoreMock()
        let userSettingMock = UserSettingsMock()
        userSettingMock.sendEmojiReactions = true
        
        let (message, group) = dbPreparer.save {
            let members = membersWithoutCreator.map { identityString in
                let contactEntity = dbPreparer.createContact(identity: identityString)
                contactEntity.featureMask = 1
                return contactEntity
            }
            
            let groupEntity = dbPreparer.createGroupEntity(
                groupID: expectedGroupID,
                groupCreator: nil
            )
            let conversation = dbPreparer.createConversation(groupID: expectedGroupID) { conversation in
                conversation.groupMyIdentity = myIdentityStoreMock.identity
                conversation.members?.formUnion(members)
            }
            let group = Group(
                myIdentityStore: myIdentityStoreMock,
                userSettings: userSettingMock,
                groupEntity: groupEntity,
                conversation: conversation,
                lastSyncRequest: nil
            )
            
            let message = dbPreparer.createTextMessage(
                conversation: conversation,
                id: expectedMessageID,
                isOwn: false,
                sender: members.first,
                remoteSentDate: Date()
            )
            
            return (message, group)
        }
                
        let groupManager = GroupManagerMock()
        groupManager.getGroupReturns = [group]
        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingMock,
            groupManager: groupManager,
            taskManager: taskManagerMock,
            entityManager: entityManager
        )
        
        let result = try await messageSender.sendReaction(
            to: message.objectID,
            reaction: EmojiVariant(base: reaction, skintone: nil)
        )
        
        let addedTasks = taskManagerMock.addedTasks.filter { task in
            guard task is TaskDefinitionSendGroupDeliveryReceiptsMessage else {
                return false
            }
            return true
        }
        
        let testTask = try XCTUnwrap(addedTasks.first as? TaskDefinitionSendGroupDeliveryReceiptsMessage)
       
        XCTAssertFalse(taskManagerMock.addedTasks.isEmpty)
        XCTAssertEqual(1, addedTasks.count)
        XCTAssertEqual(ReceiptType.ack, testTask.receiptType)
        
        XCTAssertEqual(result, .success)
    }
    
    /// Situation:
    /// Local support: Phase 1 or 2
    /// Remote support: Some legacy, some phase 1 or 2
    /// Action: Apply
    /// Mapping: None
    func testApplyReactionNoMappingYesLocalSomeRemote() async throws {
        let expectedGroupID = MockData.generateGroupID()
        let expectedMessageID = MockData.generateMessageID()
        
        let notSupportingMemberID = "MEMBER01"
        let supportingMemberID = "MEMBER02"
        
        let reaction = Emoji.abacus
        
        let myIdentityStoreMock = MyIdentityStoreMock()
        let userSettingMock = UserSettingsMock()
        userSettingMock.sendEmojiReactions = true
        
        let (message, _) = dbPreparer.save {
            let contactEntity1 = dbPreparer.createContact(identity: notSupportingMemberID)
            contactEntity1.featureMask = 1
            
            let contactEntity2 = dbPreparer.createContact(identity: supportingMemberID)
            contactEntity2.featureMask = 2024
            
            let members = [contactEntity1, contactEntity2]
            
            let groupEntity = dbPreparer.createGroupEntity(
                groupID: expectedGroupID,
                groupCreator: nil
            )
            let conversation = dbPreparer.createConversation(groupID: expectedGroupID) { conversation in
                conversation.groupMyIdentity = myIdentityStoreMock.identity
                conversation.members?.formUnion(members)
            }
            let group = Group(
                myIdentityStore: myIdentityStoreMock,
                userSettings: userSettingMock,
                groupEntity: groupEntity,
                conversation: conversation,
                lastSyncRequest: nil
            )
            let message = dbPreparer.createTextMessage(
                conversation: conversation,
                id: expectedMessageID,
                isOwn: false,
                sender: members.first,
                remoteSentDate: Date()
            )
            
            return (message, group)
        }
        
        let groupManager = GroupManager(
            myIdentityStoreMock,
            ContactStoreMock(),
            taskManagerMock,
            userSettingMock,
            entityManager,
            GroupPhotoSenderMock()
        )
    
        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingMock,
            groupManager: groupManager,
            taskManager: taskManagerMock,
            entityManager: entityManager
        )
        
        let result = try await messageSender.sendReaction(
            to: message.objectID,
            reaction: EmojiVariant(base: reaction, skintone: nil)
        )
        
        let addedTasks = taskManagerMock.addedTasks.filter { task in
            guard task is TaskDefinitionSendReactionMessage else {
                return false
            }
            return true
        }
        
        let testTask = try XCTUnwrap(addedTasks.first as? TaskDefinitionSendReactionMessage)
        XCTAssertEqual(result, .partialSupportRemoteGroup)
        XCTAssertFalse(taskManagerMock.addedTasks.isEmpty)
        XCTAssertEqual(1, addedTasks.count)
        XCTAssertEqual(reaction.data(), testTask.reaction.apply)
        XCTAssertEqual(Data(), testTask.reaction.withdraw)
        let receivingGroupMembers = try XCTUnwrap(testTask.receivingGroupMembers)
        XCTAssertTrue(receivingGroupMembers.contains(supportingMemberID))
        XCTAssertFalse(receivingGroupMembers.contains(notSupportingMemberID))
    }
    
    /// Situation:
    /// Local support: Phase 1 or 2
    /// Remote support: Some legacy, some phase 1 or 2
    /// Action: Apply
    /// Mapping: Success
    func testApplyReactionMappingYesLocalSomeRemote() async throws {
        let expectedGroupID = MockData.generateGroupID()
        let expectedMessageID = MockData.generateMessageID()
       
        let notSupportingMemberID = "MEMBER01"
        let supportingMemberID = "MEMBER02"
        
        let reaction = Emoji.thumbsUpSign
        
        let myIdentityStoreMock = MyIdentityStoreMock()
        let userSettingMock = UserSettingsMock()
        userSettingMock.sendEmojiReactions = true
        
        let (message, group) = dbPreparer.save {
            let contactEntity1 = dbPreparer.createContact(identity: notSupportingMemberID)
            contactEntity1.featureMask = 1
            
            let contactEntity2 = dbPreparer.createContact(identity: supportingMemberID)
            contactEntity2.featureMask = 2024
            
            let members = [contactEntity1, contactEntity2]
            
            let groupEntity = dbPreparer.createGroupEntity(
                groupID: expectedGroupID,
                groupCreator: nil
            )
            let conversation = dbPreparer.createConversation(groupID: expectedGroupID) { conversation in
                conversation.groupMyIdentity = myIdentityStoreMock.identity
                conversation.members?.formUnion(members)
            }
            let group = Group(
                myIdentityStore: myIdentityStoreMock,
                userSettings: userSettingMock,
                groupEntity: groupEntity,
                conversation: conversation,
                lastSyncRequest: nil
            )
            
            let message = dbPreparer.createTextMessage(
                conversation: conversation,
                id: expectedMessageID,
                isOwn: false,
                sender: members.first,
                remoteSentDate: Date()
            )
            return (message, group)
        }
        
        let groupManager = GroupManagerMock()
        groupManager.getGroupReturns = [group]
    
        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingMock,
            groupManager: groupManager,
            taskManager: taskManagerMock,
            entityManager: entityManager
        )
        
        let result = try await messageSender.sendReaction(
            to: message.objectID,
            reaction: EmojiVariant(base: reaction, skintone: nil)
        )
        
        let addedTasks = taskManagerMock.addedTasks.filter { task in
            guard task is TaskDefinitionSendReactionMessage || task is TaskDefinitionSendGroupDeliveryReceiptsMessage
            else {
                return false
            }
            return true
        }
        
        XCTAssertEqual(result, .success)
        XCTAssertFalse(taskManagerMock.addedTasks.isEmpty)
        XCTAssertEqual(2, addedTasks.count)
        
        let reactionTask = addedTasks.first { task in
            task is TaskDefinitionSendReactionMessage
        }
        let unwrappedReactionTask = try XCTUnwrap(reactionTask as? TaskDefinitionSendReactionMessage)
        XCTAssertEqual(reaction.data(), unwrappedReactionTask.reaction.apply)
        XCTAssertEqual(Data(), unwrappedReactionTask.reaction.withdraw)
        let receivingReactionTaskGroupMembers = try XCTUnwrap(unwrappedReactionTask.receivingGroupMembers)
        XCTAssertTrue(receivingReactionTaskGroupMembers.contains(supportingMemberID))
        XCTAssertFalse(receivingReactionTaskGroupMembers.contains(notSupportingMemberID))
        
        let legacyTask = addedTasks.first { task in
            task is TaskDefinitionSendGroupDeliveryReceiptsMessage
        }
        let unwrappedLegacyTask = try XCTUnwrap(legacyTask as? TaskDefinitionSendGroupDeliveryReceiptsMessage)
        XCTAssertEqual(ReceiptType.ack, unwrappedLegacyTask.receiptType)
        let receivingLegacyTaskGroupMembers = try XCTUnwrap(unwrappedLegacyTask.toMembers)
        XCTAssertTrue(receivingLegacyTaskGroupMembers.contains(notSupportingMemberID))
        XCTAssertFalse(receivingLegacyTaskGroupMembers.contains(supportingMemberID))
    }

    /// Situation:
    /// Local support: Phase 1 or 2
    /// Remote support: Phase 1 or 2
    /// Action: Apply
    /// Mapping: None
    func testApplyReactionNoMappingYesLocalAllRemote() async throws {
        let expectedGroupID = MockData.generateGroupID()
        let expectedMessageID = MockData.generateMessageID()
        
        let membersWithoutCreator = ["MEMBER01", "MEMBER02"]
        
        let reaction = Emoji.abacus
        
        let myIdentityStoreMock = MyIdentityStoreMock()
        let userSettingMock = UserSettingsMock()
        userSettingMock.sendEmojiReactions = true
        
        let (message, group) = dbPreparer.save {
            let members = membersWithoutCreator.map { identityString in
                let contactEntity = dbPreparer.createContact(identity: identityString)
                contactEntity.featureMask = 2024
                return contactEntity
            }
            
            let groupEntity = dbPreparer.createGroupEntity(
                groupID: expectedGroupID,
                groupCreator: nil
            )
            let conversation = dbPreparer.createConversation(groupID: expectedGroupID) { conversation in
                conversation.groupMyIdentity = myIdentityStoreMock.identity
                conversation.members?.formUnion(members)
            }
            let group = Group(
                myIdentityStore: myIdentityStoreMock,
                userSettings: userSettingMock,
                groupEntity: groupEntity,
                conversation: conversation,
                lastSyncRequest: nil
            )
            
            let message = dbPreparer.createTextMessage(
                conversation: conversation,
                id: expectedMessageID,
                isOwn: false,
                sender: members.first,
                remoteSentDate: Date()
            )
            return (message, group)
        }
        
        let groupManager = GroupManagerMock()
        groupManager.getGroupReturns = [group]
    
        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingMock,
            groupManager: groupManager,
            taskManager: taskManagerMock,
            entityManager: entityManager
        )
        
        let result = try await messageSender.sendReaction(
            to: message.objectID,
            reaction: EmojiVariant(base: reaction, skintone: nil)
        )
        
        let addedTasks = taskManagerMock.addedTasks.filter { task in
            guard task is TaskDefinitionSendReactionMessage else {
                return false
            }
            return true
        }
        
        let testTask = try XCTUnwrap(addedTasks.first as? TaskDefinitionSendReactionMessage)
        XCTAssertEqual(result, .success)
        XCTAssertFalse(taskManagerMock.addedTasks.isEmpty)
        XCTAssertEqual(1, addedTasks.count)
        XCTAssertEqual(reaction.data(), testTask.reaction.apply)
        XCTAssertEqual(Data(), testTask.reaction.withdraw)
    }
    
    /// Situation:
    /// Local support: Phase 1 or 2
    /// Remote support: Phase 1 or 2
    /// Action: Apply
    /// Mapping: Success
    func testApplyReactionMappingYesLocalAllRemote() async throws {
        let expectedGroupID = MockData.generateGroupID()
        let expectedMessageID = MockData.generateMessageID()
       
        let membersWithoutCreator = ["MEMBER01", "MEMBER02"]
        
        let reaction = Emoji.thumbsUpSign
        
        let myIdentityStoreMock = MyIdentityStoreMock()
        let userSettingMock = UserSettingsMock()
        userSettingMock.sendEmojiReactions = true
        
        let (message, group) = dbPreparer.save {
            let members = membersWithoutCreator.map { identityString in
                let contactEntity = dbPreparer.createContact(identity: identityString)
                contactEntity.featureMask = 2024
                return contactEntity
            }
            
            let groupEntity = dbPreparer.createGroupEntity(
                groupID: expectedGroupID,
                groupCreator: nil
            )
            let conversation = dbPreparer.createConversation(groupID: expectedGroupID) { conversation in
                conversation.groupMyIdentity = myIdentityStoreMock.identity
                conversation.members?.formUnion(members)
            }
            let group = Group(
                myIdentityStore: myIdentityStoreMock,
                userSettings: userSettingMock,
                groupEntity: groupEntity,
                conversation: conversation,
                lastSyncRequest: nil
            )
            
            let message = dbPreparer.createTextMessage(
                conversation: conversation,
                id: expectedMessageID,
                isOwn: false,
                sender: members.first,
                remoteSentDate: Date()
            )
            return (message, group)
        }
        
        let groupManager = GroupManagerMock()
        groupManager.getGroupReturns = [group]
    
        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingMock,
            groupManager: groupManager,
            taskManager: taskManagerMock,
            entityManager: entityManager
        )
        
        let result = try await messageSender.sendReaction(
            to: message.objectID,
            reaction: EmojiVariant(base: reaction, skintone: nil)
        )
        
        let addedTasks = taskManagerMock.addedTasks.filter { task in
            guard task is TaskDefinitionSendReactionMessage else {
                return false
            }
            return true
        }
        
        let testTask = try XCTUnwrap(addedTasks.first as? TaskDefinitionSendReactionMessage)
        XCTAssertEqual(result, .success)
        XCTAssertFalse(taskManagerMock.addedTasks.isEmpty)
        XCTAssertEqual(1, addedTasks.count)
        XCTAssertEqual(reaction.data(), testTask.reaction.apply)
        XCTAssertEqual(Data(), testTask.reaction.withdraw)
    }
    
    /// Situation:
    /// Local support: Phase 2
    /// Remote support: NoteGroup
    /// Action: Apply
    /// Mapping: Success
    func testApplyReactionMappingYesLocalNoteGroup() async throws {
        let expectedGroupID = MockData.generateGroupID()
        let expectedMessageID = MockData.generateMessageID()
               
        let reaction = Emoji.adult
        
        let myIdentityStoreMock = MyIdentityStoreMock()
        let userSettingMock = UserSettingsMock()
        userSettingMock.sendEmojiReactions = true
        
        let (message, group) = dbPreparer.save {
            let groupEntity = dbPreparer.createGroupEntity(
                groupID: expectedGroupID,
                groupCreator: nil
            )
            let conversation = dbPreparer.createConversation(groupID: expectedGroupID) { conversation in
                conversation.groupMyIdentity = myIdentityStoreMock.identity
            }
            let group = Group(
                myIdentityStore: myIdentityStoreMock,
                userSettings: userSettingMock,
                groupEntity: groupEntity,
                conversation: conversation,
                lastSyncRequest: nil
            )
            
            let message = dbPreparer.createTextMessage(
                conversation: conversation,
                id: expectedMessageID,
                isOwn: false,
                sender: nil,
                remoteSentDate: Date()
            )
            return (message, group)
        }
        
        let groupManager = GroupManagerMock()
        groupManager.getGroupReturns = [group]
    
        let messageSender = MessageSender(
            serverConnector: ServerConnectorMock(),
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingMock,
            groupManager: groupManager,
            taskManager: taskManagerMock,
            entityManager: entityManager
        )
        
        let result = try await messageSender.sendReaction(
            to: message.objectID,
            reaction: EmojiVariant(base: reaction, skintone: nil)
        )
        
        let addedTasks = taskManagerMock.addedTasks.filter { task in
            guard task is TaskDefinitionSendReactionMessage else {
                return false
            }
            return true
        }
        
        let testTask = try XCTUnwrap(addedTasks.first as? TaskDefinitionSendReactionMessage)
        XCTAssertEqual(result, .success)
        XCTAssertFalse(taskManagerMock.addedTasks.isEmpty)
        XCTAssertEqual(1, addedTasks.count)
        XCTAssertEqual(reaction.data(), testTask.reaction.apply)
        XCTAssertEqual(Data(), testTask.reaction.withdraw)
    }
}
