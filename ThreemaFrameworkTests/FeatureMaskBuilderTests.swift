import XCTest
@testable import ThreemaFramework

final class FeatureMaskBuilderTests: XCTestCase {

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema") // THREEMA_GROUP_IDENTIFIER @"group.ch.threema"
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testForwardSecurityEnabled() throws {
        // Copied from previous implementation of FeatureMask
        let goldVal = 0x7F
        
        XCTAssertTrue(FeatureMaskBuilder.upToVideoCalls().forwardSecurity(enabled: true).build() ^ goldVal == 0)
    }
    
    func testForwardSecurityDisabled() throws {
        // Copied from previous implementation of FeatureMask
        let goldVal = 0x3F
        
        XCTAssertTrue(FeatureMaskBuilder.upToVideoCalls().forwardSecurity(enabled: false).build() ^ goldVal == 0)
    }
}
