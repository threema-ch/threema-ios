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

final class IDColorTests: XCTestCase {
        
    func testIDColorECHOECHO() throws {
        let identity = "ECHOECHO"
        let expectedColor = UIColor.IDColor.green
        
        let actualColor = IDColor.forData(Data(identity.utf8))
        // This should use the cache of `IDColor`
        let actualColorCached = IDColor.forData(Data(identity.utf8))
        
        XCTAssertEqual(actualColor, expectedColor)
        XCTAssertEqual(actualColorCached, expectedColor)
    }
    
    func testIDColorABCD1234() throws {
        let identity = "ABCD1234"
        let expectedColor = UIColor.IDColor.orange
        
        let actualColor = IDColor.forData(Data(identity.utf8))
        
        XCTAssertEqual(actualColor, expectedColor)
    }
}
