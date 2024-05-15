//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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

class BlobDownloaderTests: XCTestCase {

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
            (nil, testData, response),
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
