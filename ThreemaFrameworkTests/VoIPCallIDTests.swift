//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2024 Threema GmbH
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

class VoIPCallIDTests: XCTestCase {
    override func setUp() {
        super.setUp()
        
        // necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testNegativeCallID() {
        let callID = VoIPCallID(callID: -1 as? UInt32)
        XCTAssertEqual(0, callID.callID)
    }
    
    func testToBigCallID() {
        let callID = VoIPCallID(callID: 99_999_999_999 as? UInt32)
        XCTAssertEqual(0, callID.callID)
    }
    
    func testShortCallID() {
        let callID = VoIPCallID(callID: 3)
        XCTAssertEqual(3, callID.callID)
    }
    
    func testBigCallID() {
        let callID = VoIPCallID(callID: 2_594_350_554)
        XCTAssertEqual(2_594_350_554, callID.callID)
    }
    
    func testRandomCallID() {
        let random = UInt32.random(in: 0...UInt32.max)
        let callID = VoIPCallID(callID: random)
        XCTAssertEqual(random, callID.callID)
    }
}
