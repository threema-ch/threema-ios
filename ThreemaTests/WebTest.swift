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

class WebTest: XCTestCase {
    override func setUp() {
        super.setUp()
        
        // necessary for ValidationLogger
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testIsWebHostAllowedNo() {
        XCTAssertFalse(WCSessionManager.isWebHostAllowed(scannedHostName: "threema.ch", whiteList: "example.com"))
        XCTAssertFalse(WCSessionManager.isWebHostAllowed(scannedHostName: "x.example.com", whiteList: "example.com"))
        XCTAssertFalse(WCSessionManager.isWebHostAllowed(scannedHostName: "x.example", whiteList: "*.example.com"))
    }
    
    func testIsWebHostAllowedNoEmptyList() {
        XCTAssertFalse(WCSessionManager.isWebHostAllowed(scannedHostName: "example.com", whiteList: ""))
    }
    
    func testIsWebHostAllowedYesExact() {
        XCTAssertTrue(WCSessionManager.isWebHostAllowed(scannedHostName: "example.com", whiteList: "example.com"))
        XCTAssertTrue(
            WCSessionManager
                .isWebHostAllowed(scannedHostName: "x.example.com", whiteList: "example.com, x.example.com")
        )
    }
        
    func testIsWebHostAllowedYesPrefixMatch() {
        XCTAssertTrue(
            WCSessionManager
                .isWebHostAllowed(scannedHostName: "x.example.com", whiteList: "example.com, *.example.com")
        )
        XCTAssertTrue(
            WCSessionManager
                .isWebHostAllowed(scannedHostName: "xyz.example.com", whiteList: "example.com, *.example.com")
        )
        XCTAssertTrue(
            WCSessionManager
                .isWebHostAllowed(scannedHostName: "x.y.example.com", whiteList: "example.com, *.example.com")
        )
    }
}
