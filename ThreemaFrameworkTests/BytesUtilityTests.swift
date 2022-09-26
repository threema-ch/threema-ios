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

class BytesUtilityTests: XCTestCase {
    
    private var testsByteHex: [[String: Any]]?
    
    private var testBytes: [[UInt8]]!
    private var expectedUInt8Pos7: [UInt8]!
    private var expectedUInt64LittleEndian: [UInt64]!
    private var expectedUInt64BigEndian: [UInt64]!
    
    override func setUp() {
        testsByteHex = [
            [
                "bytes": [
                    0x1B,
                    0x35,
                    0xED,
                    0x7E,
                    0x1B,
                    0xA9,
                    0x99,
                    0x31,
                    0x71,
                    0xFE,
                    0x4A,
                    0x7E,
                    0xED,
                    0x30,
                    0xC2,
                    0x83,
                    0x19,
                    0x05,
                    0xC3,
                    0xA5,
                    0x83,
                    0x61,
                    0x6D,
                    0x61,
                    0xE9,
                    0x37,
                    0x82,
                    0xDA,
                    0x90,
                    0x0B,
                    0xF8,
                    0xBA,
                ] as [UInt8],
                "hex": "1b35ed7e1ba9993171fe4a7eed30c2831905c3a583616d61e93782da900bf8ba",
            ],
            [
                "bytes": [
                    0x7C,
                    0xF1,
                    0xC4,
                    0x84,
                    0x7F,
                    0xB3,
                    0x2D,
                    0x6C,
                    0x37,
                    0x02,
                    0x74,
                    0x70,
                    0x18,
                    0xD0,
                    0xCC,
                    0xCD,
                    0xC2,
                    0xF7,
                    0x24,
                    0xC1,
                    0x15,
                    0xBF,
                    0xCA,
                    0x10,
                    0x36,
                    0xAE,
                    0x62,
                    0x08,
                    0xD2,
                    0xB7,
                    0xC6,
                    0x8C,
                ] as [UInt8],
                "hex": "7cf1c4847fb32d6c3702747018d0cccdc2f724c115bfca1036ae6208d2b7c68c",
            ],
            [
                "bytes": [
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                    0x00,
                ] as [UInt8],
                "hex": "0000000000000000000000000000000000000000000000000000000000000000",
            ],
        ]
        
        testBytes = [[0x01, 0x00, 0x01, 0x01, 0x01, 0x01, 0x01, 0xFE], [0x2E, 0xEE, 0x11, 0xD4, 0xFD, 0xF8, 0xF7, 0xA3]]
        expectedUInt64LittleEndian = [18_302_911_464_433_844_225, 11_815_185_916_498_144_814]
        expectedUInt64BigEndian = [72_058_697_861_366_270, 3_381_659_976_693_512_099]
        expectedUInt8Pos7 = [254, 163]
    }
    
    func testPaddingLengthToLess() {
        let result = BytesUtility.padding([0x00], pad: 0x00, length: 0)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result, [0x00])
    }
    
    func testPaddingSourceIsEmpty() {
        let result = BytesUtility.padding([UInt8](), pad: 0x00, length: 0)

        XCTAssertEqual(result.count, 0)
    }
    
    func testPaddingWithSource() {
        var result = BytesUtility.padding([UInt8]("threema".utf8), pad: 0x00, length: 16)
        
        XCTAssertEqual(result.count, 16)
        XCTAssertEqual(String(data: Data(bytes: result, count: 7), encoding: .utf8), "threema")

        result.removeSubrange(0..<8)
        XCTAssertEqual(result, [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
    }
    
    func testPaddingWithEmptySource() {
        let result = BytesUtility.padding([UInt8](), pad: 0x00, length: 8)
        
        XCTAssertEqual(result.count, 8)
        XCTAssertEqual(result, [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
    }
    
    func testPaddingRandom() {
        let padding = BytesUtility.paddingRandom()
        
        XCTAssertGreaterThanOrEqual(padding.count, 1)
        XCTAssertLessThanOrEqual(padding.count, 256)
        XCTAssertEqual(padding[0], padding.convert())
    }
    
    func testBytesToHexString() {
        for test in testsByteHex! {
            let result = BytesUtility.toHexString(bytes: test["bytes"] as! [UInt8])
            
            XCTAssertEqual(result, test["hex"] as! String)
        }
    }

    func testHexStringToBytes() {
        for test in testsByteHex! {
            let result = BytesUtility.toBytes(hexString: test["hex"] as! String)
            
            XCTAssertEqual(result, test["bytes"] as? [UInt8])
        }
    }

    func testSha1() {
        let sha1a = BytesUtility.sha1(data: Data([1]))
        let sha1b = BytesUtility.sha1(data: Data([1]))

        XCTAssertTrue(sha1a == sha1b)
    }

    func testGenerateRandomBytes() {
        let result = BytesUtility.generateRandomBytes(length: 24)
        
        XCTAssertEqual(result?.count, 24)
    }

    func testDataExtensionConvertToUInt64() {
        for run in 0..<testBytes.count {
            let data = Data(bytes: testBytes[run], count: 8)
            
            XCTAssertEqual(expectedUInt8Pos7[run], data.convert(at: 7) as UInt8)
            XCTAssertEqual(expectedUInt64LittleEndian[run], data.convert() as UInt64)

            XCTAssertEqual(expectedUInt64LittleEndian[run], data.convert(at: 0, endianess: .LittleEndian) as UInt64)
            XCTAssertEqual(expectedUInt64BigEndian[run], data.convert(at: 0, endianess: .BigEndian) as UInt64)
        }
    }
    
    func testConvertUInt64ToBytes() {
        for run in 0..<testBytes.count {
            let data = Data(bytes: testBytes[run], count: 8)
            
            let result = NSData.convertBytes(expectedUInt64LittleEndian[run])

            XCTAssertEqual(data, result)
        }
    }
    
    func testConvertBytesToUInt64AndBack() {
        for run in 0..<testBytes.count {
            let data = NSData(bytes: testBytes[run], length: 8)
            
            let result = data.convertUInt64()
            
            XCTAssertEqual(expectedUInt64LittleEndian[run], result)

            let resultData = NSData.convertBytes(result)!
            for i in 0...7 {
                XCTAssertEqual(testBytes[run][i], resultData[i])
            }
        }
    }
    
    func testConvertNSDataBytesToUInt64() {
        let idHex = "9e44815585a2331f"
        let idData = NSData(data: Data(BytesUtility.toBytes(hexString: idHex)!))
        
        let idUInt64: UInt64 = NSData.convertUInt64(idData)()
        
        let idDataResult: Data = NSData.convertBytes(idUInt64)
        let idHexResult: String = BytesUtility.toHexString(bytes: Array(idDataResult))
        
        XCTAssertEqual(idHex, idHexResult)
    }

    func testConvertDataBytesToUInt64() {
        let idHex = "9e44815585a2331f"
        let idData = Data(BytesUtility.toBytes(hexString: idHex)!)
        
        let idUInt64: UInt64 = idData.convert()
        
        let idDataResult: Data = NSData.convertBytes(idUInt64)
        let idHexResult: String = BytesUtility.toHexString(bytes: Array(idDataResult))

        XCTAssertEqual(idHex, idHexResult)
    }
}
