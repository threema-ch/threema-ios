import XCTest

@testable import ThreemaFramework

final class VoIPCallIDTests: XCTestCase {
    override func setUp() {
        super.setUp()
        
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testShortCallID() {
        let callID = VoIPCallID(callID: 3)
        XCTAssertEqual(3, callID.callID)
    }
    
    func testBigCallID() {
        let callID = VoIPCallID(callID: 2_594_350_554)
        XCTAssertEqual(2_594_350_554, callID.callID)
    }
    
    func testRandomCallID() {
        let random = UInt32.random(in: 0...UInt32.max)
        let callID = VoIPCallID(callID: random)
        XCTAssertEqual(random, callID.callID)
    }
}
