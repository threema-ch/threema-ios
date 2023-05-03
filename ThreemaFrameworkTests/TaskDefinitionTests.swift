//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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

class TaskDefinitionTests: XCTestCase {
    private var dbMainCnx: DatabaseContext!
    private var dbPreparer: DatabasePreparer!
    private var frameworkInjectorMock: FrameworkInjectorProtocol!

    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
        
        let (_, mainCnx, backgroundCnx) = DatabasePersistentContext.devNullContext()
        dbMainCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        dbPreparer = DatabasePreparer(context: mainCnx)
        
        frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(
                databaseContext:
                DatabaseContext(
                    mainContext: mainCnx,
                    backgroundContext: backgroundCnx
                )
            ),
            entityManager: EntityManager(databaseContext: dbMainCnx)
        )
    }

    func testTaskDefinitionEncodeDecode() throws {
        let task = TaskDefinition(isPersistent: true)

        let encoder = JSONEncoder()
        let data = try encoder.encode(task)
        print(String(data: data, encoding: .utf8)!)

        let decoder = JSONDecoder()
        let result = try decoder.decode(TaskDefinition.self, from: data)
        XCTAssertTrue(result.isPersistent)
        XCTAssertFalse(result.retry)
    }

    func testTaskDefinitionGroupDissolveEncodeDecode() throws {
        let expectedGroupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
        let expectedGroupCreator = "CREATOR01"
        let expectedMember = "MEMBER01"

        var group: Group!
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: expectedGroupCreator,
                verificationLevel: 0
            )
            let conversation = dbPreparer
                .createConversation(marked: false, typing: false, unreadMessageCount: 0) { conversation in
                    conversation.contact = contact
                }
            let groupEntity = dbPreparer.createGroupEntity(groupID: expectedGroupID, groupCreator: expectedGroupCreator)
            group = Group(
                myIdentityStore: MyIdentityStoreMock(),
                userSettings: UserSettingsMock(),
                groupEntity: groupEntity,
                conversation: conversation,
                lastSyncRequest: nil
            )
        }

        let task = TaskDefinitionGroupDissolve(group: group)
        task.toMembers = [expectedMember]

        let encoder = JSONEncoder()
        let data = try encoder.encode(task)
        print(String(data: data, encoding: .utf8)!)

        let decoder = JSONDecoder()
        let result = try decoder.decode(TaskDefinitionGroupDissolve.self, from: data)
        XCTAssertEqual(expectedGroupID, result.groupID)
        XCTAssertEqual(expectedGroupCreator, result.groupCreatorIdentity)
        XCTAssertEqual(1, result.toMembers.count)
        XCTAssertTrue(result.toMembers.contains(expectedMember))
    }

    func testTaskDefinitionSendIncomingMessageUpdateEncodeDecode() throws {
        let messageID = BytesUtility.generateRandomBytes(length: Int(8))!
        let messageReadDate = Date()
        // swiftformat:disable:next all
        var conversationID = D2d_ConversationId()
        conversationID.contact = "SENDER01"

        let task = TaskDefinitionSendIncomingMessageUpdate(
            messageIDs: [messageID],
            messageReadDates: [messageReadDate],
            conversationID: conversationID
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(task)
        print(String(data: data, encoding: .utf8)!)

        let decoder = JSONDecoder()
        let result = try decoder.decode(TaskDefinitionSendIncomingMessageUpdate.self, from: data)
        XCTAssertTrue(result.messageIDs.contains(messageID))
        XCTAssertTrue(result.messageReadDates.contains(messageReadDate))
        XCTAssertEqual("SENDER01", result.conversationID.contact)
        XCTAssertTrue(result.isPersistent)
        XCTAssertFalse(result.retry)
    }

    func testTaskDefinitionSendMessageEncodeDecode() throws {
        let task = TaskDefinitionSendMessage(sendContactProfilePicture: false)

        let encoder = JSONEncoder()
        let data = try encoder.encode(task)
        print(String(data: data, encoding: .utf8)!)

        let decoder = JSONDecoder()
        let result = try decoder.decode(TaskDefinitionSendMessage.self, from: data)
        XCTAssertFalse(result.sendContactProfilePicture ?? true)
        XCTAssertTrue(result.isPersistent)
        XCTAssertFalse(result.retry)
    }

    func testTaskDefinitionSendBallotVoteMessageEncodeDecode() throws {
        let expectedBallotID = BytesUtility.generateRandomBytes(length: Int(8))!

        var ballot: Ballot!
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: "ECHOECHO",
                verificationLevel: 0
            )
            let conversation = dbPreparer
                .createConversation(marked: false, typing: false, unreadMessageCount: 0) { conversation in
                    conversation.contact = contact
                }
            ballot = dbPreparer.createBallotMessage(conversation: conversation, ballotID: expectedBallotID)
        }

        let task = TaskDefinitionSendBallotVoteMessage(ballot: ballot, group: nil, sendContactProfilePicture: true)

        let encoder = JSONEncoder()
        let data = try encoder.encode(task)
        print(String(data: data, encoding: .utf8)!)

        let decoder = JSONDecoder()
        let result = try decoder.decode(TaskDefinitionSendBallotVoteMessage.self, from: data)
        XCTAssertEqual(expectedBallotID, result.ballotID)
        XCTAssertFalse(result.isGroupMessage)
        XCTAssertTrue(result.sendContactProfilePicture ?? false)
        XCTAssertTrue(result.isPersistent)
        XCTAssertFalse(result.retry)
    }

    func testTaskDefinitionSendBallotVoteMessageCreate() {
        let expectedBallotID = BytesUtility.generateRandomBytes(length: 8)!

        var ballot: Ballot!
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: "ECHOECHO",
                verificationLevel: 0
            )
            let conversation = dbPreparer
                .createConversation(marked: false, typing: false, unreadMessageCount: 0) { conversation in
                    conversation.contact = contact
                }
            ballot = dbPreparer.createBallotMessage(conversation: conversation, ballotID: expectedBallotID)
        }

        let task = TaskDefinitionSendBallotVoteMessage(ballot: ballot, group: nil, sendContactProfilePicture: true)

        let result = task.create(frameworkInjector: frameworkInjectorMock)

        if let result = result.taskDefinition as? TaskDefinitionSendBallotVoteMessage {
            XCTAssertFalse(result.isGroupMessage)
            XCTAssertEqual(expectedBallotID, result.ballotID)
            XCTAssertTrue(result.isPersistent)
            XCTAssertFalse(result.retry)
        }
        else {
            XCTFail()
        }
    }

    func testTaskDefinitionSendBaseMessageEncodeDecode() throws {
        let expectedGroupID = BytesUtility.generateRandomBytes(length: 8)!
        let expectedGroupCreator = "ADMIN007"
        let expectedMessageID = BytesUtility.generateRandomBytes(length: 8)!

        var message: TextMessage!
        var group: Group!
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: expectedGroupCreator,
                verificationLevel: 0
            )
            let conversation = dbPreparer
                .createConversation(marked: false, typing: false, unreadMessageCount: 0) { conversation in
                    conversation.contact = contact
                }
            let groupEntity = dbPreparer.createGroupEntity(groupID: expectedGroupID, groupCreator: expectedGroupCreator)
            group = Group(
                myIdentityStore: MyIdentityStoreMock(),
                userSettings: UserSettingsMock(),
                groupEntity: groupEntity,
                conversation: conversation,
                lastSyncRequest: nil
            )
            message = dbPreparer.createTextMessage(
                conversation: conversation,
                text: "Test text",
                date: Date(),
                delivered: false,
                id: expectedMessageID,
                isOwn: true,
                read: true,
                sent: false,
                userack: false,
                sender: contact,
                remoteSentDate: nil
            )
        }

        let task = TaskDefinitionSendBaseMessage(
            message: message,
            group: group,
            sendContactProfilePicture: true
        )
        task.messageAlreadySentTo.append(message.sender!.identity)

        let encoder = JSONEncoder()
        let data = try encoder.encode(task)
        print(String(data: data, encoding: .utf8)!)

        let decoder = JSONDecoder()
        let result = try decoder.decode(TaskDefinitionSendBaseMessage.self, from: data)
        XCTAssertTrue(result.isGroupMessage)
        XCTAssertEqual(expectedMessageID, result.messageID)
        XCTAssertEqual(expectedGroupID, result.groupID)
        XCTAssertEqual(expectedGroupCreator, result.groupCreatorIdentity)
        XCTAssertTrue(result.sendContactProfilePicture ?? false)
        XCTAssertTrue(result.isPersistent)
        XCTAssertFalse(result.retry)
    }

    func testTaskDefinitionSendBaseMessageCreate() {
        let expectedGroupID = BytesUtility.generateRandomBytes(length: 8)!
        let expectedGroupCreator = "ADMIN007"
        let expectedMessageID = BytesUtility.generateRandomBytes(length: 8)!
        let expectedMessageText = "Test text"

        var message: TextMessage!
        var group: Group!
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: expectedGroupCreator,
                verificationLevel: 0
            )
            let conversation = dbPreparer
                .createConversation(marked: false, typing: false, unreadMessageCount: 0) { conversation in
                    conversation.contact = contact
                }
            let groupEntity = dbPreparer.createGroupEntity(groupID: expectedGroupID, groupCreator: expectedGroupCreator)
            group = Group(
                myIdentityStore: MyIdentityStoreMock(),
                userSettings: UserSettingsMock(),
                groupEntity: groupEntity,
                conversation: conversation,
                lastSyncRequest: nil
            )
            message = dbPreparer.createTextMessage(
                conversation: conversation,
                text: expectedMessageText,
                date: Date(),
                delivered: false,
                id: expectedMessageID,
                isOwn: true,
                read: true,
                sent: false,
                userack: false,
                sender: contact,
                remoteSentDate: nil
            )
        }

        let task = TaskDefinitionSendBaseMessage(
            message: message,
            group: group,
            sendContactProfilePicture: true
        )

        let result = task.create(frameworkInjector: frameworkInjectorMock)

        XCTAssertNotNil(result)
        if let result = result.taskDefinition as? TaskDefinitionSendBaseMessage {
            XCTAssertTrue(result.isGroupMessage)
            XCTAssertEqual(expectedMessageID, result.messageID)
            XCTAssertEqual(expectedGroupID, try XCTUnwrap(result.groupID))
            XCTAssertEqual(expectedGroupCreator, result.groupCreatorIdentity)
            XCTAssertTrue(result.isPersistent)
            XCTAssertFalse(result.retry)
        }
        else {
            XCTFail()
        }
    }

    func testTaskDefinitionSendLocationMessageEncodeDecode() throws {
        let expectedGroupID = BytesUtility.generateRandomBytes(length: 8)!
        let expectedGroupCreator = "ADMIN007"
        let expectedMessageID = BytesUtility.generateRandomBytes(length: 8)!
        let expectedMessagePoiAddress = "poi address"

        var message: LocationMessage!
        var group: Group!
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: expectedGroupCreator,
                verificationLevel: 0
            )
            let conversation = dbPreparer
                .createConversation(marked: false, typing: false, unreadMessageCount: 0) { conversation in
                    conversation.contact = contact
                }
            let groupEntity = dbPreparer.createGroupEntity(groupID: expectedGroupID, groupCreator: expectedGroupCreator)
            group = Group(
                myIdentityStore: MyIdentityStoreMock(),
                userSettings: UserSettingsMock(),
                groupEntity: groupEntity,
                conversation: conversation,
                lastSyncRequest: nil
            )
            message = dbPreparer.createLocationMessage(
                conversation: conversation,
                accuracy: 1.0,
                latitude: 1.0,
                longitude: 1.0,
                poiName: "poi name",
                id: expectedMessageID,
                sender: contact
            )
        }

        let task = TaskDefinitionSendLocationMessage(
            poiAddress: expectedMessagePoiAddress,
            message: message,
            group: group,
            sendContactProfilePicture: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(task)
        print(String(data: data, encoding: .utf8)!)

        let decoder = JSONDecoder()
        let result = try decoder.decode(TaskDefinitionSendLocationMessage.self, from: data)
        XCTAssertTrue(result.isGroupMessage)
        XCTAssertEqual(expectedMessageID, result.messageID)
        XCTAssertEqual(expectedGroupID, result.groupID)
        XCTAssertEqual(expectedGroupCreator, result.groupCreatorIdentity)
        XCTAssertEqual(expectedMessagePoiAddress, result.poiAddress)
        XCTAssertTrue(result.sendContactProfilePicture ?? false)
        XCTAssertTrue(result.isPersistent)
        XCTAssertFalse(result.retry)
    }

    func testTaskDefinitionSendVideoMessageEncodeDecode() throws {
        let expectedGroupID = BytesUtility.generateRandomBytes(length: 8)!
        let expectedGroupCreator = "ADMIN007"
        let expectedMessageID = BytesUtility.generateRandomBytes(length: 8)!
        let expectedThumbnailBlobID = BytesUtility.generateRandomBytes(length: 8)!
        let expectedThumbnailSize = NSNumber(value: 1.0)

        var message: VideoMessageEntity!
        var group: Group!
        dbPreparer.save {
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: expectedGroupCreator,
                verificationLevel: 0
            )
            let conversation = dbPreparer
                .createConversation(marked: false, typing: false, unreadMessageCount: 0) { conversation in
                    conversation.contact = contact
                }
            let groupEntity = dbPreparer.createGroupEntity(groupID: expectedGroupID, groupCreator: expectedGroupCreator)
            group = Group(
                myIdentityStore: MyIdentityStoreMock(),
                userSettings: UserSettingsMock(),
                groupEntity: groupEntity,
                conversation: conversation,
                lastSyncRequest: nil
            )
            let thumbnail = dbPreparer.createImageData(data: Data([0]), height: 1, width: 1)
            let videoData = dbPreparer.createVideoData(data: Data([1]))
            message = dbPreparer.createVideoMessageEntity(
                conversation: conversation,
                thumbnail: thumbnail,
                videoData: videoData,
                date: Date(),
                complete: { videoMessage in
                    videoMessage.delivered = 1
                    videoMessage.id = expectedMessageID
                    videoMessage.isOwn = true
                    videoMessage.read = true
                    videoMessage.sent = true
                    videoMessage.userack = false
                    videoMessage.duration = 10
                    videoMessage.remoteSentDate = Date()
                }
            )
        }

        let task = TaskDefinitionSendVideoMessage(
            thumbnailBlobID: expectedThumbnailBlobID,
            thumbnailSize: expectedThumbnailSize,
            message: message,
            group: group,
            sendContactProfilePicture: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(task)

        let decoder = JSONDecoder()
        let result = try decoder.decode(TaskDefinitionSendVideoMessage.self, from: data)
        XCTAssertTrue(result.isGroupMessage)
        XCTAssertEqual(expectedMessageID, result.messageID)
        XCTAssertEqual(result.groupID, expectedGroupID)
        XCTAssertEqual(result.groupCreatorIdentity, expectedGroupCreator)
        XCTAssertEqual(result.thumbnailBlobID, expectedThumbnailBlobID)
        XCTAssertEqual(result.thumbnailSize, expectedThumbnailSize)
        XCTAssertTrue(result.sendContactProfilePicture ?? false)
        XCTAssertTrue(result.isPersistent)
        XCTAssertFalse(result.retry)
    }

    func testTaskDefinitionSendGroupCreateMessageEncodeDecode() throws {
        let expectedGroupID = BytesUtility.generateRandomBytes(length: 8)!
        let expectedGroupCreator = "CREATOR01"
        let expectedToMembers = ["MEMBER04", "MEMBER05"]
        let expectedRemovedMembers = ["MEMBER03", "MEMBER04"]
        let expectedMembers = Set(["MEMBER01", "MEMBER02"])

        let task = TaskDefinitionSendGroupCreateMessage(
            group: nil,
            to: expectedToMembers,
            removed: expectedRemovedMembers,
            members: expectedMembers,
            sendContactProfilePicture: false
        )
        
        task.groupID = expectedGroupID
        task.groupCreatorIdentity = expectedGroupCreator

        let encoder = JSONEncoder()
        let data = try XCTUnwrap(encoder.encode(task))
        print(String(data: data, encoding: .utf8)!)
        
        let decoder = JSONDecoder()
        let result = try XCTUnwrap(decoder.decode(TaskDefinitionSendGroupCreateMessage.self, from: data))
        let groupID = try XCTUnwrap(result.groupID)
        XCTAssertTrue(expectedGroupID.elementsEqual(groupID))
        XCTAssertEqual(expectedGroupCreator, result.groupCreatorIdentity)
        XCTAssertFalse(result.sendContactProfilePicture ?? true)
        XCTAssertEqual(expectedToMembers, result.toMembers)
        XCTAssertEqual(expectedRemovedMembers, result.removedMembers)
        XCTAssertEqual(expectedMembers, result.members)
        XCTAssertTrue(result.isPersistent)
        XCTAssertFalse(result.retry)
    }

    func testTaskDefinitionSendGroupDeletePhotoMessageEncodeDecode() throws {
        let expectedGroupID = BytesUtility.generateRandomBytes(length: 8)!
        let expectedGroupCreator = "CREATOR01"
        let expectedFromMember = "MEMBER01"
        let expectedToMembers = ["MEMBER03", "MEMBER04"]

        let task = TaskDefinitionSendGroupDeletePhotoMessage(
            group: nil,
            from: expectedFromMember,
            to: expectedToMembers,
            sendContactProfilePicture: false
        )
        
        task.groupID = expectedGroupID
        task.groupCreatorIdentity = expectedGroupCreator
        
        let encoder = JSONEncoder()
        let data = try XCTUnwrap(encoder.encode(task))
        print(String(data: data, encoding: .utf8)!)
        
        let decoder = JSONDecoder()
        let result = try XCTUnwrap(decoder.decode(TaskDefinitionSendGroupDeletePhotoMessage.self, from: data))
        let groupID = try XCTUnwrap(result.groupID)
        XCTAssertTrue(expectedGroupID.elementsEqual(groupID))
        XCTAssertEqual(expectedGroupCreator, result.groupCreatorIdentity)
        XCTAssertFalse(result.sendContactProfilePicture ?? true)
        XCTAssertEqual(expectedFromMember, result.fromMember)
        XCTAssertEqual(expectedToMembers, result.toMembers)
        XCTAssertTrue(result.isPersistent)
        XCTAssertFalse(result.retry)
    }

    func testTaskDefinitionSendGroupLeaveMessageEncodeDecode() throws {
        let expectedGroupID = BytesUtility.generateRandomBytes(length: 8)!
        let expectedGroupCreator = "CREATOR01"
        let expectedFromMember = "MEMBER01"
        let expectedToMembers = ["MEMBER03", "MEMBER04"]
        let expectedHiddenContacts = ["MEMBER04"]

        let task = TaskDefinitionSendGroupLeaveMessage(sendContactProfilePicture: false)
        task.groupID = expectedGroupID
        task.groupCreatorIdentity = expectedGroupCreator
        task.fromMember = expectedFromMember
        task.toMembers = expectedToMembers
        task.hiddenContacts = expectedHiddenContacts

        let encoder = JSONEncoder()
        let data = try encoder.encode(task)
        print(String(data: data, encoding: .utf8)!)

        let decoder = JSONDecoder()
        let result = try decoder.decode(TaskDefinitionSendGroupLeaveMessage.self, from: data)
        XCTAssertEqual(result.groupID, expectedGroupID)
        XCTAssertEqual(expectedGroupCreator, result.groupCreatorIdentity)
        XCTAssertFalse(result.sendContactProfilePicture ?? true)
        XCTAssertEqual(expectedFromMember, result.fromMember)
        XCTAssertEqual(expectedToMembers, result.toMembers)
        XCTAssertEqual(expectedHiddenContacts, result.hiddenContacts)
        XCTAssertTrue(result.isPersistent)
        XCTAssertFalse(result.retry)
    }

    func testTaskDefinitionSendGroupRenameMessageEncodeDecode() throws {
        let expectedGroupID = BytesUtility.generateRandomBytes(length: 8)!
        let expectedGroupCreator = "CREATOR01"
        let expectedFromMember = "MEMBER01"
        let expectedToMembers = ["MEMBER03", "MEMBER04"]
        let expectedNewName = "New Groupname"
        
        let task = TaskDefinitionSendGroupRenameMessage(
            group: nil,
            from: expectedFromMember,
            to: expectedToMembers,
            newName: expectedNewName,
            sendContactProfilePicture: false
        )
        
        task.groupID = expectedGroupID
        task.groupCreatorIdentity = expectedGroupCreator

        let encoder = JSONEncoder()
        let data = try XCTUnwrap(encoder.encode(task))
        
        let decoder = JSONDecoder()
        let result = try XCTUnwrap(decoder.decode(TaskDefinitionSendGroupRenameMessage.self, from: data))
        
        let groupID = try XCTUnwrap(result.groupID)
        XCTAssertTrue(expectedGroupID.elementsEqual(groupID))
        XCTAssertEqual(expectedGroupCreator, result.groupCreatorIdentity)
        XCTAssertFalse(result.sendContactProfilePicture ?? true)
        XCTAssertEqual(expectedFromMember, result.fromMember)
        XCTAssertEqual(expectedToMembers, result.toMembers)
        XCTAssertEqual(expectedNewName, result.name)
        XCTAssertTrue(result.isPersistent)
        XCTAssertFalse(result.retry)
    }

    func testTaskDefinitionSendGroupSetPhotoMessageEncodeDecode() throws {
        let expectedGroupID = BytesUtility.generateRandomBytes(length: 8)!
        let expectedGroupCreator = "CREATOR01"
        let expectedFromMember = "MEMBER01"
        let expectedToMembers = ["MEMBER03", "MEMBER04"]
        let expectedSize: UInt32 = 10
        let expectedBlobID = BytesUtility.generateRandomBytes(length: 8)!
        let expectedEncryptionKey = BytesUtility.generateRandomBytes(length: 8)!
        
        let task = TaskDefinitionSendGroupSetPhotoMessage(
            group: nil,
            from: expectedFromMember,
            to: expectedToMembers,
            size: expectedSize,
            blobID: expectedBlobID,
            encryptionKey: expectedEncryptionKey,
            sendContactProfilePicture: false
        )
        task.groupID = expectedGroupID
        task.groupCreatorIdentity = expectedGroupCreator

        let encoder = JSONEncoder()
        let data = try XCTUnwrap(encoder.encode(task))
        print(String(data: data, encoding: .utf8)!)
        
        let decoder = JSONDecoder()
        let result = try XCTUnwrap(decoder.decode(TaskDefinitionSendGroupSetPhotoMessage.self, from: data))
        
        let groupID = try XCTUnwrap(result.groupID)
        XCTAssertTrue(expectedGroupID.elementsEqual(groupID))
        XCTAssertEqual(expectedGroupCreator, result.groupCreatorIdentity)
        XCTAssertFalse(result.sendContactProfilePicture ?? true)
        XCTAssertEqual(expectedFromMember, result.fromMember)
        XCTAssertEqual(expectedToMembers, result.toMembers)
        XCTAssertEqual(expectedSize, result.size)
        XCTAssertEqual(expectedBlobID, result.blobID)
        XCTAssertEqual(expectedEncryptionKey, result.encryptionKey)
        XCTAssertTrue(result.isPersistent)
        XCTAssertFalse(result.retry)
    }

    func testTaskDefinitionSendAbstractMessageEncodeDecode() throws {
        let expectedMessageID = BytesUtility.generateRandomBytes(length: 8)!
        let expectedText = "Test text"
        let expectedFromIdentity = "FROMID01"
        let expectedToIdentity = "ECHOECHO"
        let expectedDate = Date()

        let abstractMessage = BoxTextMessage()
        abstractMessage.messageID = expectedMessageID
        abstractMessage.text = expectedText
        abstractMessage.fromIdentity = expectedFromIdentity
        abstractMessage.toIdentity = expectedToIdentity
        abstractMessage.date = expectedDate

        let task = TaskDefinitionSendAbstractMessage(message: abstractMessage)

        let encoder = JSONEncoder()
        let data = try encoder.encode(task)

        let decoder = JSONDecoder()
        let result = try decoder.decode(TaskDefinitionSendAbstractMessage.self, from: data)
        if let message = result.message as? BoxTextMessage {
            XCTAssertEqual(expectedMessageID, message.messageID)
            XCTAssertEqual(expectedText, message.text)
            XCTAssertEqual(expectedFromIdentity, message.fromIdentity)
            XCTAssertEqual(expectedToIdentity, message.toIdentity)
            XCTAssertEqual(expectedDate, message.date)
            XCTAssertTrue(result.isPersistent)
            XCTAssertFalse(result.retry)
        }
        else {
            XCTFail()
        }
    }

    func testAbstractMessageEncodeDecodeOverBoxedMessage() {
        let myIdentityStoreMock = MyIdentityStoreMock()

        let expectedMessageID = BytesUtility.generateRandomBytes(length: 8)!
        let expectedText = "Test text"
        let expectedFromIdentity = myIdentityStoreMock.identity
        let expectedToIdentity = "ECHOECHO"
        let expectedDate = Date()
        var contact: ContactEntity!
        dbPreparer.save {
            contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: expectedToIdentity,
                verificationLevel: 0
            )
        }

        let abstractMessage = BoxTextMessage()
        abstractMessage.messageID = expectedMessageID
        abstractMessage.text = expectedText
        abstractMessage.fromIdentity = expectedFromIdentity
        abstractMessage.toIdentity = expectedToIdentity
        abstractMessage.date = expectedDate

        let boxedMessage = abstractMessage.makeBox(
            contact,
            myIdentityStore: myIdentityStoreMock
        )

        let data = NSMutableData()
        let archiver = NSKeyedArchiver(forWritingWith: data)
        archiver.encodeRootObject(boxedMessage!)
        archiver.finishEncoding()

        let unarchiver = NSKeyedUnarchiver(forReadingWith: Data(bytes: data.mutableBytes, count: data.count))
        let result: BoxedMessage? = try? unarchiver.decodeTopLevelObject() as? BoxedMessage

        if let result = result {
            XCTAssertNotNil(result.box)
            XCTAssertTrue(expectedMessageID.elementsEqual(result.messageID))
            XCTAssertEqual(expectedFromIdentity, result.fromIdentity)
            XCTAssertEqual(expectedToIdentity, result.toIdentity)
            XCTAssertEqual(expectedDate, result.date)

            if let decData = myIdentityStoreMock.decryptData(
                result.box,
                withNonce: result.nonce,
                publicKey: contact.publicKey
            ) {
                let paddingLenth: UInt8 = decData.subdata(in: decData.count - 1..<decData.count).convert()
                let msg = MessageDecoder.decode(
                    Int32(decData[0]),
                    body: decData.subdata(in: 1..<decData.count - Int(paddingLenth))
                )

                XCTAssertNotNil(msg)
                if let message = msg as? BoxTextMessage {
                    XCTAssertEqual(expectedText, message.text)
                }
                else {
                    XCTFail()
                }
            }
            else {
                XCTFail()
            }
        }
        else {
            XCTFail()
        }
    }

    func testTaskDefinitionUpdateContactSyncEncodeDecode() throws {
        func generateContact() -> DeltaSyncContact {
            var sContact = Sync_Contact()
            sContact.identity = SwiftUtils.pseudoRandomString(length: 7)
            sContact.identityType = .regular
            sContact.publicKey = BytesUtility.generateRandomBytes(length: 32)!
            sContact.verificationLevel = .serverVerified
            sContact.nickname = SwiftUtils.pseudoRandomString(length: Int.random(in: 0..<200))
            sContact.firstName = SwiftUtils.pseudoRandomString(length: Int.random(in: 0..<200))
            sContact.lastName = SwiftUtils.pseudoRandomString(length: Int.random(in: 0..<200))
            let profileImage = BytesUtility.generateRandomBytes(length: 500)!
            let customImage = BytesUtility.generateRandomBytes(length: 500)!

            var delta = DeltaSyncContact(syncContact: sContact, syncAction: .update)
            delta.profilePicture = .updated
            delta.image = customImage
            delta.contactProfilePicture = .updated
            delta.contactImage = profileImage
            return delta
        }
        for c in [0, 1, 2, 100, 500, 50 * 1000] {
            var originalContacts = [DeltaSyncContact]()

            for _ in 0...c {
                originalContacts.append(generateContact())
            }

            let taskDefinition = TaskDefinitionUpdateContactSync(deltaSyncContacts: originalContacts)

            let encoder = JSONEncoder()
            let data = try encoder.encode(taskDefinition)

            let decoder = JSONDecoder()
            let result = try decoder.decode(TaskDefinitionUpdateContactSync.self, from: data)
            XCTAssertTrue(result.retry)

            let contactList = result.deltaSyncContacts
            for i in 0..<contactList.count {
                let oContact = originalContacts[i].syncContact
                let nContact = contactList[i].syncContact
                XCTAssertEqual(oContact.identity, nContact.identity)
                XCTAssertEqual(oContact.identityType, nContact.identityType)
                XCTAssertEqual(oContact.publicKey, nContact.publicKey)
                XCTAssertEqual(oContact.verificationLevel, nContact.verificationLevel)
                XCTAssertEqual(oContact.nickname, nContact.nickname)
                XCTAssertEqual(oContact.firstName, nContact.firstName)
                XCTAssertEqual(oContact.lastName, nContact.lastName)
                XCTAssertEqual(originalContacts[i].profilePicture, contactList[i].profilePicture)
                XCTAssertEqual(originalContacts[i].image?.count, contactList[i].image?.count)
                XCTAssertEqual(originalContacts[i].contactProfilePicture, contactList[i].contactProfilePicture)
                XCTAssertEqual(originalContacts[i].contactImage?.count, contactList[i].contactImage?.count)
            }
        }
    }

    func testTaskDefinitionDeleteContactSyncEncodeDecode() throws {
        for c in [0, 1, 2, 100, 500, 50 * 1000] {
            var identities = [String]()
            for _ in 0...c {
                identities.append(SwiftUtils.pseudoRandomString(length: 7))
            }

            let taskDefinition = TaskDefinitionDeleteContactSync(contacts: identities)

            let encoder = JSONEncoder()
            let data = try encoder.encode(taskDefinition)

            let decoder = JSONDecoder()
            let result = try decoder.decode(TaskDefinitionDeleteContactSync.self, from: data)
            XCTAssertTrue(result.retry)

            let contactList = result.contacts
            for i in 0..<contactList.count {
                XCTAssertEqual(contactList[i], identities[i])
            }
        }
    }
    
    func testTaskDefinitionSendGroupDeliveryReceiptsMessageEncodeDecode() throws {
        let expectedGroupID = BytesUtility.generateRandomBytes(length: 8)!
        let expectedGroupCreator = "CREATOR01"
        let expectedFromMember = "MEMBER01"
        let expectedToMembers = ["MEMBER03", "MEMBER04"]
        let expectedReceiptType = UInt8(GroupDeliveryReceipt.DeliveryReceiptType.acknowledged.rawValue)
        let expectedReceiptMessageIDs = [
            BytesUtility.generateRandomBytes(length: 32)!,
            BytesUtility.generateRandomBytes(length: 32)!,
        ]
        
        let task = TaskDefinitionSendGroupDeliveryReceiptsMessage(
            group: nil,
            from: expectedFromMember,
            to: expectedToMembers,
            receiptType: expectedReceiptType,
            receiptMessageIDs: expectedReceiptMessageIDs,
            sendContactProfilePicture: false
        )
        
        task.groupID = expectedGroupID
        task.groupCreatorIdentity = expectedGroupCreator
        
        let encoder = JSONEncoder()
        let data = try XCTUnwrap(encoder.encode(task))
        print(String(data: data, encoding: .utf8)!)
        
        let decoder = JSONDecoder()
        let result = try XCTUnwrap(decoder.decode(TaskDefinitionSendGroupDeliveryReceiptsMessage.self, from: data))
        let groupID = try XCTUnwrap(result.groupID)
        XCTAssertTrue(expectedGroupID.elementsEqual(groupID))
        XCTAssertEqual(expectedGroupCreator, result.groupCreatorIdentity)
        XCTAssertEqual(expectedReceiptType, result.receiptType)
        XCTAssertEqual(expectedReceiptMessageIDs, result.receiptMessageIDs)
        XCTAssertEqual(expectedFromMember, result.fromMember)
        XCTAssertEqual(expectedToMembers, result.toMembers)
        XCTAssertTrue(result.isPersistent)
        XCTAssertFalse(result.retry)
    }
}
