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

import XCTest
@testable import ThreemaFramework

class BaseMessageDisplayTests: XCTestCase {
    
    private var databasePreparer: DatabasePreparer!
    private var conversation: Conversation!
    
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
        var baseMessage: BaseMessage!
        
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
        
        baseMessage.userackDate = Date()
        XCTAssertEqual(.userAcknowledged, baseMessage.messageDisplayState)

        baseMessage.userack = false
        XCTAssertEqual(.userDeclined, baseMessage.messageDisplayState)
    }
    
    func testOtherDisplayState() {
        var baseMessage: BaseMessage!
        
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
        
        baseMessage.userackDate = .now
        XCTAssertEqual(.userAcknowledged, baseMessage.messageDisplayState)

        baseMessage.userack = false
        XCTAssertEqual(.userDeclined, baseMessage.messageDisplayState)
    }
    
    func testOwnGroupMessageDisplayState() {
        var baseMessage: BaseMessage!
        
        databasePreparer.save {
            let groupConversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: { conversation in
                    conversation.groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
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
        
        baseMessage.userackDate = .now
        XCTAssertEqual(.userAcknowledged, baseMessage.messageDisplayState)

        baseMessage.userack = false
        XCTAssertEqual(.userDeclined, baseMessage.messageDisplayState)
    }
    
    func testOtherGroupMessageDisplayState() {
        var baseMessage: BaseMessage!
        
        databasePreparer.save {
            let groupConversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: { conversation in
                    conversation.groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
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
        
        baseMessage.userackDate = .now
        XCTAssertEqual(.userAcknowledged, baseMessage.messageDisplayState)

        baseMessage.userack = false
        XCTAssertEqual(.userDeclined, baseMessage.messageDisplayState)
    }
    
    // MARK: - displayDate
    
    func testOwnSingleMessageDisplayDate() {
        var baseMessage: BaseMessage!
        
        let expectedDate = Date(timeIntervalSinceNow: -1000)
        let expectedSentDate = Date(timeIntervalSinceNow: -900)
        let expectedDeliveryDate = Date(timeIntervalSinceNow: -800)
        let expectedReadDate = Date(timeIntervalSinceNow: -700)
        let expectedAcknowledgeDate = Date(timeIntervalSinceNow: -600)
        let expectedDeclineDate = Date(timeIntervalSinceNow: -600)

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

        baseMessage.userack = true
        XCTAssertEqual(expectedReadDate, baseMessage.displayDate)

        baseMessage.userackDate = expectedAcknowledgeDate
        XCTAssertEqual(expectedAcknowledgeDate, baseMessage.displayDate)

        baseMessage.userack = false
        baseMessage.userackDate = expectedDeclineDate
        XCTAssertEqual(expectedDeclineDate, baseMessage.displayDate)
    }
    
    func testOwnGatewayMessageDisplayDate() {
        var baseMessage: BaseMessage!
        
        let expectedDate = Date(timeIntervalSinceNow: -1000)
        let expectedSentDate = Date(timeIntervalSinceNow: -900)
        let expectedDeliveryDate = Date(timeIntervalSinceNow: -800)
        let expectedReadDate = Date(timeIntervalSinceNow: -700)
        let expectedAcknowledgeDate = Date(timeIntervalSinceNow: -600)
        let expectedDeclineDate = Date(timeIntervalSinceNow: -600)

        databasePreparer.save {
            let gatewayContact = databasePreparer.createContact(
                publicKey: BytesUtility.generateRandomBytes(length: Int(32))!,
                identity: "*TESTGWY",
                verificationLevel: 0
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

        baseMessage.userack = true
        XCTAssertEqual(expectedReadDate, baseMessage.displayDate)

        baseMessage.userackDate = expectedAcknowledgeDate
        XCTAssertEqual(expectedAcknowledgeDate, baseMessage.displayDate)

        baseMessage.userack = false
        baseMessage.userackDate = expectedDeclineDate
        XCTAssertEqual(expectedDeclineDate, baseMessage.displayDate)
    }
    
    func testOwnGroupMessageDisplayDate() {
        var baseMessage: BaseMessage!
        
        let expectedDate = Date(timeIntervalSinceNow: -1000)
        let expectedSentDate = Date(timeIntervalSinceNow: -900)
        let expectedDeliveryDate = Date(timeIntervalSinceNow: -800)
        let expectedReadDate = Date(timeIntervalSinceNow: -700)
        let expectedAcknowledgeDate = Date(timeIntervalSinceNow: -600)
        let expectedDeclineDate = Date(timeIntervalSinceNow: -600)

        databasePreparer.save {
            let groupConversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: { conversation in
                    conversation.groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
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

        baseMessage.userack = true
        XCTAssertEqual(expectedDate, baseMessage.displayDate)

        baseMessage.userackDate = expectedAcknowledgeDate
        XCTAssertEqual(expectedAcknowledgeDate, baseMessage.displayDate)

        baseMessage.userack = false
        baseMessage.userackDate = expectedDeclineDate
        XCTAssertEqual(expectedDeclineDate, baseMessage.displayDate)
    }
    
    func testOtherSingleMessageDisplayDate() {
        var baseMessage: BaseMessage!
        
        let expectedSentDate = Date(timeIntervalSinceNow: -1100)
        let expectedDate = Date(timeIntervalSinceNow: -1000)
        let expectedDeliveryDate = Date(timeIntervalSinceNow: -800)
        let expectedReadDate = Date(timeIntervalSinceNow: -700)
        let expectedAcknowledgeDate = Date(timeIntervalSinceNow: -600)
        let expectedDeclineDate = Date(timeIntervalSinceNow: -600)

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

        baseMessage.userack = true
        XCTAssertEqual(expectedSentDate, baseMessage.displayDate)

        baseMessage.userackDate = expectedAcknowledgeDate
        XCTAssertEqual(expectedAcknowledgeDate, baseMessage.displayDate)

        baseMessage.userack = false
        baseMessage.userackDate = expectedDeclineDate
        XCTAssertEqual(expectedDeclineDate, baseMessage.displayDate)
    }
    
    func testOtherGroupMessageDisplayDate() {
        var baseMessage: BaseMessage!
        
        let expectedSentDate = Date(timeIntervalSinceNow: -1100)
        let expectedDate = Date(timeIntervalSinceNow: -1000)
        let expectedDeliveryDate = Date(timeIntervalSinceNow: -800)
        let expectedReadDate = Date(timeIntervalSinceNow: -700)
        let expectedAcknowledgeDate = Date(timeIntervalSinceNow: -600)
        let expectedDeclineDate = Date(timeIntervalSinceNow: -600)

        databasePreparer.save {
            let groupConversation = databasePreparer.createConversation(
                typing: false,
                unreadMessageCount: 0,
                visibility: .default,
                complete: { conversation in
                    conversation.groupID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.groupIDLength)!
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

        baseMessage.userack = true
        XCTAssertEqual(expectedSentDate, baseMessage.displayDate)

        baseMessage.userackDate = expectedAcknowledgeDate
        XCTAssertEqual(expectedAcknowledgeDate, baseMessage.displayDate)

        baseMessage.userack = false
        baseMessage.userackDate = expectedDeclineDate
        XCTAssertEqual(expectedDeclineDate, baseMessage.displayDate)
    }
    
    // MARK: - Date for state
    
    func testDateForState() {
        var baseMessage: BaseMessage!
        
        let expectedDate = Date(timeIntervalSinceNow: -1000)
        let expectedSentDate = Date(timeIntervalSinceNow: -900)
        let expectedDeliveryDate = Date(timeIntervalSinceNow: -800)
        let expectedReadDate = Date(timeIntervalSinceNow: -700)
        let expectedAcknowledgeAndDeclineDate = Date(timeIntervalSinceNow: -600)

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
            baseMessage.userackDate = expectedAcknowledgeAndDeclineDate
        }
    
        XCTAssertNil(baseMessage.date(for: .none))
        XCTAssertEqual(expectedAcknowledgeAndDeclineDate, baseMessage.date(for: .userAcknowledged))
        XCTAssertEqual(expectedAcknowledgeAndDeclineDate, baseMessage.date(for: .userDeclined))
        XCTAssertNil(baseMessage.date(for: .sending))
        
        XCTAssertNil(baseMessage.date(for: .sent))
        baseMessage.sent = true
        XCTAssertEqual(expectedSentDate, baseMessage.date(for: .sent))
        
        XCTAssertEqual(expectedDeliveryDate, baseMessage.date(for: .delivered))
        XCTAssertEqual(expectedReadDate, baseMessage.date(for: .read))
        XCTAssertNil(baseMessage.date(for: .failed))
    }
}
