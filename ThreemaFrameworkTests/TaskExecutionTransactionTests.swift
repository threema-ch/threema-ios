//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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

import PromiseKit
import ThreemaProtocols
import XCTest
@testable import ThreemaFramework

class TaskExecutionTransactionTests: XCTestCase {
    private var databaseMainCnx: DatabaseContext!
    private var databaseBackgroundCnx: DatabaseContext!

    private let timeout: Double = 300
    
    typealias TestMatrix = [(
        messageTransactionScope: D2d_TransactionScope.Scope,
        serverTransactionTypeResponses: [MediatorMessageProtocol.MediatorMessageType],
        expectedServerTransactionErrorResponses: (
            scope: D2d_TransactionScope.Scope,
            error: TaskExecutionTransactionError
        )?,
        expectedErrorMessage: String?,
        description: String
    )]
    
    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
        
        let (_, mainCnx, backgroundCnx) = DatabasePersistentContext.devNullContext()
        databaseMainCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        databaseBackgroundCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)
    }
    
    func testAlreadyLocked() {
        let testMatrix: TestMatrix = [
            (
                .userProfileSync,
                [.rejected],
                (.userProfileSync, .sameTransactionInProgress),
                "\(TaskExecutionTransactionError.sameTransactionInProgress)",
                "Test same transaction is already in progress initiated by another device"
            ),
            (
                .userProfileSync,
                [.rejected],
                (.contactSync, .otherTransactionInProgress),
                "\(TaskExecutionTransactionError.otherTransactionInProgress)",
                "Test different transaction is already in progress initiated by another device"
            ),
        ]

        testWithMatrix(testMatrix: testMatrix)
    }

    func testReflectTransaction() {
        let testMatrix: TestMatrix = [
            (.contactSync, [.lockAck, .unlockAck], nil, nil, "Test regular execution of transaction"),
        ]

        testWithMatrix(testMatrix: testMatrix)
    }

    func testLockTimeout() {
        let testMatrix: TestMatrix = [
            (
                .contactSync,
                [],
                (.contactSync, TaskExecutionTransactionError.lockTimeout),
                "\(TaskExecutionTransactionError.lockTimeout)",
                "Test lock timeout."
            ),
        ]

        testWithMatrix(testMatrix: testMatrix)
    }

    func testIncorrectServerResponses() {
        let testMatrix: TestMatrix = [
            (
                .contactSync,
                [.lockAck, .lockAck],
                (.contactSync, TaskExecutionTransactionError.badResponse),
                "\(TaskExecutionTransactionError.badResponse)",
                "Test incorrect server response. LockAck instead of UnlockAck"
            ),
            (
                .contactSync,
                [.unlockAck, .lockAck],
                (.contactSync, TaskExecutionTransactionError.badResponse),
                "\(TaskExecutionTransactionError.badResponse)",
                "Test incorrect server response. UnlockAck instead of LockAck"
            ),
            (
                .contactSync,
                [.reflectionQueueDry, .lockAck],
                (.contactSync, TaskExecutionTransactionError.badResponse),
                "\(TaskExecutionTransactionError.badResponse)",
                "Test incorrect server response. ReflectionQueueDry instaed of LockAck"
            ),
        ]

        testWithMatrix(testMatrix: testMatrix)
    }
    
    func testWithMatrix(testMatrix: TestMatrix) {
        for test in testMatrix {
            let ddLoggerMock = DDLoggerMock()
            DDTTYLogger.sharedInstance?.logFormatter = LogFormatterCustom()
            DDLog.add(ddLoggerMock)
            
            var expectedMediatorLockState: ([MediatorMessageProtocol.MediatorMessageType], [Data]?)?
            
            let expec = XCTestExpectation(description: "")
            
            let serverConnectorMock = ServerConnectorMock(
                connectionState: .loggedIn,
                deviceID: MockData.deviceID,
                deviceGroupKeys: MockData.deviceGroupKeys
            )
            serverConnectorMock.reflectMessageClosure = { _ in
                if serverConnectorMock.connectionState == .loggedIn {
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
                    return true
                }
                return false
            }
            let frameworkInjectorMock = BusinessInjectorMock(
                backgroundEntityManager: EntityManager(databaseContext: databaseBackgroundCnx),
                entityManager: EntityManager(databaseContext: databaseMainCnx),
                userSettings: UserSettingsMock(enableMultiDevice: true),
                serverConnector: serverConnectorMock
            )

            if let expectedServerTransactionErrorResponse = test.expectedServerTransactionErrorResponses {
                var transaction = expectedServerTransactionErrorResponse.scope
                let transactionInProgress = Data(bytes: &transaction, count: MemoryLayout.size(ofValue: transaction))
                expectedMediatorLockState = (test.serverTransactionTypeResponses, [transactionInProgress])
            }
            else {
                expectedMediatorLockState = (test.serverTransactionTypeResponses, nil)
            }

            var expecError: Error?
            
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
                    XCTFail(
                        "This request should not have returned an error but did so anyways. The error is \(String(describing: error))"
                    )
                }

                if let expectedErrorMessage = test.expectedErrorMessage,
                   let expectedError = error as? TaskExecutionTransactionError {
                    XCTAssertEqual("\(expectedError)", expectedErrorMessage)
                }
                else {
                    XCTFail("Exception should be thrown")
                }

                expec.fulfill()
            }
            
            func successHandler() {
                XCTAssertNil(expecError)

                expec.fulfill()
            }

            let task = test
                .0 == .contactSync ? TaskDefinitionDeleteContactSync(contacts: []) : TaskDefinitionProfileSync(
                    syncUserProfile: Sync_UserProfile(),
                    profileImage: nil,
                    linkMobileNoPending: false,
                    linkEmailPending: false
                )
            let taskExecutionTransaction = TaskExecutionTransactionToTest(
                taskContext: TaskContext(),
                taskDefinition: task,
                frameworkInjector: frameworkInjectorMock
            )

            taskExecutionTransaction.execute()
                .done {
                    DDLog.flushLog()
                    successHandler()
                }
                .catch { error in
                    expecError = error
                    errorHandler(error: error)
                }

            wait(for: [expec], timeout: timeout)
            
            DDLog.remove(ddLoggerMock)
        }
    }
    
    func testNoMediatorKey() {
        let expec = XCTestExpectation(description: "")
        
        let deviceGroupKeys: DeviceGroupKeys? = nil
        let deviceID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.deviceIDLength)!
        let serverConnectorMock = ServerConnectorMock(
            connectionState: .loggedIn,
            deviceID: deviceID,
            deviceGroupKeys: deviceGroupKeys
        )
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: databaseBackgroundCnx),
            backgroundGroupManager: GroupManagerMock(),
            backgroundUnreadMessages: UnreadMessagesMock(),
            contactStore: ContactStoreMock(),
            conversationStore: ConversationStoreMock(),
            entityManager: EntityManager(databaseContext: databaseMainCnx),
            groupManager: GroupManagerMock(),
            licenseStore: LicenseStore.shared(),
            messageSender: MessageSenderMock(),
            multiDeviceManager: MultiDeviceManagerMock(),
            myIdentityStore: MyIdentityStoreMock(),
            unreadMessages: UnreadMessagesMock(),
            userSettings: UserSettingsMock(),
            settingsStore: SettingsStoreMock(),
            serverConnector: serverConnectorMock,
            mediatorMessageProtocol: MediatorMessageProtocolMock(),
            messageProcessor: MessageProcessorMock()
        )

        let task = TaskDefinitionSettingsSync(syncSettings: Sync_Settings())

        let taskExecutionTransaction = TaskExecutionTransactionToTest(
            taskContext: TaskContext(),
            taskDefinition: task,
            frameworkInjector: frameworkInjectorMock
        )

        taskExecutionTransaction.execute()
            .done {
                XCTFail()
            }
            .catch { error in
                if let error = error as? TaskExecutionError, case .multiDeviceNotRegistered = error {
                    expec.fulfill()
                }
                else {
                    XCTFail()
                }
            }

        wait(for: [expec], timeout: timeout)
    }

    private class TaskExecutionTransactionToTest: TaskExecutionTransaction {
        override func reflectTransactionMessages() throws -> [Promise<Void>] {
            [Promise()]
        }
        
        override func writeLocal() -> Promise<Void> {
            Promise()
        }
    }
}
