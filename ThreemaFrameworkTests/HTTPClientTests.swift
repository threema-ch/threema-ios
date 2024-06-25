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

import Foundation
import XCTest

@testable import ThreemaFramework

class HTTPClientTests: XCTestCase {

    // MARK: - Properties

    var sslCAHelperMock: SSLCAHelperMock!
    let sessionManager = URLSessionManager(with: TestSessionProvider())
    let expectedDomain = "www.example.com"
    let dummyAuthToken = "dummyAuthToken"
    let dummyData = Data("DummyData".utf8)

    var challenge: URLAuthenticationChallenge?

    override func setUp() {
        sslCAHelperMock = SSLCAHelperMock()
        challenge = URLAuthenticationChallenge(
            protectionSpace: URLProtectionSpace(
                host: expectedDomain,
                port: 80,
                protocol: "https",
                realm: nil,
                authenticationMethod: NSURLAuthenticationMethodServerTrust
            ),
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: AuthenticationChallengeSenderMock()
        )
    }

    // MARK: - Delete

    func testDeleteForOwnSafe() throws {
        // Arrange
        let expectation = expectation(description: "deleteOwnSafeExpectation")
        let url = URL(string: "\(expectedDomain)/deleteOwnSafe")!
        URLProtocolMock.mockResponses[url] = (
            (nil, nil, nil, challenge), { }
        )
        let httpClient = HTTPClientForOwnSafeServer()

        // Act
        httpClient.delete(url: url) { _, _, _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)

        // Assert
        let request = try XCTUnwrap(URLProtocolMock.requests[url])
        assertOwnSafeRequest(request: request)
        XCTAssertEqual(request.httpMethod, HTTPMethod.delete.rawValue)

        XCTAssertFalse(sessionManager.sessionStore.isEmpty)
        XCTAssertGreaterThan(sslCAHelperMock.handleCalls.count, 0)
        XCTAssertEqual(sslCAHelperMock.evaluateCalls.count, 0)
    }

    func testDeleteForThreemaSafe() throws {
        // Arrange
        let expectation = expectation(description: "deleteThreemaSafeExpectation")
        let url = URL(string: "\(expectedDomain)/deleteThreemaSafe")!
        URLProtocolMock.mockResponses[url] = (
            (nil, nil, nil, challenge), { }
        )
        let httpClient = HTTPClientForThreemaSafeServer()

        // Act
        httpClient.delete(url: url) { _, _, _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)

        // Assert
        let request = try XCTUnwrap(URLProtocolMock.requests[url])
        assertThreemaSafeRequest(request: request)
        XCTAssertEqual(request.httpMethod, HTTPMethod.delete.rawValue)

        XCTAssertFalse(sessionManager.sessionStore.isEmpty)
        XCTAssertGreaterThan(sslCAHelperMock.handleCalls.count, 0)
        XCTAssertEqual(sslCAHelperMock.evaluateCalls.count, 0)
    }

    // MARK: - Download

    func testDownloadForOwnSafe() throws {
        // Arrange
        let expectation = expectation(description: "downloadOwnSafeExpectation")
        let url = URL(string: "\(expectedDomain)/downloadOwnSafe")!
        URLProtocolMock.mockResponses[url] = (
            (nil, nil, nil, challenge), { }
        )
        let httpClient = HTTPClientForOwnSafeServer()

        // Act
        httpClient.downloadData(url: url, contentType: .octetStream) { _, _, _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)

        // Assert
        let request = try XCTUnwrap(URLProtocolMock.requests[url])
        assertOwnSafeRequest(request: request)
        XCTAssertEqual(request.httpMethod, HTTPMethod.get.rawValue)
        XCTAssertEqual(request.allHTTPHeaderFields?[HTTPHeaderField.accept.rawValue], ContentType.octetStream.rawValue)

        XCTAssertFalse(sessionManager.sessionStore.isEmpty)
        XCTAssertGreaterThan(sslCAHelperMock.handleCalls.count, 0)
        XCTAssertEqual(sslCAHelperMock.evaluateCalls.count, 0)
    }

    func testDownloadForThreemaSafe() throws {
        // Arrange
        let expectation = expectation(description: "downloadThreemaSafeExpectation")
        let url = URL(string: "\(expectedDomain)/downloadThreemaSafe")!
        URLProtocolMock.mockResponses[url] = (
            (nil, nil, nil, challenge), { }
        )
        let httpClient = HTTPClientForThreemaSafeServer()

        // Act
        httpClient.downloadData(url: url, contentType: .octetStream) { _, _, _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)

        // Assert
        let request = try XCTUnwrap(URLProtocolMock.requests[url])
        assertThreemaSafeRequest(request: request)
        XCTAssertEqual(request.httpMethod, HTTPMethod.get.rawValue)
        XCTAssertEqual(request.allHTTPHeaderFields?[HTTPHeaderField.accept.rawValue], ContentType.octetStream.rawValue)

        XCTAssertFalse(sessionManager.sessionStore.isEmpty)
        XCTAssertGreaterThan(sslCAHelperMock.handleCalls.count, 0)
        XCTAssertEqual(sslCAHelperMock.evaluateCalls.count, 0)
    }

    func testDownloadForGeneralHTTPClient() throws {
        // Arrange
        let expectation = expectation(description: "downloadGeneralClientExpectation")
        let url = URL(string: "\(expectedDomain)/downloadGeneralClient")!
        URLProtocolMock.mockResponses[url] = (
            (nil, nil, nil, challenge), { }
        )
        let httpClient = generalHTTPClient()

        // Act
        httpClient.downloadData(url: url, contentType: .octetStream) { _, _, _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)

        // Assert
        let request = try XCTUnwrap(URLProtocolMock.requests[url])
        XCTAssertEqual(request.httpMethod, HTTPMethod.get.rawValue)
        XCTAssertEqual(request.allHTTPHeaderFields?[HTTPHeaderField.userAgent.rawValue], "Threema")
        XCTAssertEqual(request.allHTTPHeaderFields?[HTTPHeaderField.accept.rawValue], ContentType.octetStream.rawValue)
        XCTAssertNil(request.allHTTPHeaderFields?[HTTPHeaderField.authorization.rawValue])
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalAndRemoteCacheData)
        XCTAssertTrue(request.allowsCellularAccess)

        XCTAssertFalse(sessionManager.sessionStore.isEmpty)
        XCTAssertGreaterThan(sslCAHelperMock.handleCalls.count, 0)
        XCTAssertEqual(sslCAHelperMock.evaluateCalls.count, 0)
    }

    // MARK: - Upload

    func testUploadForOwnSafe() throws {
        // Arrange
        let expectation = expectation(description: "uploadOwnSafeExpectation")
        let url = URL(string: "\(expectedDomain)/uploadOwnSafe")!
        URLProtocolMock.mockResponses[url] = (
            (nil, nil, nil, challenge), { }
        )
        let httpClient = HTTPClientForOwnSafeServer()

        // Act
        httpClient.uploadData(url: url, data: dummyData) { _, _, _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)

        // Assert
        let request = try XCTUnwrap(URLProtocolMock.requests[url])
        assertOwnSafeRequest(request: request)
        XCTAssertEqual(request.httpMethod, HTTPMethod.put.rawValue)
        XCTAssertEqual(
            request.allHTTPHeaderFields?[HTTPHeaderField.contentType.rawValue],
            ContentType.octetStream.rawValue
        )

        XCTAssertFalse(sessionManager.sessionStore.isEmpty)
        XCTAssertGreaterThan(sslCAHelperMock.handleCalls.count, 0)
        XCTAssertEqual(sslCAHelperMock.evaluateCalls.count, 0)
    }

    func testUploadForThreemaSafe() throws {
        // Arrange
        let expectation = expectation(description: "uploadThreemaSafeExpectation")
        let url = URL(string: "\(expectedDomain)/uploadThreemaSafe")!
        URLProtocolMock.mockResponses[url] = (
            (nil, nil, nil, challenge), { }
        )
        let httpClient = HTTPClientForThreemaSafeServer()

        // Act
        httpClient.uploadData(url: url, data: dummyData) { _, _, _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)

        // Assert
        let request = try XCTUnwrap(URLProtocolMock.requests[url])
        assertThreemaSafeRequest(request: request)
        XCTAssertEqual(request.httpMethod, HTTPMethod.put.rawValue)
        XCTAssertEqual(
            request.allHTTPHeaderFields?[HTTPHeaderField.contentType.rawValue],
            ContentType.octetStream.rawValue
        )

        XCTAssertFalse(sessionManager.sessionStore.isEmpty)
        XCTAssertGreaterThan(sslCAHelperMock.handleCalls.count, 0)
        XCTAssertEqual(sslCAHelperMock.evaluateCalls.count, 0)
    }

    func testUploadMultipart() throws {
        // Arrange
        let expectation = expectation(description: "uploadMultipart")
        let dummyTaskDescription = "dummyTaskDescription"
        let url = URL(string: "\(expectedDomain)/uploadMultipart")!
        let boundary = "---------------------------Boundary_Line"
        let contentType = String(format: "multipart/form-data; boundary=%@", boundary)

        URLProtocolMock.mockResponses[url] = (
            (nil, nil, nil, challenge), { }
        )
        let httpClient = HTTPClientForThreemaSafeServer()

        // Act
        let task = httpClient.uploadDataMultipart(
            taskDescription: dummyTaskDescription,
            url: url,
            contentType: contentType,
            data: dummyData,
            delegate: httpClient
        ) { _, _, _, _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)

        // Assert
        let request = try XCTUnwrap(URLProtocolMock.requests[url])
        assertThreemaSafeRequest(request: request)
        XCTAssertEqual(request.httpMethod, HTTPMethod.post.rawValue)
        XCTAssertEqual(
            request.allHTTPHeaderFields?[HTTPHeaderField.contentType.rawValue],
            contentType
        )
        XCTAssertEqual(dummyTaskDescription, task.taskDescription)

        XCTAssertFalse(sessionManager.sessionStore.isEmpty)
        XCTAssertGreaterThan(sslCAHelperMock.handleCalls.count, 0)
        XCTAssertEqual(sslCAHelperMock.evaluateCalls.count, 0)
    }

    // MARK: - Batch Assertion Functions

    private func assertOwnSafeRequest(request: URLRequest) {
        XCTAssertEqual(request.allHTTPHeaderFields?[HTTPHeaderField.userAgent.rawValue], "Threema")
        XCTAssertNil(request.allHTTPHeaderFields?[HTTPHeaderField.authorization.rawValue])
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalAndRemoteCacheData)
        XCTAssertTrue(request.allowsCellularAccess)
    }

    private func assertThreemaSafeRequest(request: URLRequest) {
        XCTAssertEqual(request.allHTTPHeaderFields?[HTTPHeaderField.userAgent.rawValue], "Threema")
        XCTAssertEqual(request.allHTTPHeaderFields?[HTTPHeaderField.authorization.rawValue], dummyAuthToken)
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalAndRemoteCacheData)
        XCTAssertTrue(request.allowsCellularAccess)
    }

    // MARK: - Helpers

    private func HTTPClientForOwnSafeServer() -> HTTPClient {
        HTTPClient(
            authorization: nil,
            user: "testUser",
            password: "testPassword",
            sessionManager: sessionManager,
            sslCAHelper: sslCAHelperMock
        )
    }

    private func HTTPClientForThreemaSafeServer() -> HTTPClient {
        HTTPClient(
            authorization: dummyAuthToken,
            user: nil,
            password: nil,
            sessionManager: sessionManager,
            sslCAHelper: sslCAHelperMock
        )
    }

    private func generalHTTPClient() -> HTTPClient {
        HTTPClient(
            authorization: nil,
            user: nil,
            password: nil,
            sessionManager: sessionManager,
            sslCAHelper: sslCAHelperMock
        )
    }
}
