//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

class BaseMessageStateTests: XCTestCase {
    
    private var databasePreparer: DatabasePreparer!
    private var conversation: Conversation!

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")
        
        let (_, managedObjectContext, _) = DatabasePersistentContext.devNullContext()
        
        databasePreparer = DatabasePreparer(context: managedObjectContext)
        databasePreparer.save {
            conversation = databasePreparer.createConversation(
                marked: false,
                typing: false,
                unreadMessageCount: 0,
                complete: nil
            )
        }
    }
    
    // MARK: - old_messageState (deprecated)
    
    func testOldOwnMessageState() {
        var baseMessage: BaseMessage!
        
        databasePreparer.save {
            baseMessage = databasePreparer.createTextMessage(
                conversation: conversation,
                text: "Hello World",
                date: Date(),
                delivered: false,
                id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                isOwn: true,
                read: false,
                sent: false,
                userack: false,
                sender: nil
            )
        }
        
        XCTAssertEqual(MESSAGE_STATE_SENDING, baseMessage.old_messageState)
        
        baseMessage.sent = true
        XCTAssertEqual(MESSAGE_STATE_SENT, baseMessage.old_messageState)
        
        baseMessage.delivered = true
        XCTAssertEqual(MESSAGE_STATE_DELIVERED, baseMessage.old_messageState)

        baseMessage.read = true
        XCTAssertEqual(MESSAGE_STATE_READ, baseMessage.old_messageState)
        
        baseMessage.sendFailed = true
        XCTAssertEqual(MESSAGE_STATE_FAILED, baseMessage.old_messageState)
        
        baseMessage.userack = true
        XCTAssertEqual(MESSAGE_STATE_FAILED, baseMessage.old_messageState)
        
        baseMessage.userackDate = Date()
        XCTAssertEqual(MESSAGE_STATE_USER_ACK, baseMessage.old_messageState)

        baseMessage.userack = false
        XCTAssertEqual(MESSAGE_STATE_USER_DECLINED, baseMessage.old_messageState)
    }
    
    func testOldOtherMessageState() {
        var baseMessage: BaseMessage!
        
        databasePreparer.save {
            baseMessage = databasePreparer.createTextMessage(
                conversation: conversation,
                text: "Hello World",
                date: Date(),
                delivered: false,
                id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                isOwn: false,
                read: false,
                sent: false,
                userack: false,
                sender: nil
            )
        }
        
        XCTAssertEqual(MESSAGE_STATE_SENT, baseMessage.old_messageState)
        
        baseMessage.sent = true
        XCTAssertEqual(MESSAGE_STATE_SENT, baseMessage.old_messageState)
        
        baseMessage.delivered = true
        XCTAssertEqual(MESSAGE_STATE_SENT, baseMessage.old_messageState)

        baseMessage.read = true
        XCTAssertEqual(MESSAGE_STATE_SENT, baseMessage.old_messageState)
        
        baseMessage.sendFailed = true
        XCTAssertEqual(MESSAGE_STATE_SENT, baseMessage.old_messageState)
        
        baseMessage.userack = true
        XCTAssertEqual(MESSAGE_STATE_SENT, baseMessage.old_messageState)
        
        baseMessage.userackDate = Date()
        XCTAssertEqual(MESSAGE_STATE_USER_ACK, baseMessage.old_messageState)

        baseMessage.userack = false
        XCTAssertEqual(MESSAGE_STATE_USER_DECLINED, baseMessage.old_messageState)
    }
    
    // MARK: - messageState
    
    func testOwnState() {
        var baseMessage: BaseMessage!
        
        databasePreparer.save {
            baseMessage = databasePreparer.createTextMessage(
                conversation: conversation,
                text: "Hello World",
                date: Date(),
                delivered: false,
                id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                isOwn: true,
                read: false,
                sent: false,
                userack: false,
                sender: nil
            )
        }
        
        XCTAssertEqual(.sending, baseMessage.messageState)
        
        baseMessage.sent = true
        XCTAssertEqual(.sent, baseMessage.messageState)
        
        baseMessage.delivered = true
        XCTAssertEqual(.delivered, baseMessage.messageState)

        baseMessage.read = true
        XCTAssertEqual(.read, baseMessage.messageState)
        
        baseMessage.sendFailed = true
        XCTAssertEqual(.failed, baseMessage.messageState)
        
        baseMessage.userack = true
        XCTAssertEqual(.failed, baseMessage.messageState)
        
        baseMessage.userackDate = Date()
        XCTAssertEqual(.userAcknowledged, baseMessage.messageState)

        baseMessage.userack = false
        XCTAssertEqual(.userDeclined, baseMessage.messageState)
    }
    
    func testOtherState() {
        var baseMessage: BaseMessage!
        
        databasePreparer.save {
            baseMessage = databasePreparer.createTextMessage(
                conversation: conversation,
                text: "Hello World",
                date: Date(),
                delivered: false,
                id: BytesUtility.generateRandomBytes(length: ThreemaProtocol.messageIDLength)!,
                isOwn: false,
                read: false,
                sent: false,
                userack: false,
                sender: nil
            )
        }
        
        XCTAssertEqual(.received, baseMessage.messageState)
        
        baseMessage.sent = true
        XCTAssertEqual(.received, baseMessage.messageState)
        
        baseMessage.delivered = true
        XCTAssertEqual(.received, baseMessage.messageState)

        baseMessage.read = true
        XCTAssertEqual(.read, baseMessage.messageState)
        
        baseMessage.sendFailed = true
        XCTAssertEqual(.read, baseMessage.messageState)
        
        baseMessage.userack = true
        XCTAssertEqual(.read, baseMessage.messageState)
        
        baseMessage.userackDate = Date()
        XCTAssertEqual(.userAcknowledged, baseMessage.messageState)

        baseMessage.userack = false
        XCTAssertEqual(.userDeclined, baseMessage.messageState)
    }
}
    