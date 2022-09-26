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
@testable import ThreemaFramework

class MultiDeviceKeyTests: XCTestCase {

    func testDerive() {
        
        let sk: [UInt8] = [
            0x1B, 0x35, 0xED, 0x7E, 0x1B, 0xA9, 0x99, 0x31,
            0x71, 0xFE, 0x4A, 0x7E, 0xED, 0x30, 0xC2, 0x83,
            0x19, 0x05, 0xC3, 0xA5, 0x83, 0x61, 0x6D, 0x61,
            0xE9, 0x37, 0x82, 0xDA, 0x90, 0x0B, 0xF8, 0xBA,
        ]
        
        XCTAssertEqual(
            BytesUtility.toHexString(bytes: sk),
            "1b35ed7e1ba9993171fe4a7eed30c2831905c3a583616d61e93782da900bf8ba"
        )
        
        let multiDeviceKey = MultiDeviceKey()
        let key = multiDeviceKey.derive(secretKey: Data(sk))
        
        XCTAssertEqual(key!.hexString, "3d00651cc9ba39d5c03d235a5f5b895a7ff0505fc732f391998777aad32e2cf6")
    }
    
    func testSecretKeyTooSmall() {
        let sk: [UInt8] = [
            0x1B, 0x35, 0xED, 0x7E, 0x1B, 0xA9, 0x99, 0x31,
            0x71, 0xFE, 0x4A, 0x7E, 0xED, 0x30, 0xC2, 0x83,
            0x19, 0x05, 0xC3, 0xA5, 0x83, 0x61, 0x6D, 0x61,
            0xE9, 0x37, 0x82, 0xDA, 0x90, 0x0B, 0xF8,
        ]

        let multiDeviceKey = MultiDeviceKey()
        let key = multiDeviceKey.derive(secretKey: Data(sk))
        
        XCTAssertNil(key)
    }

    func testSecretKeyTooBig() {
        let sk: [UInt8] = [
            0x1B, 0x35, 0xED, 0x7E, 0x1B, 0xA9, 0x99, 0x31,
            0x71, 0xFE, 0x4A, 0x7E, 0xED, 0x30, 0xC2, 0x83,
            0x19, 0x05, 0xC3, 0xA5, 0x83, 0x61, 0x6D, 0x61,
            0xE9, 0x37, 0x82, 0xDA, 0x90, 0x0B, 0xF8, 0xBA, 0xBA,
        ]

        let multiDeviceKey = MultiDeviceKey()
        let key = multiDeviceKey.derive(secretKey: Data(sk))
        
        XCTAssertNil(key)
    }

    func testDeriveMany() {
        let multiDeviceKey = MultiDeviceKey()

        // Load test vectors file
        let testVectors = ResourceLoader.contentAsString("test-vectors-threema", "csv")
        
        if let lines = testVectors?.split(separator: "\n") {
            for line in lines {
                if line.elementsEqual("key,mk,mpk") {
                    continue
                }
                
                let values = line.split(separator: ",")
                let key = BytesUtility.toBytes(hexString: String(values[0]))!
                let mpk = BytesUtility.toBytes(hexString: String(values[2]))!

                let result = multiDeviceKey.derive(secretKey: Data(bytes: key, count: key.count))
                
                XCTAssertEqual(result, Data(mpk))
            }
        }
    }
}
