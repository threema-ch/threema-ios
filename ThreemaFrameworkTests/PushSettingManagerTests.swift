import ThreemaEssentials

import XCTest
@testable import ThreemaFramework

final class PushSettingManagerTests: XCTestCase {
    private var testDatabase: TestDatabase!

    override func setUp() {
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        testDatabase = TestDatabase()
    }

    func testSaveAndFind() async throws {
        let userSettingsMock = UserSettingsMock()

        let groupID = BytesUtility.generateGroupID()

        let pushSettingManager = PushSettingManager(
            userSettings: userSettingsMock,
            groupManager: GroupManagerMock(),
            entityManager: testDatabase.entityManager,
            markupParser: MarkupParser(),
            taskManager: TaskManagerMock(),
            isWorkApp: false
        )
        await pushSettingManager.save(pushSetting: PushSetting(identity: ThreemaIdentity("ECHOECHO")), sync: false)
        await pushSettingManager.save(
            pushSetting: PushSetting(groupIdentity: GroupIdentity(id: groupID, creator: ThreemaIdentity("ECHOECHO"))),
            sync: false
        )

        XCTAssertEqual(userSettingsMock.pushSettings.count, 2)

        let pushSettingContact = pushSettingManager.find(forContact: ThreemaIdentity("ECHOECHO"))

        XCTAssertEqual(pushSettingContact.identity, ThreemaIdentity("ECHOECHO"))

        let pushSettingGroup = pushSettingManager
            .find(forGroup: GroupIdentity(id: groupID, creator: ThreemaIdentity("ECHOECHO")))

        XCTAssertEqual(pushSettingGroup.groupIdentity, GroupIdentity(id: groupID, creator: ThreemaIdentity("ECHOECHO")))
    }

    func testSaveAndDelete() async throws {
        let userSettingsMock = UserSettingsMock()

        let pushSettingManager = PushSettingManager(
            userSettings: userSettingsMock,
            groupManager: GroupManagerMock(),
            entityManager: testDatabase.entityManager,
            markupParser: MarkupParser(),
            taskManager: TaskManagerMock(),
            isWorkApp: false
        )
        let pushSetting = PushSetting(identity: ThreemaIdentity("ECHOECHO"), groupIdentity: nil, _type: .off)
        await pushSettingManager.save(pushSetting: pushSetting, sync: false)

        XCTAssertEqual(userSettingsMock.pushSettings.count, 1)

        await pushSettingManager.delete(forContact: ThreemaIdentity("ECHOECHO"))

        XCTAssertEqual(userSettingsMock.pushSettings.count, 0)
    }

    func testSaveAndUpdate() async throws {
        let userSettingsMock = UserSettingsMock()

        let pushSettingManager = PushSettingManager(
            userSettings: userSettingsMock,
            groupManager: GroupManagerMock(),
            entityManager: testDatabase.entityManager,
            markupParser: MarkupParser(),
            taskManager: TaskManagerMock(),
            isWorkApp: false
        )
        await pushSettingManager.save(pushSetting: PushSetting(identity: ThreemaIdentity("ECHOECHO")), sync: false)

        XCTAssertEqual(userSettingsMock.pushSettings.count, 1)

        var pushSetting = pushSettingManager.find(forContact: ThreemaIdentity("ECHOECHO"))

        XCTAssertEqual(pushSetting.identity, ThreemaIdentity("ECHOECHO"))
        XCTAssertEqual(pushSetting.type, .on)
        XCTAssertNil(pushSetting.periodOffTillDate)

        // Update push setting and save
        pushSetting.type = .off
        pushSetting.setPeriodOffTime(.time1Hour)
        await pushSettingManager.save(pushSetting: pushSetting, sync: false)

        var updatedPushSetting = pushSettingManager.find(forContact: ThreemaIdentity("ECHOECHO"))
        XCTAssertEqual(updatedPushSetting.type, .off)
        XCTAssertNotNil(updatedPushSetting.periodOffTillDate)
    }

    func testSaveIdentityAndGroupIdentity() async throws {
        let userSettingsMock = UserSettingsMock()

        let pushSettingManager = PushSettingManager(
            userSettings: userSettingsMock,
            groupManager: GroupManagerMock(),
            entityManager: testDatabase.entityManager,
            markupParser: MarkupParser(),
            taskManager: TaskManagerMock(),
            isWorkApp: false
        )
        await pushSettingManager.save(pushSetting: PushSetting(identity: ThreemaIdentity("TESTID01")), sync: false)
        await pushSettingManager.save(pushSetting: PushSetting(identity: ThreemaIdentity("TESTID02")), sync: false)
        await pushSettingManager.save(pushSetting: PushSetting(identity: ThreemaIdentity("TESTID02")), sync: false)
        await pushSettingManager.save(
            pushSetting: PushSetting(groupIdentity: GroupIdentity(
                id: BytesUtility.generateGroupID(),
                creator: ThreemaIdentity("TESTID01")
            )),
            sync: false
        )

        let groupID = BytesUtility.generateGroupID()
        await pushSettingManager.save(
            pushSetting: PushSetting(groupIdentity: GroupIdentity(
                id: groupID,
                creator: ThreemaIdentity("TESTID02")
            )),
            sync: false
        )
        await pushSettingManager.save(
            pushSetting: PushSetting(groupIdentity: GroupIdentity(
                id: groupID,
                creator: ThreemaIdentity("TESTID02")
            )),
            sync: false
        )

        XCTAssertEqual(userSettingsMock.pushSettings.count, 4)
    }

    func testSaveNSOrderedSet() throws {

        enum pushSettingError: Error {
            case decodingFailed
        }

        let pushSetting = PushSetting(identity: ThreemaIdentity("ECHOECHO"))

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(pushSetting)

        let pushSettingList = NSOrderedSet(array: [data])
        let pushSettings = try pushSettingList.map { item in
            guard let data = item as? Data else {
                throw pushSettingError.decodingFailed
            }
            
            return try decoder.decode(PushSetting.self, from: data)
        }

        let result = pushSettings.filter { item in
            item.identity == ThreemaIdentity("ECHOECHO")
        }

        XCTAssertEqual(result.count, 1)
    }
    
    func testEncoding() async throws {
        let rawIdentity = "ECHOECHO"
        let userPushSetting = PushSetting(identity: ThreemaIdentity(rawIdentity))
        let expectedEncodedUserPushSettingString =
            #"{"_type":0,"identity":{"string":"\#(rawIdentity)"},"mentioned":false,"muted":false}"#
        
        let groupID = BytesUtility.generateGroupID()
        let fullGroupIdentity = GroupIdentity(id: groupID, creatorID: rawIdentity)
        var groupPushSetting = PushSetting(groupIdentity: fullGroupIdentity)
        groupPushSetting.type = .off
        groupPushSetting.muted = true
        groupPushSetting.mentioned = true
        let expectedEncodedGroupPushSettingString =
            try #"{"_type":1,"groupIdentity":\#(encode(groupIdentity: fullGroupIdentity)),"mentioned":true,"muted":true}"#

        let userSettingsMock = UserSettingsMock()

        let pushSettingManager = PushSettingManager(
            userSettings: userSettingsMock,
            groupManager: GroupManagerMock(),
            entityManager: testDatabase.entityManager,
            markupParser: MarkupParser(),
            taskManager: TaskManagerMock(),
            isWorkApp: false
        )
        await pushSettingManager.save(pushSetting: userPushSetting, sync: false)
        await pushSettingManager.save(pushSetting: groupPushSetting, sync: false)

        XCTAssertEqual(userSettingsMock.pushSettings.count, 2)
        
        let encodedUserPushSetting = try XCTUnwrap(userSettingsMock.pushSettings[0] as? Data)
        let actualEncodedUserPushSettingString = String(data: encodedUserPushSetting, encoding: .utf8)
        XCTAssertEqual(actualEncodedUserPushSettingString, expectedEncodedUserPushSettingString)
        
        let encodedGroupPushSetting = try XCTUnwrap(userSettingsMock.pushSettings[1] as? Data)
        let actualEncodedGroupPushSettingString = String(data: encodedGroupPushSetting, encoding: .utf8)
        XCTAssertEqual(actualEncodedGroupPushSettingString, expectedEncodedGroupPushSettingString)
    }
    
    func testDecoding() async throws {
        let rawIdentity = "ECHOECHO"
        let encodedUserPushSettingString =
            #"{"_type":0,"identity":{"string":"\#(rawIdentity)"},"mentioned":false,"muted":true}"#
        
        let groupID = BytesUtility.generateGroupID()
        let fullGroupIdentity = GroupIdentity(id: groupID, creatorID: rawIdentity)
        let encodedGroupPushSettingString =
            try #"{"_type":1,"groupIdentity":\#(encode(groupIdentity: fullGroupIdentity)),"mentioned":true,"muted":true}"#

        let userSettingsMock = UserSettingsMock()
        userSettingsMock.pushSettings = [
            Data(encodedUserPushSettingString.utf8),
            Data(encodedGroupPushSettingString.utf8),
        ]

        let pushSettingManager = PushSettingManager(
            userSettings: userSettingsMock,
            groupManager: GroupManagerMock(),
            entityManager: testDatabase.entityManager,
            markupParser: MarkupParser(),
            taskManager: TaskManagerMock(),
            isWorkApp: false
        )
        
        var actualUserPushSetting = pushSettingManager.find(forContact: ThreemaIdentity(rawIdentity))
        XCTAssertEqual(actualUserPushSetting.type, .on)
        XCTAssertEqual(actualUserPushSetting.mentioned, false)
        XCTAssertEqual(actualUserPushSetting.muted, true)
        
        var actualGroupPushSetting = pushSettingManager.find(forGroup: fullGroupIdentity)
        XCTAssertEqual(actualGroupPushSetting.type, .off)
        XCTAssertEqual(actualGroupPushSetting.mentioned, true)
        XCTAssertEqual(actualGroupPushSetting.muted, true)
    }

    private func encode(groupIdentity: GroupIdentity) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try String(data: encoder.encode(groupIdentity), encoding: .utf8)!
    }

    // MARK: - Reactions

    @MainActor
    func testCanSendPushForReactionToOwnMessage() async throws {
        let (pushSettingManager, _, message, _) = makeGroupWithOwnMessage()

        // A message of our own never shows a notification, a reaction to it does
        XCTAssertFalse(pushSettingManager.canSendPush(for: message, isReaction: false))
        XCTAssertTrue(pushSettingManager.canSendPush(for: message, isReaction: true))
    }

    @MainActor
    func testCanSendPushForReactionInGroupWithMentionsOnly() async throws {
        // Our own message mentions everybody, which must not let reactions to it through
        let (pushSettingManager, groupIdentity, ownMessage, incomingMessage) = makeGroupWithOwnMessage(
            text: "Hello @[@@@@@@@@]"
        )
        await pushSettingManager.save(
            pushSetting: PushSetting(identity: nil, groupIdentity: groupIdentity, _type: .off, mentioned: true),
            sync: false
        )

        XCTAssertFalse(pushSettingManager.canSendPush(for: ownMessage, isReaction: true))

        // A message mentioning us still gets through as before
        XCTAssertTrue(pushSettingManager.canSendPush(for: incomingMessage, isReaction: false))
    }

    @MainActor
    func testCanSendPushForReactionInGroupThatIsOff() async throws {
        let (pushSettingManager, groupIdentity, message, _) = makeGroupWithOwnMessage()
        await pushSettingManager.save(
            pushSetting: PushSetting(identity: nil, groupIdentity: groupIdentity, _type: .off),
            sync: false
        )

        XCTAssertFalse(pushSettingManager.canSendPush(for: message, isReaction: true))
    }

    @MainActor
    func testCanSendPushForReactionInSingleChatFollowsChatPartner() async throws {
        let userSettingsMock = UserSettingsMock()
        let pushSettingManager = PushSettingManager(
            userSettings: userSettingsMock,
            groupManager: GroupManagerMock(),
            entityManager: testDatabase.entityManager,
            markupParser: MarkupParser(),
            taskManager: TaskManagerMock(),
            isWorkApp: false
        )

        let dbPreparer = testDatabase.preparer
        let message = dbPreparer.save {
            let contact = dbPreparer.createContact(identity: "PARTNER1")
            let conversation = dbPreparer.createConversation(contactEntity: contact)
            // Our own message has no sender, the one reacting is the chat partner
            return dbPreparer.createTextMessage(
                conversation: conversation,
                isOwn: true,
                sender: nil,
                remoteSentDate: nil
            )
        }

        XCTAssertTrue(pushSettingManager.canSendPush(for: message, isReaction: true))

        await pushSettingManager.save(
            pushSetting: PushSetting(identity: ThreemaIdentity("PARTNER1"), groupIdentity: nil, _type: .off),
            sync: false
        )

        XCTAssertFalse(pushSettingManager.canSendPush(for: message, isReaction: true))
    }

    /// Group with one message of ours and one incoming message with the same text
    private func makeGroupWithOwnMessage(text: String = "Test message") -> (
        pushSettingManager: PushSettingManager,
        groupIdentity: GroupIdentity,
        ownMessage: BaseMessageEntity,
        incomingMessage: BaseMessageEntity
    ) {
        let myIdentityStoreMock = MyIdentityStoreMock()
        let userSettingsMock = UserSettingsMock()
        let groupManagerMock = GroupManagerMock(myIdentityStoreMock)
        let pushSettingManager = PushSettingManager(
            userSettings: userSettingsMock,
            groupManager: groupManagerMock,
            entityManager: testDatabase.entityManager,
            markupParser: MarkupParser(),
            taskManager: TaskManagerMock(),
            isWorkApp: false
        )

        let dbPreparer = testDatabase.preparer
        let (creator, groupEntity, conversation) = dbPreparer.createGroup(
            groupCreatorIdentity: "CREATOR1",
            members: ["CREATOR1", "MEMBER01"],
            myIdentityStoreMock: myIdentityStoreMock
        )
        let (ownMessage, incomingMessage) = dbPreparer.save {
            (
                dbPreparer.createTextMessage(
                    conversation: conversation,
                    text: text,
                    isOwn: true,
                    sender: nil,
                    remoteSentDate: nil
                ),
                dbPreparer.createTextMessage(
                    conversation: conversation,
                    text: text,
                    isOwn: false,
                    sender: creator,
                    remoteSentDate: .now
                )
            )
        }

        let group = Group(
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingsMock,
            pushSettingManager: PushSettingManagerMock(),
            groupEntity: groupEntity,
            conversation: conversation,
            lastSyncRequest: nil
        )
        groupManagerMock.getGroupReturns.append(group)

        return (pushSettingManager, group.groupIdentity, ownMessage, incomingMessage)
    }
}
