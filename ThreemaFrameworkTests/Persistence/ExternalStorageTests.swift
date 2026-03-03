//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2025 Threema GmbH
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

class ExternalStorageTests: XCTestCase {
    
    func testGetFilenameFromDescription() throws {
        let result = ExternalStorage
            .getFilename(
                description: "External Data Reference: <self = 0x6000028a72a0 ; path = 967F112E-0CBA-40C4-AFDD-60C291509994 ; length = 1893922>"
            )
        
        XCTAssertEqual(result, "967F112E-0CBA-40C4-AFDD-60C291509994")
    }

    func testGetFilenameFromDescriptionNilString() throws {
        let result = ExternalStorage
            .getFilename(
                description: "External Data Reference: <self = 0x6000028a72a0 ; path = nil ; length = 1893922>"
            )
        
        XCTAssertNil(result)
    }

    func testGetFilenameFromDescriptionNoPath() throws {
        let result = ExternalStorage
            .getFilename(
                description: "External Data Reference: <self = 0x6000028a72a0 ; pfad = 967F112E-0CBA-40C4-AFDD-60C291509994 ; length = 1893922>"
            )
        
        XCTAssertNil(result)
    }

    func testGetFilenameFromDescriptionNoEndSemicolon() throws {
        let result = ExternalStorage
            .getFilename(
                description: "External Data Reference: <self = 0x6000028a72a0 ; path = 967F112E-0CBA-40C4-AFDD-60C291509994 / length = 1893922>"
            )
        
        XCTAssertNil(result)
    }

    func testGetFilenameFromDescriptionEmpty() throws {
        let result = ExternalStorage.getFilename(description: "")
        
        XCTAssertNil(result)
    }
}
