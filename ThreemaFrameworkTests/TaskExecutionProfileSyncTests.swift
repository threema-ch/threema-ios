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

class TaskExecutionProfileSyncTests: XCTestCase {
    private var dbBackgroundCnx: DatabaseContext!

    // TODO: (IOS-3875) Timeout
    private let timeout: Double = 600

    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        let (_, mainCnx, backgroundCnx) = DatabasePersistentContext
            .devNullContext(withChildContextForBackgroundProcess: true)

        dbBackgroundCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)
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
                nil,
                true,
                getBasicConfig().initialConfig,
                getBasicConfig().secondConfig,
                getBasicConfig().goldConfig,
                "Test basic profile sync with no actual changes."
            ),
            (
                [.lockAck, .reflectAck, .unlockAck],
                nil,
                false,
                getBasicUpdatePushNameConfig().initialConfig,
                getBasicUpdatePushNameConfig().secondConfig,
                getBasicUpdatePushNameConfig().goldConfig,
                "Test profile sync with only the nickname changed"
            ),
            (
                [.lockAck, .reflectAck, .unlockAck],
                nil,
                false,
                getConfigUpdateLinkedEmailAndPhoneFromPending().initialConfig,
                getConfigUpdateLinkedEmailAndPhoneFromPending().secondConfig,
                getConfigUpdateLinkedEmailAndPhoneFromPending().goldConfig,
                "Test profile sync where the linked phone number and email has changed."
            ),
            (
                [.lockAck, .reflectAck, .reflectAck],
                (.userProfileSync, .lockTimeout),
                false,
                getConfigShouldNotChange().initialConfig,
                getConfigShouldNotChange().secondConfig,
                getConfigShouldNotChange().goldConfig,
                "Test profile sync where the linked phone number and email has changed. But can not be synced because the unlock acknowledgement is not sent by the server."
            ),
            (
                [.reflectAck, .reflectAck, .reflectAck],
                (.userProfileSync, .lockTimeout),
                false,
                getConfigShouldNotChange().initialConfig,
                getConfigShouldNotChange().secondConfig,
                getConfigShouldNotChange().goldConfig,
                "Test profile sync where the linked phone number and email has changed. But can not be synced because the lock acknowledgement is not sent by the server."
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
    )]) {

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

            if let expectedServerTransactionErrorResponse = test.expectedServerTransactionErrorResponses {
                var transaction = expectedServerTransactionErrorResponse.scope
                let transactionInProgress = Data(bytes: &transaction, count: MemoryLayout.size(ofValue: transaction))
                expectedMediatorLockState = (test.serverTransactionTypeResponses, [transactionInProgress])
            }
            else {
                expectedMediatorLockState = (test.serverTransactionTypeResponses, nil)
            }

            let frameworkInjectorMock = BusinessInjectorMock(
                entityManager: EntityManager(databaseContext: dbBackgroundCnx),
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

            let (syncUserProfile, profileImage) = getSyncUserProfile(
                initialConfig: test.initialConfig,
                secondConfig: test.secondConfig
            )

            let task = TaskDefinitionProfileSync(
                syncUserProfile: syncUserProfile,
                profileImage: profileImage,
                linkMobileNoPending: test.secondConfig.identityStore.linkMobileNoPending,
                linkEmailPending: test.secondConfig.identityStore.linkEmailPending
            )

            task.create(frameworkInjector: frameworkInjectorMock).execute()
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

    private func getSyncUserProfile(
        initialConfig: (identityStore: MyIdentityStoreProtocol, userSettings: UserSettingsProtocol),
        secondConfig: (identityStore: MyIdentityStoreProtocol, userSettings: UserSettingsProtocol)
    ) -> (syncUserProfile: Sync_UserProfile, profileImage: Data?) {
        var syncUserProfile = Sync_UserProfile()
        var profileImage: Data?

        if initialConfig.identityStore.profilePicture?["ProfilePicture"] as? Data != secondConfig.identityStore
            .profilePicture?["ProfilePicture"] as? Data {
            if let image = secondConfig.identityStore.profilePicture?["ProfilePicture"] as? Data {
                syncUserProfile.profilePicture.updated = Common_Image()
                profileImage = image
            }
            else {
                syncUserProfile.profilePicture.removed = Common_Unit()
            }
        }

        if initialConfig.identityStore.pushFromName != secondConfig.identityStore.pushFromName {
            syncUserProfile.nickname = secondConfig.identityStore.pushFromName
        }

        if initialConfig.userSettings.sendProfilePicture != secondConfig.userSettings.sendProfilePicture {
            switch secondConfig.userSettings.sendProfilePicture {
            case SendProfilePictureNone:
                break
            case SendProfilePictureContacts:
                let contactList: [String] = secondConfig.userSettings.profilePictureContactList
                    .compactMap { item -> String? in
                        if let i = item as? String {
                            return i
                        }
                        return nil
                    }

                var contacts = Common_Identities()
                contacts.identities = contactList
                syncUserProfile.profilePictureShareWith.policy = .allowList(contacts)
            case SendProfilePictureAll:
                break
            default:
                break
            }
        }

        if initialConfig.identityStore.linkedMobileNo != secondConfig.identityStore.linkedMobileNo {
            var linkPhoneNumber = Sync_UserProfile.IdentityLinks.IdentityLink()
            linkPhoneNumber.phoneNumber = secondConfig.identityStore.linkedMobileNo ?? ""
            syncUserProfile.identityLinks.links.append(linkPhoneNumber)
        }

        if initialConfig.identityStore.linkedEmail != secondConfig.identityStore.linkedEmail {
            var linkEmail = Sync_UserProfile.IdentityLinks.IdentityLink()
            linkEmail.email = secondConfig.identityStore.linkedEmail ?? ""
            syncUserProfile.identityLinks.links.append(linkEmail)
        }

        return (syncUserProfile, profileImage)
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
        originalIdentityStore.pushFromName = "Test"

        let originalUserDefaults = UserSettingsMock()
        originalUserDefaults.enableMultiDevice = true
        originalUserDefaults.sendProfilePicture = .init(rawValue: 0)
        originalUserDefaults.profilePictureContactList = []

        let newIdentityStore = MyIdentityStoreMock()
        newIdentityStore.linkMobileNoPending = false
        newIdentityStore.linkedMobileNo = nil
        newIdentityStore.linkEmailPending = false
        newIdentityStore.linkedEmail = nil

        newIdentityStore.profilePicture = nil
        newIdentityStore.pushFromName = "Test"

        let newUserDefaults = UserSettingsMock()
        newUserDefaults.enableMultiDevice = true
        newUserDefaults.sendProfilePicture = .init(rawValue: 0)
        newUserDefaults.profilePictureContactList = []

        let goldIdentityStore = MyIdentityStoreMock()
        goldIdentityStore.linkMobileNoPending = false
        goldIdentityStore.linkedMobileNo = nil
        goldIdentityStore.linkEmailPending = false
        goldIdentityStore.linkedEmail = nil

        goldIdentityStore.profilePicture = nil
        goldIdentityStore.pushFromName = "Test"

        let goldUserDefaults = UserSettingsMock()
        goldUserDefaults.enableMultiDevice = true
        goldUserDefaults.sendProfilePicture = .init(rawValue: 0)
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
        originalUserDefaults.sendProfilePicture = .init(rawValue: 0)
        originalUserDefaults.profilePictureContactList = []

        let newIdentityStore = MyIdentityStoreMock()
        newIdentityStore.linkMobileNoPending = false
        newIdentityStore.linkedMobileNo = nil
        newIdentityStore.linkEmailPending = false
        newIdentityStore.linkedEmail = nil

        newIdentityStore.profilePicture = nil
        newIdentityStore.pushFromName = "Test"

        let newUserDefaults = UserSettingsMock()
        newUserDefaults.enableMultiDevice = true
        newUserDefaults.sendProfilePicture = .init(rawValue: 0)
        newUserDefaults.profilePictureContactList = []

        let goldIdentityStore = MyIdentityStoreMock()
        goldIdentityStore.linkMobileNoPending = false
        goldIdentityStore.linkedMobileNo = nil
        goldIdentityStore.linkEmailPending = false
        goldIdentityStore.linkedEmail = nil

        goldIdentityStore.profilePicture = nil
        goldIdentityStore.pushFromName = "Test"

        let goldUserDefaults = UserSettingsMock()
        goldUserDefaults.enableMultiDevice = true
        goldUserDefaults.sendProfilePicture = .init(rawValue: 0)
        goldUserDefaults.profilePictureContactList = []

        return (
            (originalIdentityStore, originalUserDefaults),
            (newIdentityStore, newUserDefaults),
            (goldIdentityStore, goldUserDefaults)
        )
    }

    func getConfigUpdateLinkedEmailAndPhoneFromPending()
        -> (
            initialConfig: (MyIdentityStoreProtocol, UserSettingsProtocol),
            secondConfig: (MyIdentityStoreProtocol, UserSettingsProtocol),
            goldConfig: (MyIdentityStoreProtocol, UserSettingsProtocol)
        ) {
        let originalIdentityStore = MyIdentityStoreMock()
        originalIdentityStore.linkMobileNoPending = true
        originalIdentityStore.linkedMobileNo = nil
        originalIdentityStore.linkEmailPending = true
        originalIdentityStore.linkedEmail = nil

        originalIdentityStore.profilePicture = nil
        originalIdentityStore.pushFromName = ""

        let originalUserDefaults = UserSettingsMock()
        originalUserDefaults.enableMultiDevice = true
        originalUserDefaults.sendProfilePicture = .init(rawValue: 0)
        originalUserDefaults.profilePictureContactList = []

        let newIdentityStore = MyIdentityStoreMock()
        newIdentityStore.linkMobileNoPending = false
        newIdentityStore.linkedMobileNo = "+41"
        newIdentityStore.linkEmailPending = false
        newIdentityStore.linkedEmail = "support@threema.ch"

        newIdentityStore.profilePicture = nil
        newIdentityStore.pushFromName = "Test"

        let newUserDefaults = UserSettingsMock()
        newUserDefaults.enableMultiDevice = true
        newUserDefaults.sendProfilePicture = .init(rawValue: 0)
        newUserDefaults.profilePictureContactList = []

        let goldIdentityStore = MyIdentityStoreMock()
        goldIdentityStore.linkMobileNoPending = false
        goldIdentityStore.linkedMobileNo = "+41"
        goldIdentityStore.linkEmailPending = false
        goldIdentityStore.linkedEmail = "support@threema.ch"

        goldIdentityStore.profilePicture = nil
        goldIdentityStore.pushFromName = "Test"

        let goldUserDefaults = UserSettingsMock()
        goldUserDefaults.enableMultiDevice = true
        goldUserDefaults.sendProfilePicture = .init(rawValue: 0)
        goldUserDefaults.profilePictureContactList = []

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
        originalIdentityStore.linkMobileNoPending = true
        originalIdentityStore.linkedMobileNo = nil
        originalIdentityStore.linkEmailPending = true
        originalIdentityStore.linkedEmail = nil

        originalIdentityStore.profilePicture = nil
        originalIdentityStore.pushFromName = "Hello World"

        let originalUserDefaults = UserSettingsMock()
        originalUserDefaults.enableMultiDevice = true
        originalUserDefaults.sendProfilePicture = .init(rawValue: 0)
        originalUserDefaults.profilePictureContactList = []

        let newIdentityStore = MyIdentityStoreMock()
        newIdentityStore.linkMobileNoPending = false
        newIdentityStore.linkedMobileNo = "+41"
        newIdentityStore.linkEmailPending = false
        newIdentityStore.linkedEmail = "support@threema.ch"

        newIdentityStore.profilePicture = nil
        newIdentityStore.pushFromName = "Test"

        let newUserDefaults = UserSettingsMock()
        newUserDefaults.enableMultiDevice = true
        newUserDefaults.sendProfilePicture = .init(rawValue: 0)
        newUserDefaults.profilePictureContactList = []

        let goldIdentityStore = MyIdentityStoreMock()
        goldIdentityStore.linkMobileNoPending = true
        goldIdentityStore.linkedMobileNo = nil
        goldIdentityStore.linkEmailPending = true
        goldIdentityStore.linkedEmail = nil

        goldIdentityStore.profilePicture = nil
        goldIdentityStore.pushFromName = "Hello World"

        let goldUserDefaults = UserSettingsMock()
        goldUserDefaults.enableMultiDevice = true
        goldUserDefaults.sendProfilePicture = .init(rawValue: 0)
        goldUserDefaults.profilePictureContactList = []

        return (
            (originalIdentityStore, originalUserDefaults),
            (newIdentityStore, newUserDefaults),
            (goldIdentityStore, goldUserDefaults)
        )
    }
}
