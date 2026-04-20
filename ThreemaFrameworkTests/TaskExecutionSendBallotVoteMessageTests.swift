import Foundation
import ThreemaEssentials

import XCTest

@testable import ThreemaFramework

final class TaskExecutionSendBallotVoteMessageTests: XCTestCase {

    private var testDatabase: TestDatabase!
    private var dbPreparer: TestDatabasePreparer!

    private var ddLoggerMock: DDLoggerMock!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        testDatabase = TestDatabase()
        dbPreparer = testDatabase.backgroundPreparer

        // Workaround to ensure remote secret is initialized
        AppLaunchManager.shared.setRemoteSecretManager(testDatabase.remoteSecretManagerMock)

        ddLoggerMock = DDLoggerMock()
        DDTTYLogger.sharedInstance?.logFormatter = LogFormatterCustom()
        DDLog.add(ddLoggerMock)
    }

    override func tearDownWithError() throws {
        DDLog.remove(ddLoggerMock)
    }
    
    func testExecuteNoticeGroupBallotVoteMessageWithReflecting() throws {
        let expectedReflectID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedReflectMessage = BytesUtility.generateRandomBytes(length: 16)!

        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: MockMultiDevice.deviceID,
            deviceGroupKeys: MockMultiDevice.deviceGroupKeys
        )
        serverConnectorMock.reflectMessageClosure = { _ in
            if serverConnectorMock.connectionState == .loggedIn {
                NotificationCenter.default.post(
                    name: TaskManager.mediatorMessageAckObserverName(reflectID: expectedReflectID),
                    object: expectedReflectID,
                    userInfo: [expectedReflectID: Date()]
                )
                return nil
            }
            return ThreemaError.threemaError(
                "Not logged in",
                withCode: ThreemaProtocolError.notLoggedIn.rawValue
            ) as? NSError
        }
        let myIdentityStoreMock = MyIdentityStoreMock()
        let groupManagerMock = GroupManagerMock()
        let frameworkInjectorMock = BusinessInjectorMock(
            entityManager: testDatabase.backgroundEntityManager,
            groupManager: groupManagerMock,
            myIdentityStore: myIdentityStoreMock,
            userSettings: UserSettingsMock(enableMultiDevice: true),
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: MediatorMessageProtocolMock(
                deviceGroupKeys: serverConnectorMock.deviceGroupKeys!,
                returnValues: [
                    MediatorMessageProtocolMock
                        .ReflectData(
                            id: expectedReflectID,
                            message: expectedReflectMessage
                        ),
                ]
            )
        )

        let (ballotID, group) = dbPreparer.save {
            let groupEntity = dbPreparer.createGroupEntity(
                groupID: BytesUtility.generateGroupID(),
                groupCreator: nil
            )

            var ballotID: Data!
            var group: Group!
            dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                conversation.groupID = groupEntity.groupID
                conversation.groupMyIdentity = myIdentityStoreMock.identity

                let ballot = frameworkInjectorMock.entityManager.entityCreator
                    .ballotEntity(id: BytesUtility.generateBallotID())
                ballot.createDate = Date()
                ballot.creatorID = myIdentityStoreMock.identity
                ballot.conversation = conversation

                ballotID = ballot.id
                group = Group(
                    myIdentityStore: myIdentityStoreMock,
                    userSettings: UserSettingsMock(),
                    pushSettingManager: PushSettingManagerMock(),
                    groupEntity: groupEntity,
                    conversation: conversation,
                    lastSyncRequest: nil
                )

                groupManagerMock.getConversationReturns = conversation
            }

            return (ballotID, group)
        }

        let expec = expectation(description: "TaskDefinitionSendBaseMessage")
        var expecError: Error?
        
        let task = TaskDefinitionSendBallotVoteMessage(
            ballotID: ballotID!,
            receiverIdentity: nil,
            group: group,
            sendContactProfilePicture: false
        )
        
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expec.fulfill()
            }
            .catch { error in
                expecError = error
                expec.fulfill()
            }

        waitForExpectations(timeout: 6) { error in
            if let error {
                XCTFail(error.localizedDescription)
            }
            else {
                XCTAssertNil(expecError)
                XCTAssertEqual(1, serverConnectorMock.reflectMessageCalls.count)
                XCTAssertEqual(
                    1,
                    serverConnectorMock.reflectMessageCalls.filter { $0.elementsEqual(expectedReflectMessage) }.count
                )
                XCTAssertEqual(0, serverConnectorMock.sendMessageCalls.count)
            }
        }
    }
    
    func testExecuteBallotVoteMessageWithReflecting() throws {
        let expectedMessageReflectID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedMessageReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageSentReflectID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedMessageSentReflect = BytesUtility.generateRandomBytes(length: 16)!
        var expectedReflectIDs = [expectedMessageReflectID, expectedMessageSentReflectID]
        
        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: MockMultiDevice.deviceID,
            deviceGroupKeys: MockMultiDevice.deviceGroupKeys
        )
        serverConnectorMock.reflectMessageClosure = { _ in
            if serverConnectorMock.connectionState == .loggedIn {
                let expectedReflectID = expectedReflectIDs.remove(at: 0)
                NotificationCenter.default.post(
                    name: TaskManager.mediatorMessageAckObserverName(reflectID: expectedReflectID),
                    object: expectedReflectID,
                    userInfo: [expectedReflectID: Date()]
                )
                return nil
            }
            return ThreemaError.threemaError(
                "Not logged in",
                withCode: ThreemaProtocolError.notLoggedIn.rawValue
            ) as? NSError
        }
        
        let frameworkInjectorMock = BusinessInjectorMock(
            entityManager: testDatabase.backgroundEntityManager,
            userSettings: UserSettingsMock(enableMultiDevice: true),
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: MediatorMessageProtocolMock(
                deviceGroupKeys: serverConnectorMock.deviceGroupKeys!,
                returnValues: [
                    MediatorMessageProtocolMock.ReflectData(
                        id: expectedMessageReflectID,
                        message: expectedMessageReflect
                    ),
                    MediatorMessageProtocolMock.ReflectData(
                        id: expectedMessageSentReflectID,
                        message: expectedMessageSentReflect
                    ),
                ]
            )
        )

        let (ballotID, receiverIdentity) = dbPreparer.save {
            let receiverIdentity = "ECHOECHO"
            let contact = dbPreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                identity: receiverIdentity
            )
            let conversation = dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default)
            conversation.contact = contact

            let ballotID = BytesUtility.generateBallotID()
            let ballot = frameworkInjectorMock.entityManager.entityCreator.ballotEntity(id: ballotID)
            ballot.createDate = Date()
            ballot.creatorID = frameworkInjectorMock.myIdentityStore.identity
            ballot.conversation = conversation

            return (ballotID, receiverIdentity)
        }

        let expec = expectation(description: "TaskDefinitionSendBaseMessage")
        var expecError: Error?

        let task = TaskDefinitionSendBallotVoteMessage(
            ballotID: ballotID,
            receiverIdentity: receiverIdentity,
            group: nil,
            sendContactProfilePicture: false
        )
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expec.fulfill()
            }
            .catch { error in
                expecError = error
                expec.fulfill()
            }

        waitForExpectations(timeout: 6) { error in
            if let error {
                XCTFail(error.localizedDescription)
            }
            else {
                XCTAssertNil(expecError)
                XCTAssertEqual(1, serverConnectorMock.reflectMessageCalls.count)
                XCTAssertEqual(
                    1,
                    serverConnectorMock.reflectMessageCalls.filter { $0.elementsEqual(expectedMessageReflect) }.count
                )
                XCTAssertEqual(
                    0,
                    serverConnectorMock.reflectMessageCalls.filter { $0.elementsEqual(expectedMessageSentReflect) }
                        .count
                )
                XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.count)
            }
        }
    }
    
    func testExecuteGroupBallotVoteMessageWithReflecting() throws {
        let expectedMessageReflectID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedMessageReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMessageSentReflectID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
        let expectedMessageSentReflect = BytesUtility.generateRandomBytes(length: 16)!
        let expectedMembers: Set<String> = ["MEMBER01", "MEMBER02", "MEMBER03"]
        var expectedReflectIDs = [expectedMessageReflectID, expectedMessageSentReflectID]

        let userSettingsMock = UserSettingsMock(blacklist: ["MEMBER02"], enableMultiDevice: true)
        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: MockMultiDevice.deviceID,
            deviceGroupKeys: MockMultiDevice.deviceGroupKeys
        )
        serverConnectorMock.reflectMessageClosure = { _ in
            if serverConnectorMock.connectionState == .loggedIn {
                let expectedReflectID = expectedReflectIDs.remove(at: 0)
                NotificationCenter.default.post(
                    name: TaskManager.mediatorMessageAckObserverName(reflectID: expectedReflectID),
                    object: expectedReflectID,
                    userInfo: [expectedReflectID: Date()]
                )
                return nil
            }
            return ThreemaError.threemaError(
                "Not logged in",
                withCode: ThreemaProtocolError.notLoggedIn.rawValue
            ) as? NSError
        }
        let myIdentityStoreMock = MyIdentityStoreMock()
        let groupManagerMock = GroupManagerMock()
        let frameworkInjectorMock = BusinessInjectorMock(
            entityManager: testDatabase.backgroundEntityManager,
            groupManager: groupManagerMock,
            myIdentityStore: myIdentityStoreMock,
            userSettings: userSettingsMock,
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: MediatorMessageProtocolMock(
                deviceGroupKeys: serverConnectorMock.deviceGroupKeys!,
                returnValues: [
                    MediatorMessageProtocolMock.ReflectData(
                        id: expectedMessageReflectID,
                        message: expectedMessageReflect
                    ),
                    MediatorMessageProtocolMock.ReflectData(
                        id: expectedMessageSentReflectID,
                        message: expectedMessageSentReflect
                    ),
                ]
            )
        )

        let (ballotID, group) = dbPreparer.save {
            var members = Set<ContactEntity>()
            for member in expectedMembers {
                let contact = dbPreparer.createContact(
                    publicKey: BytesUtility.generateRandomBytes(length: 32)!,
                    identity: member
                )
                members.insert(contact)
            }

            let groupEntity = dbPreparer.createGroupEntity(
                groupID: BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!,
                groupCreator: "MEMBER01"
            )
            let conversation = dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default)
            conversation.groupID = groupEntity.groupID
            conversation.contact = members.first(where: { $0.identity == "MEMBER01" })
            conversation.members?.formUnion(members)

            let ballotID = BytesUtility.generateBallotID()
            let ballot = frameworkInjectorMock.entityManager.entityCreator.ballotEntity(id: ballotID)
            ballot.createDate = Date()
            ballot.creatorID = frameworkInjectorMock.myIdentityStore.identity
            ballot.conversation = conversation
            ballot.type = BallotEntity.BallotType.intermediate.rawValue as NSNumber

            let group = Group(
                myIdentityStore: myIdentityStoreMock,
                userSettings: userSettingsMock,
                pushSettingManager: PushSettingManagerMock(),
                groupEntity: groupEntity,
                conversation: conversation,
                lastSyncRequest: nil
            )

            groupManagerMock.getConversationReturns = conversation

            return (ballotID, group)
        }

        let expec = expectation(description: "TaskDefinitionSendBaseMessage")
        var expecError: Error?
        
        let task = TaskDefinitionSendBallotVoteMessage(
            ballotID: ballotID,
            receiverIdentity: nil,
            group: group,
            sendContactProfilePicture: false
        )
        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expec.fulfill()
            }
            .catch { error in
                expecError = error
                expec.fulfill()
            }

        waitForExpectations(timeout: 6) { error in
            if let error {
                XCTFail(error.localizedDescription)
            }
            else {
                XCTAssertNil(expecError)
                XCTAssertEqual(1, serverConnectorMock.reflectMessageCalls.count)
                XCTAssertEqual(
                    1,
                    serverConnectorMock.reflectMessageCalls.filter { $0.elementsEqual(expectedMessageReflect) }.count
                )
                XCTAssertEqual(
                    0,
                    serverConnectorMock.reflectMessageCalls.filter { $0.elementsEqual(expectedMessageSentReflect) }
                        .count
                )
                XCTAssertEqual(2, serverConnectorMock.sendMessageCalls.count)
                XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.filter { $0.toIdentity == "MEMBER01" }.count)
                XCTAssertEqual(1, serverConnectorMock.sendMessageCalls.filter { $0.toIdentity == "MEMBER03" }.count)
            }
        }
    }
}
