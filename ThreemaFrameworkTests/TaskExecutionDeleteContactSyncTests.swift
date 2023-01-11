//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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
import XCTest
@testable import ThreemaFramework

class TaskExecutionDeleteContactSyncTests: XCTestCase {
    private var databaseMainCnx: DatabaseContext!
    private var databaseBackgroundCnx: DatabaseContext!

    private var deviceGroupKeys: DeviceGroupKeys!
    
    private let timeout: Double = 30
    
    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
        
        let (_, mainCnx, backgroundCnx) = DatabasePersistentContext.devNullContext()
        databaseMainCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        databaseBackgroundCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)

        deviceGroupKeys = DeviceGroupKeys(
            dgpk: BytesUtility.generateRandomBytes(length: Int(kDeviceGroupKeyLen))!,
            dgrk: BytesUtility.generateRandomBytes(length: Int(kDeviceGroupKeyLen))!,
            dgdik: BytesUtility.generateRandomBytes(length: Int(kDeviceGroupKeyLen))!,
            dgsddk: BytesUtility.generateRandomBytes(length: Int(kDeviceGroupKeyLen))!,
            dgtsk: BytesUtility.generateRandomBytes(length: Int(kDeviceGroupKeyLen))!,
            deviceGroupIDFirstByteHex: "a1"
        )
    }
    
    func testShouldSkip() throws {
        let deviceID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.deviceIDLength)!
        
        let contact = Contact(context: databaseMainCnx.main)
        contact.identity = "ECHOECHO"
        contact.publicNickname = "ECHOECHO"
        
        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: databaseBackgroundCnx),
            backgroundGroupManager: GroupManagerMock(),
            backgroundUnreadMessages: UnreadMessagesMock(),
            contactStore: ContactStoreMock(callOnCompletion: false, contact),
            entityManager: EntityManager(databaseContext: databaseMainCnx),
            groupManager: GroupManagerMock(),
            licenseStore: LicenseStore.shared(),
            messageSender: MessageSenderMock(),
            multiDeviceManager: MultiDeviceManagerMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            serverConnector: ServerConnectorMock(
                connectionState: .loggedIn,
                deviceID: deviceID,
                deviceGroupKeys: deviceGroupKeys
            ),
            mediatorMessageProtocol: MediatorMessageProtocolMock(),
            messageProcessor: MessageProcessorMock()
        )

        let taskDefinition = TaskDefinitionDeleteContactSync(contacts: [contact.identity])
        let taskExecution = taskDefinition
            .create(frameworkInjector: frameworkInjectorMock) as! TaskExecutionDeleteContactSync
        
        XCTAssert(try! taskExecution.shouldSkip())
        XCTAssert(try! taskExecution.checkPreconditions())
    }
    
    func testSuccessPrecondition() throws {
        let deviceID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.deviceIDLength)!

        let contact = Contact(context: databaseMainCnx.main)
        contact.identity = "ECHOECHO"
        contact.publicNickname = "ECHOECHO"

        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: databaseBackgroundCnx),
            backgroundGroupManager: GroupManagerMock(),
            backgroundUnreadMessages: UnreadMessagesMock(),
            contactStore: ContactStoreMock(),
            entityManager: EntityManager(databaseContext: databaseMainCnx),
            groupManager: GroupManagerMock(),
            licenseStore: LicenseStore.shared(),
            messageSender: MessageSenderMock(),
            multiDeviceManager: MultiDeviceManagerMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            serverConnector: ServerConnectorMock(
                connectionState: .loggedIn,
                deviceID: deviceID,
                deviceGroupKeys: deviceGroupKeys
            ),
            mediatorMessageProtocol: MediatorMessageProtocolMock(),
            messageProcessor: MessageProcessorMock()
        )
        
        let taskDefinition = TaskDefinitionDeleteContactSync(contacts: [contact.identity])
        let taskExecution = taskDefinition
            .create(frameworkInjector: frameworkInjectorMock) as! TaskExecutionDeleteContactSync
        
        XCTAssert(try! taskExecution.checkPreconditions())
    }
    
    func testReflectTransactionMessages() throws {
        let deviceID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.deviceIDLength)!

        let frameworkInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: databaseBackgroundCnx),
            backgroundGroupManager: GroupManagerMock(),
            backgroundUnreadMessages: UnreadMessagesMock(),
            contactStore: ContactStoreMock(),
            entityManager: EntityManager(databaseContext: databaseMainCnx),
            groupManager: GroupManagerMock(),
            licenseStore: LicenseStore.shared(),
            messageSender: MessageSenderMock(),
            multiDeviceManager: MultiDeviceManagerMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: UserSettingsMock(),
            serverConnector: ServerConnectorMock(
                connectionState: .loggedIn,
                deviceID: deviceID,
                deviceGroupKeys: deviceGroupKeys
            ),
            mediatorMessageProtocol: MediatorMessageProtocolMock(),
            messageProcessor: MessageProcessorMock()
        )
        
        for c in [0, 1, 2, 100, 500, 50 * 1000] {
            var identities = [String]()
            for _ in 0..<c {
                identities.append(SwiftUtils.pseudoRandomString(length: 7))
            }
            let taskDefinition = TaskDefinitionDeleteContactSync(contacts: identities)
            let taskExecution = taskDefinition
                .create(frameworkInjector: frameworkInjectorMock) as! TaskExecutionDeleteContactSync
            
            let reflectedContacts = try! taskExecution.reflectTransactionMessages().count
            XCTAssert(reflectedContacts == c)
        }
    }
}
