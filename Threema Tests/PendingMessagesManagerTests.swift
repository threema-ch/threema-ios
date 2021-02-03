//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2021 Threema GmbH
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

@testable import Threema

class PendingMessagesManagerTests: XCTestCase {

    private var mockValidationLogger: ValidationLoggerMock?
    private var mockLogger: TestLoggerMock?
    
    private let testLogMessage: String = "PendingMessagesManager.pendingMessage: Some arguments invalid, no key or sender identity could be evaluated"

    override func setUp() {
        super.setUp()
        
        // necessary for ValidationLogger
        AppGroup.setGroupId("group.ch.threema") //THREEMA_GROUP_IDENTIFIER @"group.ch.threema"

        mockLogger = TestLoggerMock()
        DDLog.add(mockLogger!, with: .all)
    }

    override func tearDown() {
        DDLog.remove(mockLogger!)
    }

    func testPendingMessageAllNil() {
        let pm = PendingMessagesManager.shared

        pm.pendingMessage(senderId: nil, messageId: nil, abstractMessage: nil, threemaDict: nil, completion: { pendingMessage in })

        DDLog.flushLog()
        XCTAssertEqual(testLogMessage, mockLogger!.getTestLogMessage()?.message)
    }

    func testPendingMessageNothingNil() {
        let am: AbstractMessage = AbstractMessage()
        am.fromIdentity = "FROM-ID"
        
        let pm = PendingMessagesManager.shared
        pm.pendingMessage(senderId: "SENDER-ID", messageId: "msgid123", abstractMessage: am, threemaDict: nil, completion: { pendingMessage in
            
            XCTAssertNotNil(pendingMessage)
            XCTAssertEqual("FROM-ID", pendingMessage!.key.prefix(7))
        })
        
        DDLog.flushLog()
        XCTAssertNotEqual(testLogMessage, mockLogger!.getTestLogMessage()?.message)
    }

    func testPendingMessageSenderIdNilAndAbstractMessageNil() {
        let pm = PendingMessagesManager.shared
        pm.pendingMessage(senderId: nil, messageId: "msgid123", abstractMessage: nil, threemaDict: nil, completion: { pendingMessage in })

        DDLog.flushLog()
        XCTAssertEqual(testLogMessage, mockLogger!.getTestLogMessage()?.message)
    }
    
    func testPendingMessageMessageIdNilAndAbstractMessageNil() {
        let pm = PendingMessagesManager.shared
        pm.pendingMessage(senderId: "SENDER-ID", messageId: nil, abstractMessage: nil, threemaDict: nil, completion: { pendingMessage in })
        
        DDLog.flushLog()
        XCTAssertEqual(testLogMessage, mockLogger!.getTestLogMessage()?.message)
    }
    
    /* This crash -> is abstractMessage nil, must be threemaDict NOT nil !?!?
    func testPendingMessageAbstractMessageNil() {
        let pm = PendingMessagesManager.shared
        pm.pendingMessage(senderId: "SENDER-ID", messageId: "msgid123", abstractMessage: nil, threemaDict: nil, validationLogger: self.mockValidationLogger!, completion: { pendingMessage in
            
            XCTAssertNotNil(pendingMessage)
            XCTAssertEqual("FROM-IDmsgid123", pendingMessage!.key.prefix(7))
        })
        
        XCTAssertNotNil(pm)
    }
    */
}
