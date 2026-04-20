import ThreemaEssentials
import XCTest

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
