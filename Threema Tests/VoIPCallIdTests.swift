//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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

class VoIPCallIdTests: XCTestCase {
    override func setUp() {
        super.setUp()
        
        // necessary for ValidationLogger
        AppGroup.setGroupId("group.ch.threema") //THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testNegativeCallId() -> Void {
        let callId = VoIPCallId(callId: -1 as? UInt32)
        XCTAssertEqual(0, callId.callId)
    }
    
    func testToBigCallId() -> Void {
        let callId = VoIPCallId(callId: 99999999999 as? UInt32)
        XCTAssertEqual(0, callId.callId)
    }
    
    func testShortCallId() -> Void {
        let callId = VoIPCallId(callId: 3)
        XCTAssertEqual(3, callId.callId)
    }
    
    func testBigCallId() -> Void {
        let callId = VoIPCallId(callId: 2594350554)
        XCTAssertEqual(2594350554, callId.callId)
    }
    
    func testRandomCallId() -> Void {
        let random = UInt32.random(in: 0 ... UInt32.max)
        let callId = VoIPCallId(callId: random)
        XCTAssertEqual(random, callId.callId)
    }
}
