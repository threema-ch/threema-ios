import ThreemaEssentials
import XCTest
@testable import ThreemaFramework

final class BlobDownloaderTests: XCTestCase {

    override func setUpWithError() throws {
        AppGroup.setGroupID("group.ch.threema")
    }

    override func tearDownWithError() throws { }

    func testBasicAsyncDownload() async throws {
        
        // Arrange
        let urlString = "https://example.com"
        let blobID = try XCTUnwrap(BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength))
        let testData = Data("Test Data".utf8)
        let objectID = NSManagedObjectID()
        
        let blobURL = BlobURL(
            serverConnector: ServerConnectorMock(),
            userSettings: UserSettingsMock(),
            serverInfoProvider: ServerInfoProviderMock(baseURLString: urlString)
        )
        
        let expectation = expectation(description: "Download test data")
        
        // To test, we need a URL created by BlobURL
        var resolvedURL: URL!
        
        blobURL.download(blobID: blobID, origin: .public) { url, _ in
            guard let url else {
                XCTFail("URL is nil")
                return
            }
            
            resolvedURL = url
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5)
        
        let response = HTTPURLResponse(url: resolvedURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        
        URLProtocolMock.mockResponses[resolvedURL] = (
            (nil, testData, response, nil),
            nil
        )
        
        // Act
        
        let downloader = BlobDownloader(
            blobURL: blobURL,
            sessionManager: URLSessionManager(with: TestSessionProvider())
        )
        let actualData = try await downloader.download(blobID: blobID, origin: .public, objectID: objectID)
        
        // Assert
        XCTAssertEqual(testData, actualData)
    }
}
