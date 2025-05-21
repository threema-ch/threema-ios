//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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

import XCTest
@testable import ThreemaFramework

class BaseMessageDisplayTests: XCTestCase {
    
    private var databasePreparer: DatabasePreparer!
    private var conversation: ConversationEntity!
    
    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")
        
        let (_, managedObjectContext, _) = DatabasePersistentContext.devNullContext()
        
        databasePreparer = DatabasePreparer(context: managedObjectContext)
        databasePreparer.save {
            conversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: nil
            )
        }
    }

    // MARK: - messageDisplayState
    
    func testOwnDisplayState() {
        var baseMessage: BaseMessageEntity!
        
        databasePreparer.save {
            baseMessage = databasePreparer.createTextMessage(
                conversation: conversation,
                text: "Hello World",
                date: .now,
                delivered: false,
                id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                isOwn: true,
                read: false,
                sent: false,
                userack: false,
                sender: nil,
                remoteSentDate: .now
            )
        }
        
        XCTAssertEqual(.sending, baseMessage.messageDisplayState)
        
        baseMessage.sent = true
        XCTAssertEqual(.sent, baseMessage.messageDisplayState)
        
        baseMessage.delivered = true
        XCTAssertEqual(.delivered, baseMessage.messageDisplayState)

        baseMessage.read = true
        XCTAssertEqual(.read, baseMessage.messageDisplayState)
        
        baseMessage.sendFailed = true
        XCTAssertEqual(.failed, baseMessage.messageDisplayState)
        
        baseMessage.userack = true
        XCTAssertEqual(.failed, baseMessage.messageDisplayState)
    }
    
    func testOtherDisplayState() {
        var baseMessage: BaseMessageEntity!
        
        databasePreparer.save {
            baseMessage = databasePreparer.createTextMessage(
                conversation: conversation,
                text: "Hello World",
                date: .now,
                delivered: false,
                id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                isOwn: false,
                read: false,
                sent: false,
                userack: false,
                sender: nil,
                remoteSentDate: .now
            )
        }
        
        XCTAssertEqual(.none, baseMessage.messageDisplayState)
        
        baseMessage.sent = true
        XCTAssertEqual(.none, baseMessage.messageDisplayState)
        
        baseMessage.delivered = true
        XCTAssertEqual(.none, baseMessage.messageDisplayState)

        baseMessage.read = true
        XCTAssertEqual(.none, baseMessage.messageDisplayState)
        
        baseMessage.sendFailed = true
        XCTAssertEqual(.none, baseMessage.messageDisplayState)
        
        baseMessage.userack = true
        XCTAssertEqual(.none, baseMessage.messageDisplayState)
    }
    
    func testOwnGroupMessageDisplayState() {
        var baseMessage: BaseMessageEntity!
        
        databasePreparer.save {
            let groupConversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: { conversation in
                    // swiftformat:disable:next acronyms
                    conversation.groupId = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
                }
            )
            
            baseMessage = databasePreparer.createTextMessage(
                conversation: groupConversation,
                text: "Hello World",
                date: .now,
                delivered: false,
                id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                isOwn: true,
                read: false,
                sent: false,
                userack: false,
                sender: nil,
                remoteSentDate: .now
            )
        }
        
        XCTAssertEqual(.sending, baseMessage.messageDisplayState)
        
        baseMessage.sent = true
        XCTAssertEqual(.none, baseMessage.messageDisplayState)
        
        baseMessage.delivered = true
        XCTAssertEqual(.none, baseMessage.messageDisplayState)

        baseMessage.read = true
        XCTAssertEqual(.none, baseMessage.messageDisplayState)
        
        baseMessage.sendFailed = true
        XCTAssertEqual(.failed, baseMessage.messageDisplayState)
        
        baseMessage.userack = true
        XCTAssertEqual(.failed, baseMessage.messageDisplayState)
    }
    
    func testOtherGroupMessageDisplayState() {
        var baseMessage: BaseMessageEntity!
        
        databasePreparer.save {
            let groupConversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: { conversation in
                    // swiftformat:disable:next acronyms
                    conversation.groupId = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
                }
            )
            
            baseMessage = databasePreparer.createTextMessage(
                conversation: groupConversation,
                text: "Hello World",
                date: .now,
                delivered: false,
                id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                isOwn: false,
                read: false,
                sent: false,
                userack: false,
                sender: nil,
                remoteSentDate: .now
            )
        }
        
        XCTAssertEqual(.none, baseMessage.messageDisplayState)
        
        baseMessage.sent = true
        XCTAssertEqual(.none, baseMessage.messageDisplayState)
        
        baseMessage.delivered = true
        XCTAssertEqual(.none, baseMessage.messageDisplayState)

        baseMessage.read = true
        XCTAssertEqual(.none, baseMessage.messageDisplayState)
        
        // Should not really be reachable
        baseMessage.sendFailed = true
        XCTAssertEqual(.none, baseMessage.messageDisplayState)
        
        baseMessage.userack = true
        XCTAssertEqual(.none, baseMessage.messageDisplayState)
    }
    
    // MARK: - displayDate
    
    func testOwnSingleMessageDisplayDate() {
        var baseMessage: BaseMessageEntity!
        
        let expectedDate = Date(timeIntervalSinceNow: -1000)
        let expectedSentDate = Date(timeIntervalSinceNow: -900)
        let expectedDeliveryDate = Date(timeIntervalSinceNow: -800)
        let expectedReadDate = Date(timeIntervalSinceNow: -700)

        databasePreparer.save {
            baseMessage = databasePreparer.createTextMessage(
                conversation: conversation,
                text: "Hello World",
                date: expectedDate,
                delivered: false,
                id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                isOwn: true,
                read: false,
                sent: false,
                userack: false,
                sender: nil,
                remoteSentDate: nil
            )
        }
        
        XCTAssertEqual(expectedDate, baseMessage.displayDate)
        
        baseMessage.sent = true
        baseMessage.remoteSentDate = expectedSentDate
        XCTAssertEqual(expectedDate, baseMessage.displayDate)
        
        baseMessage.delivered = true
        baseMessage.deliveryDate = expectedDeliveryDate
        XCTAssertEqual(expectedDeliveryDate, baseMessage.displayDate)

        baseMessage.read = true
        baseMessage.readDate = expectedReadDate
        XCTAssertEqual(expectedReadDate, baseMessage.displayDate)

        baseMessage.sendFailed = true
        XCTAssertEqual(expectedReadDate, baseMessage.displayDate)
    }
    
    func testOwnGatewayMessageDisplayDate() {
        var baseMessage: BaseMessageEntity!
        
        let expectedDate = Date(timeIntervalSinceNow: -1000)
        let expectedSentDate = Date(timeIntervalSinceNow: -900)
        let expectedDeliveryDate = Date(timeIntervalSinceNow: -800)
        let expectedReadDate = Date(timeIntervalSinceNow: -700)

        databasePreparer.save {
            let gatewayContact = databasePreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: "*TESTGWY"
            )
            conversation.contact = gatewayContact
            
            baseMessage = databasePreparer.createTextMessage(
                conversation: conversation,
                text: "Hello World",
                date: expectedDate,
                delivered: false,
                id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                isOwn: true,
                read: false,
                sent: false,
                userack: false,
                sender: nil,
                remoteSentDate: nil
            )
        }
        
        XCTAssertEqual(expectedDate, baseMessage.displayDate)

        baseMessage.sent = true
        baseMessage.remoteSentDate = expectedSentDate
        XCTAssertEqual(expectedDate, baseMessage.displayDate)
        
        baseMessage.delivered = true
        baseMessage.deliveryDate = expectedDeliveryDate
        XCTAssertEqual(expectedDeliveryDate, baseMessage.displayDate)

        baseMessage.read = true
        baseMessage.readDate = expectedReadDate
        XCTAssertEqual(expectedReadDate, baseMessage.displayDate)

        baseMessage.sendFailed = true
        XCTAssertEqual(expectedReadDate, baseMessage.displayDate)
    }
    
    func testOwnGroupMessageDisplayDate() {
        var baseMessage: BaseMessageEntity!
        
        let expectedDate = Date(timeIntervalSinceNow: -1000)
        let expectedSentDate = Date(timeIntervalSinceNow: -900)
        let expectedDeliveryDate = Date(timeIntervalSinceNow: -800)
        let expectedReadDate = Date(timeIntervalSinceNow: -700)

        databasePreparer.save {
            let groupConversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: { conversation in
                    // swiftformat:disable:next acronyms
                    conversation.groupId = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
                }
            )
            
            baseMessage = databasePreparer.createTextMessage(
                conversation: groupConversation,
                text: "Hello World",
                date: expectedDate,
                delivered: false,
                id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                isOwn: true,
                read: false,
                sent: false,
                userack: false,
                sender: nil,
                remoteSentDate: nil
            )
        }
        
        XCTAssertEqual(expectedDate, baseMessage.displayDate)

        baseMessage.sent = true
        baseMessage.remoteSentDate = expectedSentDate
        XCTAssertEqual(expectedDate, baseMessage.displayDate)
        
        baseMessage.delivered = true
        baseMessage.deliveryDate = expectedDeliveryDate
        XCTAssertEqual(expectedDate, baseMessage.displayDate)

        baseMessage.read = true
        baseMessage.readDate = expectedReadDate
        XCTAssertEqual(expectedDate, baseMessage.displayDate)

        baseMessage.sendFailed = true
        XCTAssertEqual(expectedDate, baseMessage.displayDate)
    }
    
    func testOtherSingleMessageDisplayDate() {
        var baseMessage: BaseMessageEntity!
        
        let expectedSentDate = Date(timeIntervalSinceNow: -1100)
        let expectedDate = Date(timeIntervalSinceNow: -1000)
        let expectedDeliveryDate = Date(timeIntervalSinceNow: -800)
        let expectedReadDate = Date(timeIntervalSinceNow: -700)

        databasePreparer.save {
            baseMessage = databasePreparer.createTextMessage(
                conversation: conversation,
                text: "Hello World",
                date: expectedDate,
                delivered: false,
                id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                isOwn: false,
                read: false,
                sent: false,
                userack: false,
                sender: nil,
                remoteSentDate: expectedSentDate
            )
        }
        
        XCTAssertEqual(expectedSentDate, baseMessage.displayDate)

        baseMessage.sent = true
        XCTAssertEqual(expectedSentDate, baseMessage.displayDate)
        
        baseMessage.delivered = true
        baseMessage.deliveryDate = expectedDeliveryDate
        XCTAssertEqual(expectedSentDate, baseMessage.displayDate)

        baseMessage.read = true
        baseMessage.readDate = expectedReadDate
        XCTAssertEqual(expectedSentDate, baseMessage.displayDate)

        baseMessage.sendFailed = true
        XCTAssertEqual(expectedSentDate, baseMessage.displayDate)
    }
    
    func testOtherGroupMessageDisplayDate() {
        var baseMessage: BaseMessageEntity!
        
        let expectedSentDate = Date(timeIntervalSinceNow: -1100)
        let expectedDate = Date(timeIntervalSinceNow: -1000)
        let expectedDeliveryDate = Date(timeIntervalSinceNow: -800)
        let expectedReadDate = Date(timeIntervalSinceNow: -700)

        databasePreparer.save {
            let groupConversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: { conversation in
                    // swiftformat:disable:next acronyms
                    conversation.groupId = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
                }
            )
            
            baseMessage = databasePreparer.createTextMessage(
                conversation: groupConversation,
                text: "Hello World",
                date: expectedDate,
                delivered: false,
                id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                isOwn: false,
                read: false,
                sent: false,
                userack: false,
                sender: nil,
                remoteSentDate: expectedSentDate
            )
        }
        
        XCTAssertEqual(expectedSentDate, baseMessage.displayDate)

        baseMessage.sent = true
        XCTAssertEqual(expectedSentDate, baseMessage.displayDate)
        
        baseMessage.delivered = true
        baseMessage.deliveryDate = expectedDeliveryDate
        XCTAssertEqual(expectedSentDate, baseMessage.displayDate)

        baseMessage.read = true
        baseMessage.readDate = expectedReadDate
        XCTAssertEqual(expectedSentDate, baseMessage.displayDate)

        baseMessage.sendFailed = true
        XCTAssertEqual(expectedSentDate, baseMessage.displayDate)
    }
    
    // MARK: - Date for state
    
    func testDateForState() {
        var baseMessage: BaseMessageEntity!
        
        let expectedDate = Date(timeIntervalSinceNow: -1000)
        let expectedSentDate = Date(timeIntervalSinceNow: -900)
        let expectedDeliveryDate = Date(timeIntervalSinceNow: -800)
        let expectedReadDate = Date(timeIntervalSinceNow: -700)

        databasePreparer.save {
            baseMessage = databasePreparer.createTextMessage(
                conversation: conversation,
                text: "Hello World",
                date: expectedDate,
                delivered: false,
                id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                isOwn: true,
                read: false,
                sent: false,
                userack: false,
                sender: nil,
                remoteSentDate: expectedSentDate
            )
            
            baseMessage.deliveryDate = expectedDeliveryDate
            baseMessage.readDate = expectedReadDate
        }
    
        XCTAssertNil(baseMessage.date(for: .none))
        XCTAssertNil(baseMessage.date(for: .sending))
        
        XCTAssertNil(baseMessage.date(for: .sent))
        baseMessage.sent = true
        XCTAssertEqual(expectedSentDate, baseMessage.date(for: .sent))
        
        XCTAssertEqual(expectedDeliveryDate, baseMessage.date(for: .delivered))
        XCTAssertEqual(expectedReadDate, baseMessage.date(for: .read))
        XCTAssertNil(baseMessage.date(for: .failed))
    }
}
