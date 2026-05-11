import Foundation
import ThreemaEssentials
import ThreemaProtocols

import XCTest
@testable import ThreemaFramework

final class TaskExecutionProfileSyncTests: XCTestCase {
    private var dbBackgroundCnx: DatabaseContextProtocol!

    private let timeout: Double = 1

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        let testDatabase = TestDatabase()
        dbBackgroundCnx = testDatabase.backgroundContext
    }
    
    func testAlreadyLocked() {
        let testMatrix: [
            (
                serverTransactionTypeResponses: [MediatorMessageProtocol.MediatorMessageType],
                expectedServerTransactionErrorResponses: (
                    scope: D2d_TransactionScope.Scope,
                    error: TaskExecutionTransactionError
                )?,
                // Should the task report a dropping error?
                // If `TaskExecutionTransactionError` and `TaskExecutionError` become the same error this could be moved
                // into `expectedServerTransactionErrorResponses`
                expectsDropping: Bool,
                expectedProfileStoreSaveCalls: Int,
                description: String,
            )
        ] = [
            (
                [.lockAck, .reflectAck, .unlockAck],
                nil,
                false,
                1,
                "Test profile sync with only the nickname changed"
            ),
            (
                [.lockAck, .reflectAck, .reflectAck],
                (.userProfileSync, .lockTimeout),
                false,
                0,
                "Test profile sync where the nickname has changed. But can not be synced because the unlock acknowledgement is not sent by the server."
            ),
            (
                [.reflectAck, .reflectAck, .reflectAck],
                (.userProfileSync, .lockTimeout),
                false,
                0,
                "Test profile sync where the nickname has changed. But can not be synced because the lock acknowledgement is not sent by the server."
            ),
        ]

        testWithMatrix(testMatrix: testMatrix)
    }

    func testWithMatrix(testMatrix: [(
        serverTransactionTypeResponses: [MediatorMessageProtocol.MediatorMessageType],
        expectedServerTransactionErrorResponses: (
            scope: D2d_TransactionScope.Scope,
            error: TaskExecutionTransactionError
        )?,
        expectsDropping: Bool,
        expectedProfileStoreSaveCalls: Int,
        description: String
    )]) {

        for test in testMatrix {
            let expec = XCTestExpectation(description: "")
            let expectedReflectID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
            let expectedReflectMessage = BytesUtility.generateRandomBytes(length: 16)!
            var expectedMediatorLockState: ([MediatorMessageProtocol.MediatorMessageType], [Data]?)?

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

                    if var lockState = expectedMediatorLockState, !lockState.0.isEmpty {
                        let serverResponse = lockState.0.removeFirst()
                        if serverResponse != .reflectAck {
                            if var response = lockState.1 {
                                if !response.isEmpty {
                                    serverConnectorMock.transactionResponse(
                                        serverResponse.rawValue,
                                        reason: response.removeFirst()
                                    )
                                }
                            }
                            else {
                                serverConnectorMock.transactionResponse(serverResponse.rawValue, reason: nil)
                            }
                        }
                        expectedMediatorLockState = lockState
                    }
                    return nil
                }
                return ThreemaError.threemaError(
                    "Not logged in",
                    withCode: ThreemaProtocolError.notLoggedIn.rawValue
                ) as? NSError
            }

            if let expectedServerTransactionErrorResponse = test.expectedServerTransactionErrorResponses {
                var transaction = expectedServerTransactionErrorResponse.scope
                let transactionInProgress = Data(bytes: &transaction, count: MemoryLayout.size(ofValue: transaction))
                expectedMediatorLockState = (test.serverTransactionTypeResponses, [transactionInProgress])
            }
            else {
                expectedMediatorLockState = (test.serverTransactionTypeResponses, nil)
            }
            
            let profileStoreMock = ProfileStoreMock()
            let userSettingsMock = UserSettingsMock()
            userSettingsMock.enableMultiDevice = true
            
            let frameworkInjectorMock = BusinessInjectorMock(
                entityManager: EntityManager(databaseContext: dbBackgroundCnx, isRemoteSecretEnabled: false),
                profileStore: profileStoreMock,
                userSettings: userSettingsMock, serverConnector: serverConnectorMock,
                mediatorMessageProtocol: MediatorMessageProtocolMock(
                    deviceGroupKeys: MockMultiDevice.deviceGroupKeys,
                    returnValues: [
                        MediatorMessageProtocolMock
                            .ReflectData(
                                id: expectedReflectID,
                                message: expectedReflectMessage
                            ),
                    ]
                ),
                messageProcessor: MessageProcessorMock()
            )

            func errorHandler(error: Error?) {
                if let expectedServerTransactionErrorResponse = test.expectedServerTransactionErrorResponses {
                    if let error = error as? TaskExecutionTransactionError {
                        let message =
                            "Expected the error from the server to be \(expectedServerTransactionErrorResponse.error) but we have received \(error)"
                        XCTAssertEqual(error, expectedServerTransactionErrorResponse.error, message)
                    }
                    else {
                        XCTFail(
                            "Received an unexpected error of type \(String(describing: error)) but we expected \(expectedServerTransactionErrorResponse.error)"
                        )
                    }
                }
                else {
                    if test.expectsDropping {
                        XCTAssertEqual("\(TaskExecutionError.taskDropped)", "\(error!)")
                    }
                    else {
                        XCTFail(
                            "This request should not have returned an error but did so anyways. The error is \(String(describing: error))"
                        )
                    }
                }
                expec.fulfill()
            }

            func successHandler() {
                expec.fulfill()
            }
            
            var profile = D2dSync_UserProfile()
            profile.nickname = "New Nickname"
            
            let task = TaskDefinitionProfileSync(
                syncUserProfile: profile,
                profileImage: nil,
                linkMobileNoPending: false,
                linkEmailPending: false
            )
            
            /// Inject a zero transaction-response timeout so lockTimeout cases fail immediately
            /// rather than waiting the production 25 s per lock/unlock step.
            let taskContext = TaskContext(
                logReflectMessageToMediator: .reflectOutgoingMessageToMediator,
                logReceiveMessageAckFromMediator: .receiveOutgoingMessageAckFromMediator,
                logSendMessageToChat: .none,
                logReceiveMessageAckFromChat: .none,
                transactionResponseTimeoutInSeconds: 0
            )
            task.create(frameworkInjector: frameworkInjectorMock, taskContext: taskContext)
                .execute()
                .done {
                    successHandler()
                }
                .catch { error in
                    errorHandler(error: error)
                }

            wait(for: [expec], timeout: timeout)
            
            XCTAssertEqual(profileStoreMock.saveCalls, test.expectedProfileStoreSaveCalls)
        }
    }
}
