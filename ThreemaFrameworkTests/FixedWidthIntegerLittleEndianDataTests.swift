//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

final class FixedWidthIntegerLittleEndianDataTests: XCTestCase {
    
    func testConvertUInt32() {
        let expectedData = Data([21, 97, 145, 126])
        
        let number: UInt32 = 2_123_456_789
        
        let actualData = number.littleEndianData
        
        XCTAssertEqual(actualData, expectedData)
    }
    
    func testConvertUInt64() {
        let expectedData = Data([0x01, 0x00, 0x01, 0x01, 0x01, 0x01, 0x01, 0xFE])
        
        let number: UInt64 = 18_302_911_464_433_844_225
        
        let actualData = number.littleEndianData
        
        XCTAssertEqual(actualData, expectedData)
    }
    
    func testConvertUInt642() {
        let expectedData = Data([0x2E, 0xEE, 0x11, 0xD4, 0xFD, 0xF8, 0xF7, 0xA3])
        
        let number: UInt64 = 11_815_185_916_498_144_814
        
        let actualData = number.littleEndianData
        
        XCTAssertEqual(actualData, expectedData)
    }
}
