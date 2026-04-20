import XCTest

@testable import Threema

final class WebTest: XCTestCase {
    override func setUp() {
        super.setUp()
        
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testIsWebHostAllowedNo() {
        XCTAssertFalse(WCSessionManager.isWebHostAllowed(scannedHostName: "threema.com", whiteList: "example.com"))
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
