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

class BaseMessageStateTests: XCTestCase {
    
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
    
    // MARK: - messageState
    
    func testOwnState() {
        var baseMessage: BaseMessageEntity!
        
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
                sender: nil,
                remoteSentDate: nil
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
    }
    
    func testOtherState() {
        var baseMessage: BaseMessageEntity!
        
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
                sender: nil,
                remoteSentDate: Date(timeIntervalSinceNow: -100)
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
    }
}
