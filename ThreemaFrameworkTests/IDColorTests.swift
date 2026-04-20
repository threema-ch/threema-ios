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
