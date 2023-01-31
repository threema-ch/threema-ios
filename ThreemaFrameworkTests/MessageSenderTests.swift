//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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
import XCTest

@testable import ThreemaFramework

class MessageSenderTests: XCTestCase {
    private var dbMainCnx: DatabaseContext!
    private var dbBackgroundCnx: DatabaseContext!
    private var dbPreparer: DatabasePreparer!
    
    private var ddLoggerMock: DDLoggerMock!
    
    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")
        
        let (_, mainCnx, backgroundCnx) = DatabasePersistentContext.devNullContext()
        dbMainCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: nil)
        dbBackgroundCnx = DatabaseContext(mainContext: mainCnx, backgroundContext: backgroundCnx)
        dbPreparer = DatabasePreparer(context: mainCnx)
        
        ddLoggerMock = DDLoggerMock()
        DDTTYLogger.sharedInstance?.logFormatter = LogFormatterCustom()
        DDLog.add(ddLoggerMock)
    }
    
    func testNotAllwedDonateInteractionForOutgoingMessage() throws {
        
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.donateInteractions = false
        
        let businessInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: dbBackgroundCnx),
            backgroundGroupManager: GroupManagerMock(),
            backgroundUnreadMessages: UnreadMessagesMock(),
            contactStore: ContactStoreMock(),
            entityManager: EntityManager(databaseContext: dbMainCnx),
            groupManager: GroupManagerMock(),
            licenseStore: LicenseStore.shared(),
            messageSender: MessageSenderMock(),
            multiDeviceManager: MultiDeviceManagerMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: userSettingsMock,
            serverConnector: ServerConnectorMock(),
            mediatorMessageProtocol: MediatorMessageProtocolMock(),
            messageProcessor: MessageProcessorMock()
        )
        
        var objectID: NSManagedObjectID!
        dbPreparer.createConversation(marked: false, typing: false, unreadMessageCount: 100) { conversation in
            conversation.groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
            objectID = conversation.objectID
        }
        let expectation = XCTestExpectation()
        
        MessageSender.donateInteractionForOutgoingMessage(in: objectID, with: businessInjectorMock).done { success in
            if success {
                XCTFail("Donations are not allowed")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        DDLog.sharedInstance.flushLog()
        
        XCTAssertTrue(ddLoggerMock.exists(message: "Donations are disabled by the user"))
    }
    
    func testDoNotDonateInteractionForOutgoingMessageIfConversationIsPrivate() throws {
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.donateInteractions = true
        
        let businessInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: dbBackgroundCnx),
            backgroundGroupManager: GroupManagerMock(),
            backgroundUnreadMessages: UnreadMessagesMock(),
            contactStore: ContactStoreMock(),
            entityManager: EntityManager(databaseContext: dbMainCnx),
            groupManager: GroupManagerMock(),
            licenseStore: LicenseStore.shared(),
            messageSender: MessageSenderMock(),
            multiDeviceManager: MultiDeviceManagerMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: userSettingsMock,
            serverConnector: ServerConnectorMock(),
            mediatorMessageProtocol: MediatorMessageProtocolMock(),
            messageProcessor: MessageProcessorMock()
        )
        
        var objectID: NSManagedObjectID!
        dbPreparer.createConversation(marked: false, typing: false, unreadMessageCount: 100) { conversation in
            conversation.groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
            conversation.conversationCategory = .private
            objectID = conversation.objectID
        }
        let expectation = XCTestExpectation()
        
        MessageSender.donateInteractionForOutgoingMessage(in: objectID, with: businessInjectorMock).done { success in
            if success {
                XCTFail("Donations are not allowed")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        DDLog.sharedInstance.flushLog()
        
        XCTAssertTrue(ddLoggerMock.exists(message: "Do not donate for private conversations"))
    }
    
    func testAllowedDonateInteractionForOutgoingMessage() throws {
        
        let userSettingsMock = UserSettingsMock()
        userSettingsMock.donateInteractions = true
        
        let businessInjectorMock = BusinessInjectorMock(
            backgroundEntityManager: EntityManager(databaseContext: dbBackgroundCnx),
            backgroundGroupManager: GroupManagerMock(),
            backgroundUnreadMessages: UnreadMessagesMock(),
            contactStore: ContactStoreMock(),
            entityManager: EntityManager(databaseContext: dbMainCnx),
            groupManager: GroupManagerMock(),
            licenseStore: LicenseStore.shared(),
            messageSender: MessageSenderMock(),
            multiDeviceManager: MultiDeviceManagerMock(),
            myIdentityStore: MyIdentityStoreMock(),
            userSettings: userSettingsMock,
            serverConnector: ServerConnectorMock(),
            mediatorMessageProtocol: MediatorMessageProtocolMock(),
            messageProcessor: MessageProcessorMock()
        )
        
        var objectID: NSManagedObjectID!
        dbPreparer.createConversation(marked: false, typing: false, unreadMessageCount: 100) { conversation in
            conversation.groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
            objectID = conversation.objectID
        }
        
        let expectation = XCTestExpectation()
        
        MessageSender.donateInteractionForOutgoingMessage(in: objectID, with: businessInjectorMock).done { _ in
            // We don't care about success here and only check the absence of a certain log message below
            // because we don't have enabled all entitlements in all targets
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        DDLog.sharedInstance.flushLog()
        XCTAssertFalse(ddLoggerMock.exists(message: "Donations are disabled by the user"))
    }
}
