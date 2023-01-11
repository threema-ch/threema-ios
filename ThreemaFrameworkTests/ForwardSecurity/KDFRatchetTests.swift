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

class KDFRatchetTests: XCTestCase {
    let initialChainKey = Data(
        BytesUtility
            .toBytes(hexString: "421e73cf324785dee4c4830f2efbb8cd4b258ed8520a608a6ce340aaa7400024")!
    )
    let expectedEncryptionKey1 = Data(
        BytesUtility
            .toBytes(hexString: "60d3de2d849fa8b3d9799e8e50b09a7ef1d4e1e855c99fdb711bfe29466cdad3")!
    )
    let expectedEncryptionKey100 = Data(
        BytesUtility
            .toBytes(hexString: "d2acf6e1c7262eb360ad92b6a74e0f9ad6ee129278742fc2462ae72916eaa334")!
    )
    let tooManyTurns = 1_000_000
    
    override func setUp() {
        continueAfterFailure = false
    }
    
    func testTurnOnce() {
        let ratchet = KDFRatchet(counter: 0, initialChainKey: initialChainKey)
        ratchet.turn()
        
        XCTAssertEqual(ratchet.counter, 1)
        XCTAssertEqual(ratchet.currentEncryptionKey, expectedEncryptionKey1)
    }
    
    func testTurnMany() throws {
        let ratchet = KDFRatchet(counter: 0, initialChainKey: initialChainKey)
        let numTurns = try ratchet.turnUntil(targetCounterValue: 100)
        
        XCTAssertEqual(numTurns, 100)
        XCTAssertEqual(ratchet.counter, 100)
        XCTAssertEqual(ratchet.currentEncryptionKey, expectedEncryptionKey100)
    }
    
    func testTurnTooMany() {
        let ratchet = KDFRatchet(counter: 0, initialChainKey: initialChainKey)
        XCTAssertThrowsError(try ratchet.turnUntil(targetCounterValue: UInt64(tooManyTurns)))
    }
}
