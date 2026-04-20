import XCTest
@testable import ThreemaFramework

final class URLSessionTests: XCTestCase {
    
    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    // MARK: - URLSessionProvider

    func testDefaultSessionImplementation() throws {
        let configuration = TestSessionProvider().defaultSession().configuration

        XCTAssertTrue(configuration.allowsCellularAccess)
        XCTAssertNil(configuration.urlCache)
        XCTAssertNil(configuration.urlCredentialStorage)
    }
}
