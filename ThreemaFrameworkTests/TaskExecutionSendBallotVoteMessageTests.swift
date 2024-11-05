//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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

import Foundation

import XCTest
@testable import ThreemaFramework

class TaskExecutionSendBallotVoteMessageTests: XCTestCase {

    private var dbMainCnx: DatabaseContext!
    private var dbBackgroundCnx: DatabaseContext!
    private var dbPreparer: DatabasePreparer!

    private var ddLoggerMock: DDLoggerMock!

    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        let (_, mainCnx, backgroundCnx) = DatabasePersistentContext.devNullContext()
        dbMainCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        dbBackgroundCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)
        dbPreparer = DatabasePreparer(context: mainCnx)

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
            deviceID: MockData.deviceID,
            deviceGroupKeys: MockData.deviceGroupKeys
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
            entityManager: EntityManager(databaseContext: dbBackgroundCnx),
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
                groupID: MockData.generateGroupID(),
                groupCreator: nil
            )

            var ballotID: Data!
            var group: Group!
            dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default) { conversation in
                // swiftformat:disable:next acronyms
                conversation.groupId = groupEntity.groupId
                conversation.groupMyIdentity = myIdentityStoreMock.identity

                let ballot = frameworkInjectorMock.entityManager.entityCreator.ballot()!
                ballot.id = MockData.generateBallotID()
                ballot.createDate = Date()
                ballot.creatorID = myIdentityStoreMock.identity
                ballot.conversation = conversation

                ballotID = ballot.id
                group = Group(
                    myIdentityStore: myIdentityStoreMock,
                    userSettings: UserSettingsMock(),
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
            deviceID: MockData.deviceID,
            deviceGroupKeys: MockData.deviceGroupKeys
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
            entityManager: EntityManager(databaseContext: dbBackgroundCnx),
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
                identity: receiverIdentity,
                verificationLevel: 0
            )
            let conversation = dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default)
            conversation.contact = contact

            let ballotID = MockData.generateBallotID()
            let ballot = frameworkInjectorMock.entityManager.entityCreator.ballot()
            ballot?.id = ballotID
            ballot?.createDate = Date()
            ballot?.creatorID = frameworkInjectorMock.myIdentityStore.identity
            ballot?.conversation = conversation

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
            deviceID: MockData.deviceID,
            deviceGroupKeys: MockData.deviceGroupKeys
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
            entityManager: EntityManager(databaseContext: dbBackgroundCnx),
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
                    identity: member,
                    verificationLevel: 0
                )
                members.insert(contact)
            }

            let groupEntity = dbPreparer.createGroupEntity(
                groupID: BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!,
                groupCreator: "MEMBER01"
            )
            let conversation = dbPreparer.createConversation(typing: false, unreadMessageCount: 0, visibility: .default)
            // swiftformat:disable:next acronyms
            conversation.groupId = groupEntity.groupId
            conversation.contact = members.first(where: { $0.identity == "MEMBER01" })
            conversation.members?.formUnion(members)

            let ballotID = MockData.generateBallotID()
            let ballot = frameworkInjectorMock.entityManager.entityCreator.ballot()
            ballot?.id = ballotID
            ballot?.createDate = Date()
            ballot?.creatorID = frameworkInjectorMock.myIdentityStore.identity
            ballot?.conversation = conversation

            let group = Group(
                myIdentityStore: myIdentityStoreMock,
                userSettings: userSettingsMock,
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
