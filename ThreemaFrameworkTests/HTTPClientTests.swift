//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

class HTTPClientTests: XCTestCase {
   
    // MARK: - Properties
    
    let sessionManager = URLSessionManager(with: TestSessionProvider())
    let dummyAuthToken = "dummyAuthToken"
    let dummyData = "DummyData".data(using: .utf8)!

    // MARK: - Delete

    func testDeleteForOwnSafe() throws {
        // Arrange
        let expectation = expectation(description: "deleteOwnSafeExpectation")
        let url = URL(string: "www.example.com/deleteOwnSafe")!
        URLProtocolMock.mockResponses[url] = (
            (nil, nil, nil), { }
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
    }
    
    func testDeleteForThreemaSafe() throws {
        // Arrange
        let expectation = expectation(description: "deleteThreemaSafeExpectation")
        let url = URL(string: "www.example.com/deleteThreemaSafe")!
        URLProtocolMock.mockResponses[url] = (
            (nil, nil, nil), { }
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
        
        XCTAssertTrue(sessionManager.sessionStore.isEmpty)
    }
    
    // MARK: - Download
    
    func testDownloadForOwnSafe() throws {
        // Arrange
        let expectation = expectation(description: "downloadOwnSafeExpectation")
        let url = URL(string: "www.example.com/downloadOwnSafe")!
        URLProtocolMock.mockResponses[url] = (
            (nil, nil, nil), { }
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
    }
    
    func testDownloadForThreemaSafe() throws {
        // Arrange
        let expectation = expectation(description: "downloadThreemaSafeExpectation")
        let url = URL(string: "www.example.com/downloadThreemaSafe")!
        URLProtocolMock.mockResponses[url] = (
            (nil, nil, nil), { }
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
        
        XCTAssertTrue(sessionManager.sessionStore.isEmpty)
    }
    
    func testDownloadForGeneralHTTPClient() throws {
        // Arrange
        let expectation = expectation(description: "downloadGeneralClientExpectation")
        let url = URL(string: "www.example.com/downloadGeneralClient")!
        URLProtocolMock.mockResponses[url] = (
            (nil, nil, nil), { }
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
        
        XCTAssertTrue(sessionManager.sessionStore.isEmpty)
    }
    
    // MARK: - Upload
    
    func testUploadForOwnSafe() throws {
        // Arrange
        let expectation = expectation(description: "uploadOwnSafeExpectation")
        let url = URL(string: "www.example.com/uploadOwnSafe")!
        URLProtocolMock.mockResponses[url] = (
            (nil, nil, nil), { }
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
    }
    
    func testUploadForThreemaSafe() throws {
        // Arrange
        let expectation = expectation(description: "uploadThreemaSafeExpectation")
        let url = URL(string: "www.example.com/uploadThreemaSafe")!
        URLProtocolMock.mockResponses[url] = (
            (nil, nil, nil), { }
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
        
        XCTAssertTrue(sessionManager.sessionStore.isEmpty)
    }
    
    func testUploadMultipart() throws {
        // Arrange
        let expectation = expectation(description: "uploadMultipart")
        let dummyTaskDescription = "dummyTaskDescription"
        let url = URL(string: "www.example.com/uploadMultipart")!
        let boundary = "---------------------------Boundary_Line"
        let contentType = String(format: "multipart/form-data; boundary=%@", boundary)
        
        URLProtocolMock.mockResponses[url] = (
            (nil, nil, nil), { }
        )
        let httpClient = HTTPClientForThreemaSafeServer()
        
        // Act
        let task = httpClient.uploadDataMultipart(
            taskDescription: dummyTaskDescription,
            url: url,
            contentType: contentType,
            data: dummyData,
            delegate: self
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
            user: "testUser",
            password: "testPassword",
            sessionManager: sessionManager
        )
    }
    
    private func HTTPClientForThreemaSafeServer() -> HTTPClient {
        HTTPClient(
            authorization: dummyAuthToken,
            sessionManager: sessionManager
        )
    }
    
    private func generalHTTPClient() -> HTTPClient {
        HTTPClient(sessionManager: sessionManager)
    }
}

// MARK: - URLSessionTaskDelegate

extension HTTPClientTests: URLSessionTaskDelegate { }
