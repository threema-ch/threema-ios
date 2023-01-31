//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

class ThreemaKDFTests: XCTestCase {
    // First three vectors taken from multidevice-kdf/test-vectors-blake2b.csv
    static let testVectors: [TestVector] = [
        TestVector(
            secretKey: "101692161c717bc3fe893b3dbcfe7424c725fd06624940a1046895fb83960240",
            salt: "492e",
            personal: "a390519d083d07c5",
            derived: "ae810e70c16cc45692c1d4fedf323ca2ca0218d90dc0f969ab1a7aeb6d3039a8"
        ),
        TestVector(
            secretKey: "f8e2fcb4369c164e1cdfff82cb7a2c970f1b9a1553c143bf6aef588c1343c2da",
            salt: "aaf4ad",
            personal: "9f4c909b3b27f8e5",
            derived: "5f316d0be440fc40b60bd1c90aab60f1de6f9e2de57d9d0f24b3a3fa02eda76a"
        ),
        TestVector(
            secretKey: "88f7c68a72c76747494fec2d9783e2948906d86b2458818b7e9ee7fce856cb72",
            salt: "00",
            personal: "ef2a504bdb217992",
            derived: "b4da86a0622262e4f8f8bce44aa6a3ee994b61997c1895af2803a98901914cc0"
        ),
    ]
    
    func testDeriveKey() {
        for testVector in ThreemaKDFTests.testVectors {
            let kdf = ThreemaKDF(personal: testVector.personal)
            let derived = kdf.deriveKey(salt: testVector.salt, key: testVector.secretKey)
            XCTAssertEqual(derived, testVector.derived)
        }
    }
    
    func testBlake2bSelfTest() {
        XCTAssertEqual(0, ThreemaKDF.blake2bSelfTest())
    }
    
    func testBlake2bHash() {
        // From https://raw.githubusercontent.com/BLAKE2/BLAKE2/master/testvectors/blake2-kat.json
        let data = Data(
            BytesUtility
                .toBytes(hexString: "000102030405060708090a0b0c0d0e0f")!
        )
        let expectedDigest = Data(
            BytesUtility
                .toBytes(
                    hexString: "bfbabbef45554ccfa0dc83752a19cc35d5920956b301d558d772282bc867009168e9e98606bb5ba73a385de5749228c925a85019b71f72fe29b3cd37ca52efe6"
                )!
        )
        let digest = ThreemaKDF.hash(input: data, outputLen: 64)!
        XCTAssertEqual(digest, expectedDigest)
    }
}

class TestVector {
    let secretKey: Data
    let salt: Data
    let personal: Data
    let derived: Data
    
    init(secretKey: String, salt: String, personal: String, derived: String) {
        self.secretKey = Data(BytesUtility.toBytes(hexString: secretKey)!)
        self.salt = Data(BytesUtility.toBytes(hexString: salt)!)
        self.personal = Data(BytesUtility.toBytes(hexString: personal)!)
        self.derived = Data(BytesUtility.toBytes(hexString: derived)!)
    }
}
