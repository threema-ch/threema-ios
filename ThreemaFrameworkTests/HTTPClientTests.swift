//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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

    let sslCAHelperMock = SSLCAHelperMock()
    let sessionManager = URLSessionManager(with: TestSessionProvider())

    let expectedDomain = "www.example.com"

    let expectedAuthToken = "authToken"

    let expectedUsername = "testUser"
    let expectedPassword = "testPassword"

    let expectedData = Data("data".utf8)

    private var ddLoggerMock: DDLoggerMock!

    override func setUpWithError() throws {
        ddLoggerMock = DDLoggerMock()
        DDTTYLogger.sharedInstance?.logFormatter = LogFormatterCustom()
        DDLog.add(ddLoggerMock)
    }

    override func tearDownWithError() throws {
        DDLog.remove(ddLoggerMock)
    }

    // MARK: - Delete

    func testDeleteForOwnSafe() throws {
        // Arrange
        let expectation = expectation(description: "deleteOwnSafeExpectation")
        let url = URL(string: "\(expectedDomain)/deleteOwnSafe")!
        let (httpClient, challenges) = httpClientAndChallengeForOwnSafeServer()
        URLProtocolMock.mockResponses[url] = (
            (nil, nil, nil, challenges), { }
        )

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

        XCTAssertTrue(
            ddLoggerMock.exists(
                message: "HttpClient authentication method: NSURLAuthenticationMethodHTTPBasic"
            )
        )
    }

    func testDeleteForThreemaSafe() throws {
        // Arrange
        let expectation = expectation(description: "deleteThreemaSafeExpectation")
        let url = URL(string: "\(expectedDomain)/deleteThreemaSafe")!
        let (httpClient, challenge) = httpClientAndChallengeForThreemaSafeServer()
        URLProtocolMock.mockResponses[url] = (
            (nil, nil, nil, challenge), { }
        )

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

        XCTAssertEqual(ddLoggerMock.logMessages.count, 0)
    }

    // MARK: - Download

    func testDownloadForOwnSafe() throws {
        // Arrange
        let expectation = expectation(description: "downloadOwnSafeExpectation")
        let url = URL(string: "\(expectedDomain)/downloadOwnSafe")!
        let (httpClient, challenge) = httpClientAndChallengeForOwnSafeServer()
        URLProtocolMock.mockResponses[url] = (
            (nil, nil, nil, challenge), { }
        )

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

        XCTAssertTrue(
            ddLoggerMock.exists(
                message: "HttpClient authentication method: NSURLAuthenticationMethodHTTPBasic"
            )
        )
    }

    func testDownloadForThreemaSafe() throws {
        // Arrange
        let expectation = expectation(description: "downloadThreemaSafeExpectation")
        let url = URL(string: "\(expectedDomain)/downloadThreemaSafe")!
        let (httpClient, challenge) = httpClientAndChallengeForThreemaSafeServer()
        URLProtocolMock.mockResponses[url] = (
            (nil, nil, nil, challenge), { }
        )

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

        XCTAssertEqual(ddLoggerMock.logMessages.count, 0)
    }

    func testDownloadForGeneralHTTPClient() throws {
        // Arrange
        let expectation = expectation(description: "downloadGeneralClientExpectation")
        let url = URL(string: "\(expectedDomain)/downloadGeneralClient")!
        let (httpClient, challenge) = generalHTTPClientAndChallenge()
        URLProtocolMock.mockResponses[url] = (
            (nil, nil, nil, challenge), { }
        )

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

        XCTAssertEqual(ddLoggerMock.logMessages.count, 0)
    }

    // MARK: - Upload

    func testUploadForOwnSafe() throws {
        // Arrange
        let expectation = expectation(description: "uploadOwnSafeExpectation")
        let url = URL(string: "\(expectedDomain)/uploadOwnSafe")!
        let (httpClient, challenge) = httpClientAndChallengeForOwnSafeServer()
        URLProtocolMock.mockResponses[url] = (
            (nil, nil, nil, challenge), { }
        )

        // Act
        httpClient.uploadData(url: url, data: expectedData) { _, _, _ in
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

        XCTAssertTrue(
            ddLoggerMock.exists(
                message: "HttpClient authentication method: NSURLAuthenticationMethodHTTPBasic"
            )
        )
    }

    func testUploadForThreemaSafe() throws {
        // Arrange
        let expectation = expectation(description: "uploadThreemaSafeExpectation")
        let url = URL(string: "\(expectedDomain)/uploadThreemaSafe")!
        let (httpClient, challenge) = httpClientAndChallengeForThreemaSafeServer()
        URLProtocolMock.mockResponses[url] = (
            (nil, nil, nil, challenge), { }
        )

        // Act
        httpClient.uploadData(url: url, data: expectedData) { _, _, _ in
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

        XCTAssertEqual(ddLoggerMock.logMessages.count, 0)
    }

    func testUploadMultipart() throws {
        // Arrange
        let expectation = expectation(description: "uploadMultipart")
        let dummyTaskDescription = "dummyTaskDescription"
        let url = URL(string: "\(expectedDomain)/uploadMultipart")!
        let boundary = "---------------------------Boundary_Line"
        let contentType = "multipart/form-data; boundary=\(boundary)"

        let (httpClient, challenge) = httpClientAndChallengeForThreemaSafeServer()
        URLProtocolMock.mockResponses[url] = (
            (nil, nil, nil, challenge), { }
        )

        // Act
        let task = httpClient.uploadDataMultipart(
            taskDescription: dummyTaskDescription,
            url: url,
            contentType: contentType,
            data: expectedData,
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

        XCTAssertEqual(ddLoggerMock.logMessages.count, 0)
    }

    // MARK: - URLSessionTaskDelegate Tests

    func testURLSessionTaskDidReceiveChallengeForOwnSafe() async {
        // Arrange
        let url = URL(string: "\(expectedDomain)")!
        let (httpClient, challenges) = httpClientAndChallengeForOwnSafeServer()
        let session = URLSession(configuration: .default)
        let task = session.dataTask(with: URLRequest(url: url))

        // Act
        let (challengeDisposition, credentials) = await httpClient.urlSession(
            session,
            task: task,
            didReceive: challenges.first(where: {
                $0.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic
            })!
        )

        // Assert
        XCTAssertEqual(challengeDisposition, .useCredential)
        XCTAssertEqual(credentials?.user, expectedUsername)
    }

    func testURLSessionTaskDidReceiveChallengeForThreemaSafe() async {
        // Arrange
        let url = URL(string: "\(expectedDomain)")!
        let (httpClient, challenges) = httpClientAndChallengeForThreemaSafeServer()
        let session = URLSession(configuration: .default)
        let task = session.dataTask(with: URLRequest(url: url))

        // Act
        let (challengeDisposition, credentials) = await httpClient.urlSession(
            session,
            task: task,
            didReceive: challenges.first!
        )

        // Assert
        XCTAssertEqual(challengeDisposition, .performDefaultHandling)
        XCTAssertNil(credentials)
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
        XCTAssertEqual(request.allHTTPHeaderFields?[HTTPHeaderField.authorization.rawValue], expectedAuthToken)
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalAndRemoteCacheData)
        XCTAssertTrue(request.allowsCellularAccess)
    }

    // MARK: - Helpers

    private func httpClientAndChallengeForOwnSafeServer() -> (HTTPClient, [URLAuthenticationChallenge]) {
        let client = HTTPClient(
            authorization: nil,
            user: expectedUsername,
            password: expectedPassword,
            sessionManager: sessionManager,
            sslCAHelper: sslCAHelperMock
        )

        let challenges = [
            authenticationChallenge(authenticationMethod: NSURLAuthenticationMethodServerTrust),
            authenticationChallenge(authenticationMethod: NSURLAuthenticationMethodHTTPBasic),
        ]

        return (client, challenges)
    }

    private func httpClientAndChallengeForThreemaSafeServer() -> (HTTPClient, [URLAuthenticationChallenge]) {
        let client = HTTPClient(
            authorization: expectedAuthToken,
            user: nil,
            password: nil,
            sessionManager: sessionManager,
            sslCAHelper: sslCAHelperMock
        )

        let challenges = [
            authenticationChallenge(authenticationMethod: NSURLAuthenticationMethodServerTrust),
        ]

        return (client, challenges)
    }

    private func generalHTTPClientAndChallenge() -> (HTTPClient, [URLAuthenticationChallenge]) {
        let client = HTTPClient(
            authorization: nil,
            user: nil,
            password: nil,
            sessionManager: sessionManager,
            sslCAHelper: sslCAHelperMock
        )

        let challenges = [
            authenticationChallenge(authenticationMethod: NSURLAuthenticationMethodServerTrust),
        ]

        return (client, challenges)
    }

    private func authenticationChallenge(authenticationMethod: String) -> URLAuthenticationChallenge {
        URLAuthenticationChallenge(
            protectionSpace: URLProtectionSpace(
                host: expectedDomain,
                port: 80,
                protocol: "https",
                realm: nil,
                authenticationMethod: authenticationMethod
            ),
            proposedCredential: nil,
            previousFailureCount: 0,
            failureResponse: nil,
            error: nil,
            sender: AuthenticationChallengeSenderMock()
        )
    }
}
