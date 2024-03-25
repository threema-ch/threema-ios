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

import Foundation

import ThreemaProtocols
import XCTest
@testable import ThreemaFramework

class TaskExecutionSettingsSyncTests: XCTestCase {
    private var databaseMainCnx: DatabaseContext!
    private var databaseBackgroundCnx: DatabaseContext!

    private let timeout: Double = 60
    
    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
        
        let (_, mainCnx, backgroundCnx) = DatabasePersistentContext.devNullContext()
        databaseMainCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        databaseBackgroundCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)
    }
    
    func testNoDeviceGroupPathKey() {
        let frameworkInjectorMock = BusinessInjectorMock(
            entityManager: EntityManager(databaseContext: databaseMainCnx)
        )

        let task = TaskDefinitionSettingsSync(syncSettings: Sync_Settings())

        let expec = expectation(description: "TaskDefinitionSettingsSync")
        var expecError: Error?

        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                expec.fulfill()
            }
            .catch { error in
                expecError = error
                expec.fulfill()
            }

        waitForExpectations(timeout: 6) { error in
            XCTAssertNil(error)
            if let expectedError = try? XCTUnwrap(expecError as? TaskExecutionError) {
                XCTAssertEqual("\(expectedError)", "\(TaskExecutionError.multiDeviceNotRegistered)")
            }
            else {
                XCTFail("Exception should be thown")
            }
        }
    }
    
    func testConnectionStateDisconnected() {
        let serverConnectorMock = ServerConnectorMock(
            connectionState: .disconnected,
            deviceID: MockData.deviceID,
            deviceGroupKeys: MockData.deviceGroupKeys
        )
        let frameworkInjectorMock = BusinessInjectorMock(
            entityManager: EntityManager(databaseContext: databaseMainCnx),
            userSettings: UserSettingsMock(enableMultiDevice: true),
            serverConnector: serverConnectorMock
        )

        // Change one value otherwise error will be shouldSkip
        var syncSettings = Sync_Settings()
        syncSettings.contactSyncPolicy = .sync

        let task = TaskDefinitionSettingsSync(syncSettings: syncSettings)

        let expect = expectation(description: "TaskDefinitionSettingsSync")
        var expectError: Error?

        task.create(frameworkInjector: frameworkInjectorMock).execute()
            .done {
                DDLog.flushLog()
                expect.fulfill()
            }
            .catch { error in
                expectError = error
                expect.fulfill()
            }

        waitForExpectations(timeout: 6) { error in
            XCTAssertNil(error)
            if let expectedError = try? XCTUnwrap(expectError) {
                XCTAssertEqual(
                    "\(expectedError)",
                    "reflectMessageFailed(message: Optional(\"message type: lock / Error Domain=ThreemaErrorDomain Code=675 \\\"Not logged in\\\" UserInfo={NSLocalizedDescription=Not logged in}\"))"
                )
            }
            else {
                XCTFail("Exception should be thrown")
            }
        }
    }

    func testAlreadyLocked() throws {
        let testMatrix: [
            (
                serverTransactionTypeResponses: [MediatorMessageProtocol.MediatorMessageType],
                expectedServerTransactionErrorResponses: (
                    scope: D2d_TransactionScope.Scope,
                    error: TaskExecutionTransactionError
                )?,
                initialConfig: (
                    identityStore: MyIdentityStoreProtocol,
                    userSettings: UserSettingsProtocol
                ),
                secondConfig: (
                    identityStore: MyIdentityStoreProtocol,
                    userSettings: UserSettingsProtocol
                ),
                goldConfig: (
                    identityStore: MyIdentityStoreProtocol,
                    userSettings: UserSettingsProtocol
                ),
                description: String
            )
        ] = [
            (
                [.lockAck, .reflectAck, .unlockAck],
                (.userProfileSync, .shouldSkip),
                getBasicConfig().initialConfig,
                getBasicConfig().secondConfig,
                getBasicConfig().goldConfig,
                "Test basic settings sync with no actual changes."
            ),
            (
                [.lockAck, .reflectAck, .unlockAck],
                nil,
                getBasicUpdatePushNameConfig().initialConfig,
                getBasicUpdatePushNameConfig().secondConfig,
                getBasicUpdatePushNameConfig().goldConfig,
                "Test settings sync with everything inverted"
            ),
            (
                [.lockAck, .reflectAck, .reflectAck],
                (.userProfileSync, .lockTimeout),
                getConfigShouldNotChange().initialConfig,
                getConfigShouldNotChange().secondConfig,
                getConfigShouldNotChange().goldConfig,
                "Test settings sync with everything inverted, but can not be synced because the unlock acknowledgement is not sent by the server."
            ),
            (
                [.reflectAck, .reflectAck, .reflectAck],
                (.userProfileSync, .lockTimeout),
                getConfigShouldNotChange().initialConfig,
                getConfigShouldNotChange().secondConfig,
                getConfigShouldNotChange().goldConfig,
                "Test settings sync with everything inverted, but can not be synced because the lock acknowledgement is not sent by the server."
            ),
        ]
        
        try testWithMatrix(testMatrix: testMatrix)
    }
    
    func testWithMatrix(testMatrix: [(
        serverTransactionTypeResponses: [MediatorMessageProtocol.MediatorMessageType],
        expectedServerTransactionErrorResponses: (
            scope: D2d_TransactionScope.Scope,
            error: TaskExecutionTransactionError
        )?,
        initialConfig: (
            identityStore: MyIdentityStoreProtocol,
            userSettings: UserSettingsProtocol
        ),
        secondConfig: (
            identityStore: MyIdentityStoreProtocol,
            userSettings: UserSettingsProtocol
        ),
        goldConfig: (
            identityStore: MyIdentityStoreProtocol,
            userSettings: UserSettingsProtocol
        ),
        description: String
    )]) throws {

        for test in testMatrix {
            print("👨‍🏫 Starting Test: \(test.description)")
            let expec = XCTestExpectation(description: "")
            let expectedReflectID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!
            let expectedReflectMessage = BytesUtility.generateRandomBytes(length: 16)!
            var expectedMediatorLockState: ([MediatorMessageProtocol.MediatorMessageType], [Data]?)?

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

            let deviceGroupKeys = try XCTUnwrap(serverConnectorMock.deviceGroupKeys, "Device group keys missing")
            let framworkInjectorMock = BusinessInjectorMock(
                entityManager: EntityManager(databaseContext: databaseMainCnx),
                myIdentityStore: test.initialConfig.identityStore,
                userSettings: test.initialConfig.userSettings,
                serverConnector: serverConnectorMock,
                mediatorMessageProtocol: MediatorMessageProtocolMock(
                    deviceGroupKeys: MockData.deviceGroupKeys,
                    returnValues: [
                        MediatorMessageProtocolMock
                            .ReflectData(
                                id: expectedReflectID,
                                message: expectedReflectMessage
                            ),
                    ]
                )
            )

            if let expectedServerTransactionErrorResponse = test.expectedServerTransactionErrorResponses {
                var transaction = expectedServerTransactionErrorResponse.scope
                let transactionInProgress = Data(bytes: &transaction, count: MemoryLayout.size(ofValue: transaction))
                expectedMediatorLockState = (test.serverTransactionTypeResponses, [transactionInProgress])
            }
            else {
                expectedMediatorLockState = (test.serverTransactionTypeResponses, nil)
            }
            
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
                expec.fulfill()
            }
            
            func successHandler() {
                expec.fulfill()
            }
            
            let task =
                TaskDefinitionSettingsSync(syncSettings: getSyncSettings(
                    initialConfig: test.initialConfig.userSettings,
                    secondConfig: test.secondConfig.userSettings
                ))

            let taskExecutionTransaction = task.create(
                frameworkInjector: framworkInjectorMock,
                taskContext: TaskContext(
                    logReflectMessageToMediator: .reflectOutgoingMessageToMediator,
                    logReceiveMessageAckFromMediator: .receiveOutgoingMessageAckFromMediator,
                    logSendMessageToChat: .none, logReceiveMessageAckFromChat: .none
                )
            )
            
            taskExecutionTransaction.execute()
                .done {
                    successHandler()
                }
                .catch { error in
                    errorHandler(error: error)
                }

            wait(for: [expec], timeout: timeout)
            
            XCTAssertEqual(
                test.initialConfig.identityStore.linkMobileNoPending,
                test.goldConfig.identityStore.linkMobileNoPending
            )
            XCTAssertEqual(
                test.initialConfig.identityStore.linkedMobileNo,
                test.goldConfig.identityStore.linkedMobileNo
            )
            XCTAssertEqual(
                test.initialConfig.identityStore.linkEmailPending,
                test.goldConfig.identityStore.linkEmailPending
            )
            XCTAssertEqual(test.initialConfig.identityStore.linkedEmail, test.goldConfig.identityStore.linkedEmail)
            
            XCTAssertEqual(
                test.initialConfig.identityStore.profilePicture,
                test.goldConfig.identityStore.profilePicture
            )
            XCTAssertEqual(test.initialConfig.identityStore.pushFromName, test.goldConfig.identityStore.pushFromName)
            
            XCTAssertEqual(
                test.initialConfig.userSettings.sendProfilePicture,
                test.goldConfig.userSettings.sendProfilePicture
            )
            
            let oldContactList: [String] = test.initialConfig.userSettings.profilePictureContactList
                .compactMap { item -> String? in
                    if let i = item as? String {
                        return i
                    }
                    return nil
                }
            
            let goldContactList: [String] = test.goldConfig.userSettings.profilePictureContactList
                .compactMap { item -> String? in
                    if let i = item as? String {
                        return i
                    }
                    return nil
                }
            XCTAssertEqual(oldContactList, goldContactList)
        }
    }

    private func getSyncSettings(
        initialConfig: UserSettingsProtocol,
        secondConfig: UserSettingsProtocol
    ) -> Sync_Settings {
        var syncSettings = Sync_Settings()

        if initialConfig.syncContacts != secondConfig.syncContacts {
            syncSettings.contactSyncPolicy = secondConfig.syncContacts ? .sync : .notSynced
        }

        if initialConfig.sendReadReceipts != secondConfig.sendReadReceipts {
            syncSettings.readReceiptPolicy = secondConfig.sendReadReceipts ? .sendReadReceipt : .dontSendReadReceipt
        }

        if initialConfig.blockUnknown != secondConfig.blockUnknown {
            syncSettings.unknownContactPolicy = secondConfig.blockUnknown ? .blockUnknown : .allowUnknown
        }

        if initialConfig.sendTypingIndicator != secondConfig.sendTypingIndicator {
            syncSettings.typingIndicatorPolicy = secondConfig
                .sendTypingIndicator ? .sendTypingIndicator : .dontSendTypingIndicator
        }

        if initialConfig.enableThreemaCall != secondConfig.enableThreemaCall {
            syncSettings.o2OCallPolicy = secondConfig.enableThreemaCall ? .allowO2OCall : .denyO2OCall
        }

        if initialConfig.alwaysRelayCalls != secondConfig.alwaysRelayCalls {
            syncSettings.o2OCallConnectionPolicy = secondConfig
                .alwaysRelayCalls ? .requireRelayedConnection : .allowDirectConnection
        }

        if initialConfig.blacklist != secondConfig.blacklist {
            syncSettings.blockedIdentities
                .identities = secondConfig.blacklist != nil ? secondConfig.blacklist!.map { $0 as! String } : [String]()
        }

        if initialConfig.syncExclusionList as! [String] != secondConfig.syncExclusionList as! [String] {
            syncSettings.excludeFromSyncIdentities.identities = secondConfig.syncExclusionList as! [String]
        }

        return syncSettings
    }
    
    func getBasicConfig() -> (
        initialConfig: (MyIdentityStoreProtocol, UserSettingsProtocol),
        secondConfig: (MyIdentityStoreProtocol, UserSettingsProtocol),
        goldConfig: (MyIdentityStoreProtocol, UserSettingsProtocol)
    ) {
        let originalIdentityStore = MyIdentityStoreMock()
        originalIdentityStore.linkMobileNoPending = false
        originalIdentityStore.linkedMobileNo = nil
        originalIdentityStore.linkEmailPending = false
        originalIdentityStore.linkedEmail = nil
        
        originalIdentityStore.profilePicture = nil
        originalIdentityStore.pushFromName = ""
        
        let originalUserDefaults = UserSettingsMock()
        originalUserDefaults.enableMultiDevice = true
        originalUserDefaults.syncContacts = false
        originalUserDefaults.blockUnknown = false
        originalUserDefaults.sendReadReceipts = false
        originalUserDefaults.sendTypingIndicator = false
        originalUserDefaults.enableThreemaCall = false
        originalUserDefaults.alwaysRelayCalls = false
        originalUserDefaults.blacklist = NSOrderedSet(array: ["*SUPPORT"])
        originalUserDefaults.syncExclusionList = ["*SUPPORT"]
        originalUserDefaults.profilePictureContactList = []
        
        let newIdentityStore = MyIdentityStoreMock()
        newIdentityStore.linkMobileNoPending = false
        newIdentityStore.linkedMobileNo = nil
        newIdentityStore.linkEmailPending = false
        newIdentityStore.linkedEmail = nil
        
        newIdentityStore.profilePicture = nil
        newIdentityStore.pushFromName = ""
        
        let newUserDefaults = UserSettingsMock()
        newUserDefaults.enableMultiDevice = true
        newUserDefaults.syncContacts = false
        newUserDefaults.blockUnknown = false
        newUserDefaults.sendReadReceipts = false
        newUserDefaults.sendTypingIndicator = false
        newUserDefaults.enableThreemaCall = false
        newUserDefaults.alwaysRelayCalls = false
        newUserDefaults.blacklist = NSOrderedSet(array: ["*SUPPORT"])
        newUserDefaults.syncExclusionList = ["*SUPPORT"]
        newUserDefaults.profilePictureContactList = []
        
        let goldIdentityStore = MyIdentityStoreMock()
        goldIdentityStore.linkMobileNoPending = false
        goldIdentityStore.linkedMobileNo = nil
        goldIdentityStore.linkEmailPending = false
        goldIdentityStore.linkedEmail = nil
        
        goldIdentityStore.profilePicture = nil
        goldIdentityStore.pushFromName = ""
        
        let goldUserDefaults = UserSettingsMock()
        goldUserDefaults.enableMultiDevice = true
        goldUserDefaults.syncContacts = false
        goldUserDefaults.blockUnknown = false
        goldUserDefaults.sendReadReceipts = false
        goldUserDefaults.sendTypingIndicator = false
        goldUserDefaults.enableThreemaCall = false
        goldUserDefaults.alwaysRelayCalls = false
        goldUserDefaults.blacklist = NSOrderedSet(array: ["*SUPPORT"])
        goldUserDefaults.syncExclusionList = ["*SUPPORT"]
        goldUserDefaults.profilePictureContactList = []
        
        return (
            (originalIdentityStore, originalUserDefaults),
            (newIdentityStore, newUserDefaults),
            (goldIdentityStore, goldUserDefaults)
        )
    }
    
    func getBasicUpdatePushNameConfig() -> (
        initialConfig: (MyIdentityStoreProtocol, UserSettingsProtocol),
        secondConfig: (MyIdentityStoreProtocol, UserSettingsProtocol),
        goldConfig: (MyIdentityStoreProtocol, UserSettingsProtocol)
    ) {
        let originalIdentityStore = MyIdentityStoreMock()
        originalIdentityStore.linkMobileNoPending = false
        originalIdentityStore.linkedMobileNo = nil
        originalIdentityStore.linkEmailPending = false
        originalIdentityStore.linkedEmail = nil
        
        originalIdentityStore.profilePicture = nil
        originalIdentityStore.pushFromName = ""
        
        let originalUserDefaults = UserSettingsMock()
        originalUserDefaults.enableMultiDevice = true
        originalUserDefaults.syncContacts = false
        originalUserDefaults.blockUnknown = false
        originalUserDefaults.sendReadReceipts = false
        originalUserDefaults.sendTypingIndicator = false
        originalUserDefaults.enableThreemaCall = false
        originalUserDefaults.alwaysRelayCalls = false
        originalUserDefaults.blacklist = NSOrderedSet(array: ["*SUPPORT"])
        originalUserDefaults.syncExclusionList = ["*SUPPORT"]
        originalUserDefaults.profilePictureContactList = []
        
        let newIdentityStore = MyIdentityStoreMock()
        newIdentityStore.linkMobileNoPending = false
        newIdentityStore.linkedMobileNo = nil
        newIdentityStore.linkEmailPending = false
        newIdentityStore.linkedEmail = nil
        
        newIdentityStore.profilePicture = nil
        newIdentityStore.pushFromName = ""
        
        let newUserDefaults = UserSettingsMock()
        newUserDefaults.enableMultiDevice = true
        newUserDefaults.syncContacts = true
        newUserDefaults.blockUnknown = true
        newUserDefaults.sendReadReceipts = true
        newUserDefaults.sendTypingIndicator = true
        newUserDefaults.enableThreemaCall = true
        newUserDefaults.alwaysRelayCalls = true
        newUserDefaults.blacklist = NSOrderedSet(array: [])
        newUserDefaults.syncExclusionList = []
        newUserDefaults.profilePictureContactList = []
        
        let goldIdentityStore = MyIdentityStoreMock()
        goldIdentityStore.linkMobileNoPending = false
        goldIdentityStore.linkedMobileNo = nil
        goldIdentityStore.linkEmailPending = false
        goldIdentityStore.linkedEmail = nil
        
        goldIdentityStore.profilePicture = nil
        goldIdentityStore.pushFromName = ""
        
        var goldUserDefaults = UserSettingsMock()
        goldUserDefaults = newUserDefaults
        
        return (
            (originalIdentityStore, originalUserDefaults),
            (newIdentityStore, newUserDefaults),
            (goldIdentityStore, goldUserDefaults)
        )
    }
    
    func getConfigShouldNotChange() -> (
        initialConfig: (MyIdentityStoreProtocol, UserSettingsProtocol),
        secondConfig: (MyIdentityStoreProtocol, UserSettingsProtocol),
        goldConfig: (MyIdentityStoreProtocol, UserSettingsProtocol)
    ) {
        let originalIdentityStore = MyIdentityStoreMock()
        originalIdentityStore.linkMobileNoPending = false
        originalIdentityStore.linkedMobileNo = nil
        originalIdentityStore.linkEmailPending = false
        originalIdentityStore.linkedEmail = nil
        
        originalIdentityStore.profilePicture = nil
        originalIdentityStore.pushFromName = ""
        
        let originalUserDefaults = UserSettingsMock()
        originalUserDefaults.enableMultiDevice = true
        originalUserDefaults.syncContacts = false
        originalUserDefaults.blockUnknown = false
        originalUserDefaults.sendReadReceipts = false
        originalUserDefaults.sendTypingIndicator = false
        originalUserDefaults.enableThreemaCall = false
        originalUserDefaults.alwaysRelayCalls = false
        originalUserDefaults.blacklist = NSOrderedSet(array: ["*SUPPORT"])
        originalUserDefaults.syncExclusionList = ["*SUPPORT"]
        originalUserDefaults.profilePictureContactList = []
        
        let newIdentityStore = MyIdentityStoreMock()
        newIdentityStore.linkMobileNoPending = false
        newIdentityStore.linkedMobileNo = nil
        newIdentityStore.linkEmailPending = false
        newIdentityStore.linkedEmail = nil
        
        newIdentityStore.profilePicture = nil
        newIdentityStore.pushFromName = ""
        
        let newUserDefaults = UserSettingsMock()
        newUserDefaults.enableMultiDevice = true
        newUserDefaults.syncContacts = true
        newUserDefaults.blockUnknown = true
        newUserDefaults.sendReadReceipts = true
        newUserDefaults.sendTypingIndicator = true
        newUserDefaults.enableThreemaCall = true
        newUserDefaults.alwaysRelayCalls = true
        newUserDefaults.blacklist = NSOrderedSet(array: [])
        newUserDefaults.syncExclusionList = []
        newUserDefaults.profilePictureContactList = []
        
        let goldIdentityStore = MyIdentityStoreMock()
        goldIdentityStore.linkMobileNoPending = false
        goldIdentityStore.linkedMobileNo = nil
        goldIdentityStore.linkEmailPending = false
        goldIdentityStore.linkedEmail = nil
        
        goldIdentityStore.profilePicture = nil
        goldIdentityStore.pushFromName = ""
        
        var goldUserDefaults = UserSettingsMock()
        goldUserDefaults = originalUserDefaults
        
        return (
            (originalIdentityStore, originalUserDefaults),
            (newIdentityStore, newUserDefaults),
            (goldIdentityStore, goldUserDefaults)
        )
    }
}
