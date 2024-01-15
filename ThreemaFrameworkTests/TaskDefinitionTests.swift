//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2024 Threema GmbH
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

        let decoder = JSONDecoder()
        let result = try decoder.decode(TaskDefinition.self, from: data)
        XCTAssertTrue(result.isPersistent)
        XCTAssertTrue(result.retry)
        XCTAssertEqual(result.retryCount, 0)
    }

    func testTaskDefinitionChangedAttributesEncodeDecode() throws {
        let task = TaskDefinition(isPersistent: true)
        task.isPersistent = false
        task.retry = false
        task.retryCount = 1
        task.state = .executing

        let encoder = JSONEncoder()
        let data = try encoder.encode(task)

        let decoder = JSONDecoder()
        let result = try decoder.decode(TaskDefinition.self, from: data)

        XCTAssertFalse(result.isPersistent)
        XCTAssertFalse(result.retry)
        XCTAssertEqual(result.retryCount, 1)
        XCTAssertEqual(result.state, .executing)
    }

    func testTaskDefinitionGroupDissolveEncodeDecode() throws {
        let expectedMember = "MEMBER01"
        let expectedNonces = [
            "ADMIN007": MockData.generateMessageNonce(),
            expectedMember: MockData.generateMessageNonce(),
        ]

        let (_, groupEntity, conversation) = try dbPreparer.createGroup(
            groupID: MockData.generateGroupID(),
            groupCreatorIdentity: "ADMIN007",
            members: ["ECHOECHO"]
        )
        let expectedGroup = Group(
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            groupEntity: groupEntity,
            conversation: conversation,
            lastSyncRequest: nil
        )

        let task = TaskDefinitionGroupDissolve(group: expectedGroup)
        task.toMembers = [expectedMember]
        task.nonces = expectedNonces

        let encoder = JSONEncoder()
        let data = try encoder.encode(task)

        let decoder = JSONDecoder()
        let result = try decoder.decode(TaskDefinitionGroupDissolve.self, from: data)

        XCTAssertNil(result.receiverIdentity)
        XCTAssertEqual(expectedGroup.groupID, result.groupID)
        XCTAssertEqual(expectedGroup.groupCreatorIdentity, result.groupCreatorIdentity)
        XCTAssertEqual(1, result.toMembers.count)
        XCTAssertTrue(result.toMembers.contains(expectedMember))
        XCTAssertTrue(result.nonces.isEmpty)
        XCTAssertTrue(result.isPersistent)
        XCTAssertTrue(result.retry)
    }

    func testTaskDefinitionReflectIncomingMessageEncodeDecode() throws {
        let expectedMessageID = MockData.generateMessageID()
        let expectedIdentity = "ECHOECHO"
        let expectedText = "test 123!!!"
        let expectedNonces = [expectedIdentity: MockData.generateMessageNonce()]

        let expectedAbstractMessage = BoxTextMessage()
        expectedAbstractMessage.messageID = expectedMessageID
        expectedAbstractMessage.fromIdentity = expectedIdentity
        expectedAbstractMessage.toIdentity = expectedIdentity
        expectedAbstractMessage.text = expectedText

        let task = TaskDefinitionReflectIncomingMessage(message: expectedAbstractMessage)
        task.nonces = expectedNonces

        let encoder = JSONEncoder()
        let data = try XCTUnwrap(encoder.encode(task))

        let decoder = JSONDecoder()
        let result = try XCTUnwrap(decoder.decode(TaskDefinitionReflectIncomingMessage.self, from: data))

        XCTAssertEqual(result.message.messageID, expectedMessageID)
        XCTAssertEqual(result.message.fromIdentity, expectedIdentity)
        XCTAssertEqual(result.message.toIdentity, expectedIdentity)
        XCTAssertEqual((result.message as? BoxTextMessage)?.text, expectedText)
        XCTAssertTrue(result.nonces.isEmpty)
        XCTAssertFalse(result.isPersistent)
        XCTAssertFalse(result.retry)
    }

    func testTaskDefinitionSendDeliveryReceiptsMessageEncodeDecode() throws {
        let expectedFromIdentity = "CONTACT1"
        let expectedToIdentity = "CONTACT2"
        let expectedReceiptType: ReceiptType = .read
        let expectedReceiptMessageIDs = [
            MockData.generateMessageID(),
            MockData.generateMessageID(),
        ]
        let expectedReceiptReadDates = [
            Date(),
            Date(),
        ]
        let expectedNonces = [expectedToIdentity: MockData.generateMessageNonce()]

        let task = TaskDefinitionSendDeliveryReceiptsMessage(
            fromIdentity: expectedFromIdentity,
            toIdentity: expectedToIdentity,
            receiptType: expectedReceiptType,
            receiptMessageIDs: expectedReceiptMessageIDs,
            receiptReadDates: expectedReceiptReadDates,
            excludeFromSending: [Data]()
        )
        task.nonces = expectedNonces

        let encoder = JSONEncoder()
        let data = try XCTUnwrap(encoder.encode(task))

        let decoder = JSONDecoder()
        let result = try XCTUnwrap(decoder.decode(TaskDefinitionSendDeliveryReceiptsMessage.self, from: data))

        XCTAssertNil(result.receiverIdentity)
        XCTAssertNil(result.groupID)
        XCTAssertEqual(expectedFromIdentity, result.fromIdentity)
        XCTAssertEqual(expectedToIdentity, result.toIdentity)
        XCTAssertEqual(expectedReceiptType, result.receiptType)
        XCTAssertEqual(expectedReceiptMessageIDs, result.receiptMessageIDs)
        XCTAssertEqual(expectedReceiptReadDates, result.receiptReadDates)
        XCTAssertTrue(result.excludeFromSending.isEmpty)
        XCTAssertTrue(result.nonces.isEmpty)
        XCTAssertTrue(result.isPersistent)
        XCTAssertTrue(result.retry)
    }

    func testTaskDefinitionSendMessageEncodeDecode() throws {
        let expectedNonces = ["ECHOECHO": MockData.generateMessageNonce()]

        let task = TaskDefinitionSendMessage(sendContactProfilePicture: false)
        task.nonces = expectedNonces

        let encoder = JSONEncoder()
        let data = try encoder.encode(task)

        let decoder = JSONDecoder()
        let result = try decoder.decode(TaskDefinitionSendMessage.self, from: data)

        XCTAssertFalse(result.sendContactProfilePicture ?? true)
        XCTAssertTrue(result.nonces.isEmpty)
        XCTAssertTrue(result.isPersistent)
        XCTAssertTrue(result.retry)
    }

    func testTaskDefinitionSendBallotVoteMessageEncodeDecode() throws {
        let expectedBallotID = MockData.generateBallotID()
        let expectedReceiverIdentity = "ECHOECHO"
        let expectedNonces = ["ECHOECHO": MockData.generateMessageNonce()]

        let task = TaskDefinitionSendBallotVoteMessage(
            ballotID: expectedBallotID,
            receiverIdentity: expectedReceiverIdentity,
            group: nil,
            sendContactProfilePicture: true
        )
        task.nonces = expectedNonces

        let encoder = JSONEncoder()
        let data = try encoder.encode(task)

        let decoder = JSONDecoder()
        let result = try decoder.decode(TaskDefinitionSendBallotVoteMessage.self, from: data)

        XCTAssertEqual(expectedBallotID, result.ballotID)
        XCTAssertEqual(expectedReceiverIdentity, result.receiverIdentity)
        XCTAssertFalse(result.isGroupMessage)
        XCTAssertTrue(result.sendContactProfilePicture ?? false)
        XCTAssertTrue(result.nonces.isEmpty)
        XCTAssertTrue(result.isPersistent)
        XCTAssertTrue(result.retry)
    }

    func testTaskDefinitionSendBaseMessageEncodeDecode() throws {
        let expectedMessageID = MockData.generateMessageID()
        let expectedNonces = ["ADMIN007": MockData.generateMessageNonce()]

        let (_, groupEntity, conversation) = try dbPreparer.createGroup(
            groupID: MockData.generateGroupID(),
            groupCreatorIdentity: "ADMIN007",
            members: ["ECHOECHO"]
        )
        let expectedGroup = Group(
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            groupEntity: groupEntity,
            conversation: conversation,
            lastSyncRequest: nil
        )

        let task = TaskDefinitionSendBaseMessage(
            messageID: expectedMessageID,
            receiverIdentity: nil,
            group: expectedGroup,
            sendContactProfilePicture: true
        )
        task.nonces = expectedNonces
        task.messageAlreadySentTo["ADMIN007"] = expectedNonces["ADMIN007"]

        let encoder = JSONEncoder()
        let data = try encoder.encode(task)

        let decoder = JSONDecoder()
        let result = try decoder.decode(TaskDefinitionSendBaseMessage.self, from: data)

        XCTAssertTrue(result.isGroupMessage)
        XCTAssertEqual(expectedMessageID, result.messageID)
        XCTAssertNil(result.receiverIdentity)
        XCTAssertEqual(expectedGroup.groupID, result.groupID)
        XCTAssertEqual(expectedGroup.groupCreatorIdentity, result.groupCreatorIdentity)
        XCTAssertTrue(result.sendContactProfilePicture ?? false)
        XCTAssertEqual(1, result.messageAlreadySentTo.count)
        XCTAssertTrue(result.nonces.isEmpty)
        XCTAssertTrue(result.isPersistent)
        XCTAssertTrue(result.retry)
    }

    func testTaskDefinitionSendLocationMessageEncodeDecode() throws {
        let expectedMessageID = MockData.generateMessageID()
        let expectedMessagePoiAddress = "poi address"
        let expectedNonces = ["ADMIN007": MockData.generateMessageNonce()]

        let (_, groupEntity, conversation) = try dbPreparer.createGroup(
            groupID: MockData.generateGroupID(),
            groupCreatorIdentity: "ADMIN007",
            members: ["ECHOECHO"]
        )
        let expectedGroup = Group(
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            groupEntity: groupEntity,
            conversation: conversation,
            lastSyncRequest: nil
        )

        let task = TaskDefinitionSendLocationMessage(
            poiAddress: expectedMessagePoiAddress,
            messageID: expectedMessageID,
            receiverIdentity: nil,
            group: expectedGroup,
            sendContactProfilePicture: true
        )
        task.nonces = expectedNonces

        let encoder = JSONEncoder()
        let data = try encoder.encode(task)

        let decoder = JSONDecoder()
        let result = try decoder.decode(TaskDefinitionSendLocationMessage.self, from: data)

        XCTAssertTrue(result.isGroupMessage)
        XCTAssertEqual(expectedMessageID, result.messageID)
        XCTAssertNil(task.receiverIdentity)
        XCTAssertEqual(expectedGroup.groupID, result.groupID)
        XCTAssertEqual(expectedGroup.groupCreatorIdentity, result.groupCreatorIdentity)
        XCTAssertEqual(expectedMessagePoiAddress, result.poiAddress)
        XCTAssertTrue(result.sendContactProfilePicture ?? false)
        XCTAssertTrue(result.nonces.isEmpty)
        XCTAssertTrue(result.isPersistent)
        XCTAssertTrue(result.retry)
    }

    func testTaskDefinitionSendGroupCreateMessageEncodeDecode() throws {
        let expectedToMembers = ["MEMBER04", "MEMBER05"]
        let expectedRemovedMembers = ["MEMBER03", "MEMBER04"]
        let expectedMembers = ["MEMBER01", "MEMBER02"]
        var expectedNonces = [String: Data]()
        expectedToMembers.forEach { identity in
            expectedNonces[identity] = MockData.generateMessageNonce()
        }

        let (_, groupEntity, conversation) = try dbPreparer.createGroup(
            groupID: MockData.generateGroupID(),
            groupCreatorIdentity: "CREATOR1",
            members: expectedMembers
        )
        let expectedGroup = Group(
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            groupEntity: groupEntity,
            conversation: conversation,
            lastSyncRequest: nil
        )

        let task = TaskDefinitionSendGroupCreateMessage(
            group: expectedGroup,
            to: expectedToMembers,
            removed: expectedRemovedMembers,
            members: Set(expectedMembers),
            sendContactProfilePicture: false
        )
        
        task.nonces = expectedNonces

        let encoder = JSONEncoder()
        let data = try XCTUnwrap(encoder.encode(task))

        let decoder = JSONDecoder()
        let result = try XCTUnwrap(decoder.decode(TaskDefinitionSendGroupCreateMessage.self, from: data))

        XCTAssertNil(result.receiverIdentity)
        let groupID = try XCTUnwrap(result.groupID)
        XCTAssertEqual(expectedGroup.groupID, groupID)
        XCTAssertEqual(expectedGroup.groupCreatorIdentity, result.groupCreatorIdentity)
        XCTAssertFalse(result.sendContactProfilePicture ?? true)
        XCTAssertEqual(expectedToMembers, result.toMembers)
        XCTAssertEqual(expectedRemovedMembers, result.removedMembers)
        XCTAssertEqual(Set(expectedMembers), result.members)
        XCTAssertTrue(result.nonces.isEmpty)
        XCTAssertTrue(result.isPersistent)
        XCTAssertTrue(result.retry)
    }

    func testTaskDefinitionSendGroupDeletePhotoMessageEncodeDecode() throws {
        let expectedFromMember = "MEMBER01"
        let expectedToMembers = ["MEMBER03", "MEMBER04"]
        var expectedNonces = [String: Data]()
        expectedToMembers.forEach { identity in
            expectedNonces[identity] = MockData.generateMessageNonce()
        }

        let (_, groupEntity, conversation) = try dbPreparer.createGroup(
            groupID: MockData.generateGroupID(),
            groupCreatorIdentity: "CREATOR1",
            members: ["MEMBER01", "MEMBER02", "MEMBER03", "MEMBER04"]
        )
        let expectedGroup = Group(
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            groupEntity: groupEntity,
            conversation: conversation,
            lastSyncRequest: nil
        )

        let task = TaskDefinitionSendGroupDeletePhotoMessage(
            group: expectedGroup,
            from: expectedFromMember,
            to: expectedToMembers,
            sendContactProfilePicture: false
        )
        
        task.nonces = expectedNonces
        
        let encoder = JSONEncoder()
        let data = try XCTUnwrap(encoder.encode(task))

        let decoder = JSONDecoder()
        let result = try XCTUnwrap(decoder.decode(TaskDefinitionSendGroupDeletePhotoMessage.self, from: data))

        XCTAssertNil(result.receiverIdentity)
        let groupID = try XCTUnwrap(result.groupID)
        XCTAssertEqual(expectedGroup.groupID, groupID)
        XCTAssertEqual(expectedGroup.groupCreatorIdentity, result.groupCreatorIdentity)
        XCTAssertFalse(result.sendContactProfilePicture ?? true)
        XCTAssertEqual(expectedFromMember, result.fromMember)
        XCTAssertEqual(expectedToMembers, result.toMembers)
        XCTAssertTrue(result.nonces.isEmpty)
        XCTAssertTrue(result.isPersistent)
        XCTAssertTrue(result.retry)
    }

    func testTaskDefinitionSendGroupLeaveMessageEncodeDecode() throws {
        let expectedGroupID = MockData.generateGroupID()
        let expectedGroupCreator = "CREATOR1"
        let expectedFromMember = "MEMBER01"
        let expectedToMembers = ["MEMBER03", "MEMBER04"]
        let expectedHiddenContacts = ["MEMBER04"]
        var expectedNonces = [String: Data]()
        expectedToMembers.forEach { identity in
            expectedNonces[identity] = MockData.generateMessageNonce()
        }

        let task = TaskDefinitionSendGroupLeaveMessage(sendContactProfilePicture: false)
        task.groupID = expectedGroupID
        task.groupCreatorIdentity = expectedGroupCreator
        task.fromMember = expectedFromMember
        task.toMembers = expectedToMembers
        task.hiddenContacts = expectedHiddenContacts
        task.nonces = expectedNonces

        let encoder = JSONEncoder()
        let data = try encoder.encode(task)

        let decoder = JSONDecoder()
        let result = try decoder.decode(TaskDefinitionSendGroupLeaveMessage.self, from: data)

        XCTAssertNil(result.receiverIdentity)
        XCTAssertEqual(result.groupID, expectedGroupID)
        XCTAssertEqual(expectedGroupCreator, result.groupCreatorIdentity)
        XCTAssertFalse(result.sendContactProfilePicture ?? true)
        XCTAssertEqual(expectedFromMember, result.fromMember)
        XCTAssertEqual(expectedToMembers, result.toMembers)
        XCTAssertEqual(expectedHiddenContacts, result.hiddenContacts)
        XCTAssertTrue(result.nonces.isEmpty)
        XCTAssertTrue(result.isPersistent)
        XCTAssertTrue(result.retry)
    }

    func testTaskDefinitionSendGroupRenameMessageEncodeDecode() throws {
        let expectedFromMember = "MEMBER01"
        let expectedToMembers = ["MEMBER03", "MEMBER04"]
        let expectedNewName = "New group name"
        var expectedNonces = [String: Data]()
        expectedToMembers.forEach { identity in
            expectedNonces[identity] = MockData.generateMessageNonce()
        }

        let (_, groupEntity, conversation) = try dbPreparer.createGroup(
            groupID: MockData.generateGroupID(),
            groupCreatorIdentity: "CREATOR1",
            members: ["MEMBER01", "MEMBER02", "MEMBER03", "MEMBER04"]
        )
        let expectedGroup = Group(
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            groupEntity: groupEntity,
            conversation: conversation,
            lastSyncRequest: nil
        )

        let task = TaskDefinitionSendGroupRenameMessage(
            group: expectedGroup,
            from: expectedFromMember,
            to: expectedToMembers,
            newName: expectedNewName,
            sendContactProfilePicture: false
        )
        
        task.nonces = expectedNonces

        let encoder = JSONEncoder()
        let data = try XCTUnwrap(encoder.encode(task))
        
        let decoder = JSONDecoder()
        let result = try XCTUnwrap(decoder.decode(TaskDefinitionSendGroupRenameMessage.self, from: data))

        XCTAssertNil(result.receiverIdentity)
        let groupID = try XCTUnwrap(result.groupID)
        XCTAssertEqual(expectedGroup.groupID, groupID)
        XCTAssertEqual(expectedGroup.groupCreatorIdentity, result.groupCreatorIdentity)
        XCTAssertFalse(result.sendContactProfilePicture ?? true)
        XCTAssertEqual(expectedFromMember, result.fromMember)
        XCTAssertEqual(expectedToMembers, result.toMembers)
        XCTAssertEqual(expectedNewName, result.name)
        XCTAssertTrue(result.nonces.isEmpty)
        XCTAssertTrue(result.isPersistent)
        XCTAssertTrue(result.retry)
    }

    func testTaskDefinitionSendGroupSetPhotoMessageEncodeDecode() throws {
        let expectedFromMember = "MEMBER01"
        let expectedToMembers = ["MEMBER03", "MEMBER04"]
        let expectedSize: UInt32 = 10
        let expectedBlobID = MockData.generateBlobID()
        let expectedEncryptionKey = MockData.generateBlobEncryptionKey()
        var expectedNonces = [String: Data]()
        expectedToMembers.forEach { identity in
            expectedNonces[identity] = MockData.generateMessageNonce()
        }
        
        let (_, groupEntity, conversation) = try dbPreparer.createGroup(
            groupID: MockData.generateGroupID(),
            groupCreatorIdentity: "CREATOR1",
            members: ["MEMBER01", "MEMBER02", "MEMBER03", "MEMBER04"]
        )
        let expectedGroup = Group(
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            groupEntity: groupEntity,
            conversation: conversation,
            lastSyncRequest: nil
        )

        let task = TaskDefinitionSendGroupSetPhotoMessage(
            group: expectedGroup,
            from: expectedFromMember,
            to: expectedToMembers,
            size: expectedSize,
            blobID: expectedBlobID,
            encryptionKey: expectedEncryptionKey,
            sendContactProfilePicture: false
        )

        task.nonces = expectedNonces

        let encoder = JSONEncoder()
        let data = try XCTUnwrap(encoder.encode(task))

        let decoder = JSONDecoder()
        let result = try XCTUnwrap(decoder.decode(TaskDefinitionSendGroupSetPhotoMessage.self, from: data))

        XCTAssertNil(result.receiverIdentity)
        let groupID = try XCTUnwrap(result.groupID)
        XCTAssertEqual(expectedGroup.groupID, groupID)
        XCTAssertEqual(expectedGroup.groupCreatorIdentity, result.groupCreatorIdentity)
        XCTAssertFalse(result.sendContactProfilePicture ?? true)
        XCTAssertEqual(expectedFromMember, result.fromMember)
        XCTAssertEqual(expectedToMembers, result.toMembers)
        XCTAssertEqual(expectedSize, result.size)
        XCTAssertEqual(expectedBlobID, result.blobID)
        XCTAssertEqual(expectedEncryptionKey, result.encryptionKey)
        XCTAssertTrue(result.nonces.isEmpty)
        XCTAssertTrue(result.isPersistent)
        XCTAssertTrue(result.retry)
    }

    func testTaskDefinitionSendAbstractMessageEncodeDecode() throws {
        let expectedMessageID = MockData.generateMessageID()
        let expectedText = "Test text"
        let expectedFromIdentity = "FROMID01"
        let expectedToIdentity = "ECHOECHO"
        let expectedDate = Date()
        let expectedNonces = [expectedToIdentity: MockData.generateMessageNonce()]

        let abstractMessage = BoxTextMessage()
        abstractMessage.messageID = expectedMessageID
        abstractMessage.text = expectedText
        abstractMessage.fromIdentity = expectedFromIdentity
        abstractMessage.toIdentity = expectedToIdentity
        abstractMessage.date = expectedDate

        let task = TaskDefinitionSendAbstractMessage(message: abstractMessage)
        task.nonces = expectedNonces

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
            XCTAssertTrue(result.nonces.isEmpty)
            XCTAssertTrue(result.isPersistent)
            XCTAssertTrue(result.retry)
        }
        else {
            XCTFail()
        }
    }

    func testAbstractMessageEncodeDecodeOverBoxedMessage() throws {
        let myIdentityStoreMock = MyIdentityStoreMock()

        let expectedMessageID = MockData.generateMessageID()
        let expectedText = "Test text"
        let expectedFromIdentity = myIdentityStoreMock.identity
        let expectedToIdentity = "ECHOECHO"
        let expectedDate = Date()
        let expectedNonce = MockData.generateMessageNonce()
        var contact: ContactEntity!
        dbPreparer.save {
            contact = dbPreparer.createContact(
                publicKey: MockData.generatePublicKey(),
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
        abstractMessage.nonce = expectedNonce

        let boxedMessage = abstractMessage.makeBox(
            contact,
            myIdentityStore: myIdentityStoreMock,
            nonce: abstractMessage.nonce
        )

        let data = NSMutableData()
        let archiver = NSKeyedArchiver(forWritingWith: data)
        archiver.encodeRootObject(boxedMessage!)
        archiver.finishEncoding()

        let unarchiver = NSKeyedUnarchiver(forReadingWith: Data(bytes: data.mutableBytes, count: data.count))
        let result: BoxedMessage? = try? unarchiver.decodeTopLevelObject() as? BoxedMessage

        if let result {
            XCTAssertNotNil(result.box)
            XCTAssertTrue(expectedMessageID.elementsEqual(result.messageID))
            XCTAssertEqual(expectedFromIdentity, result.fromIdentity)
            XCTAssertEqual(expectedToIdentity, result.toIdentity)
            XCTAssertEqual(expectedDate, result.date)
            XCTAssertEqual(expectedNonce, result.nonce)

            if let decData = myIdentityStoreMock.decryptData(
                result.box,
                withNonce: result.nonce,
                publicKey: contact.publicKey
            ) {
                let paddingLenth: UInt8 = try decData.subdata(in: decData.count - 1..<decData.count).littleEndian()
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
            sContact.publicKey = MockData.generatePublicKey()
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
            XCTAssertTrue(result.isPersistent)
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
            XCTAssertTrue(result.isPersistent)
            XCTAssertTrue(result.retry)

            let contactList = result.contacts
            for i in 0..<contactList.count {
                XCTAssertEqual(contactList[i], identities[i])
            }
        }
    }
    
    func testTaskDefinitionSendGroupDeliveryReceiptsMessageEncodeDecode() throws {
        let expectedFromMember = "MEMBER01"
        let expectedToMembers = ["MEMBER03", "MEMBER04"]
        let expectedReceiptType: ReceiptType = .ack
        let expectedReceiptMessageIDs = [
            MockData.generateMessageID(),
            MockData.generateMessageID(),
        ]
        var expectedNonces = [String: Data]()
        expectedToMembers.forEach { identity in
            expectedNonces[identity] = MockData.generateMessageNonce()
        }

        let (_, groupEntity, conversation) = try dbPreparer.createGroup(
            groupID: MockData.generateGroupID(),
            groupCreatorIdentity: "CREATOR1",
            members: expectedToMembers
        )
        let expectedGroup = Group(
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            groupEntity: groupEntity,
            conversation: conversation,
            lastSyncRequest: nil
        )

        let task = TaskDefinitionSendGroupDeliveryReceiptsMessage(
            group: expectedGroup,
            from: expectedFromMember,
            to: expectedToMembers,
            receiptType: expectedReceiptType,
            receiptMessageIDs: expectedReceiptMessageIDs,
            receiptReadDates: [Date]()
        )
        
        task.nonces = expectedNonces
        
        let encoder = JSONEncoder()
        let data = try XCTUnwrap(encoder.encode(task))
        
        let decoder = JSONDecoder()
        let result = try XCTUnwrap(decoder.decode(TaskDefinitionSendGroupDeliveryReceiptsMessage.self, from: data))

        XCTAssertNil(result.receiverIdentity)
        let groupID = try XCTUnwrap(result.groupID)
        XCTAssertEqual(expectedGroup.groupID, groupID)
        XCTAssertEqual(expectedGroup.groupCreatorIdentity, result.groupCreatorIdentity)
        XCTAssertEqual(expectedReceiptType, result.receiptType)
        XCTAssertEqual(expectedReceiptMessageIDs, result.receiptMessageIDs)
        XCTAssertEqual(expectedFromMember, result.fromMember)
        XCTAssertEqual(expectedToMembers, result.toMembers)
        XCTAssertTrue(result.nonces.isEmpty)
        XCTAssertTrue(result.isPersistent)
        XCTAssertTrue(result.retry)
    }
}
