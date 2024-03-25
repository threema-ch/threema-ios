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

import PromiseKit
import XCTest
@testable import ThreemaFramework

class TaskExecutionDeleteContactSyncTests: XCTestCase {
    private var dbMainCnx: DatabaseContext!
    private var dbBackgroundCnx: DatabaseContext!

    private let timeout: Double = 30
    
    override func setUpWithError() throws {
        // Necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
        
        let (_, mainCnx, backgroundCnx) = DatabasePersistentContext
            .devNullContext(withChildContextForBackgroundProcess: true)

        dbMainCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        dbBackgroundCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)
    }
    
    func testShouldSkip() throws {
        let contact = ContactEntity(context: dbMainCnx.main)
        contact.identity = "ECHOECHO"
        contact.publicNickname = "ECHOECHO"

        let frameworkInjectorMock = BusinessInjectorMock(
            contactStore: ContactStoreMock(callOnCompletion: false, contact),
            entityManager: EntityManager(databaseContext: dbBackgroundCnx),
            serverConnector: ServerConnectorMock(
                connectionState: .loggedIn,
                deviceID: MockData.deviceID,
                deviceGroupKeys: MockData.deviceGroupKeys
            )
        )

        let taskDefinition = TaskDefinitionDeleteContactSync(contacts: [contact.identity])
        let taskExecution = taskDefinition
            .create(frameworkInjector: frameworkInjectorMock) as! TaskExecutionDeleteContactSync
        
        XCTAssert(try! taskExecution.shouldSkip())
        XCTAssert(try! taskExecution.checkPreconditions())
    }
    
    func testSuccessPrecondition() throws {
        let contact = ContactEntity(context: dbMainCnx.main)
        contact.identity = "ECHOECHO"
        contact.publicNickname = "ECHOECHO"

        let frameworkInjectorMock = BusinessInjectorMock(
            entityManager: EntityManager(databaseContext: dbBackgroundCnx),
            serverConnector: ServerConnectorMock(
                connectionState: .loggedIn,
                deviceID: MockData.deviceID,
                deviceGroupKeys: MockData.deviceGroupKeys
            )
        )
        
        let taskDefinition = TaskDefinitionDeleteContactSync(contacts: [contact.identity])
        let taskExecution = taskDefinition
            .create(frameworkInjector: frameworkInjectorMock) as! TaskExecutionDeleteContactSync
        
        XCTAssert(try! taskExecution.checkPreconditions())
    }
    
    func testReflectTransactionMessages() throws {
        let frameworkInjectorMock = BusinessInjectorMock(
            entityManager: EntityManager(databaseContext: dbBackgroundCnx),
            serverConnector: ServerConnectorMock(
                connectionState: .loggedIn,
                deviceID: MockData.deviceID,
                deviceGroupKeys: MockData.deviceGroupKeys
            )
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
