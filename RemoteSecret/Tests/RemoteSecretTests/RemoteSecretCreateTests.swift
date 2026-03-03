//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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
import libthreemaSwift
import libthreemaSwiftTestHelper
import RemoteSecretProtocolTestHelper
import Testing
import ThreemaEssentials
@testable import RemoteSecret

@Suite("Remote Secret Create")
struct RemoteSecretCreateTests {
    let identity = "ABCDEFGH"
    let appInfo = AppInfo(
        version: "1.0",
        locale: "en/CH",
        deviceModel: "iPhone1,0",
        osVersion: "18.0"
    )
    let testURLString = "https://example.com"
    
    // MARK: Successes
        
    @Test("Basic successful poll")
    func basicPoll() async throws {
        // Basic values
        let expectedAuthenticationToken = Data(repeating: 2, count: 32)
        let expectedRemoteSecretHash = Data(repeating: 3, count: 32)
        let expectedIdentityHash = try deriveRemoteSecretHashForIdentity(
            remoteSecretHash: expectedRemoteSecretHash,
            userIdentity: identity
        )
        
        // Prepare
        
        let fakeRemoteSecretCreateResult = RemoteSecretCreateResult(
            remoteSecret: Data(repeating: 1, count: 32),
            remoteSecretAuthenticationToken: expectedAuthenticationToken,
            remoteSecretHash: expectedRemoteSecretHash
        )
        let remoteSecretCreateTaskMock = RemoteSecretCreateTaskMock(pollResponses: [
            .done(fakeRemoteSecretCreateResult),
        ])
        
        let sut = RemoteSecretCreate(
            appInfo: appInfo,
            maxNumberOfRetries: 0,
            createTaskResolver: TestingRemoteSecretCreateTaskResolver(
                answer: .success(remoteSecretCreateTaskMock)
            ),
            httpClient: RemoteSecretHTTPSClientMock()
        )
        
        // Run
        
        let (actualAuthenticationToken, actualIdentityHash) = try await sut.run(
            workServerBaseURL: testURLString,
            licenseUsername: "",
            licensePassword: "",
            identity: ThreemaIdentity(rawValue: identity),
            clientKey: Data(repeating: 4, count: 32)
        )
        
        // Validate
        
        #expect(actualAuthenticationToken == expectedAuthenticationToken)
        #expect(actualIdentityHash == expectedIdentityHash)
        #expect(remoteSecretCreateTaskMock.responses.wrappedValue.isEmpty == true)
    }
    
    @Test("Poll with request")
    func pollWithRequest() async throws {
        // Basic values
        let expectedAuthenticationToken = Data(repeating: 2, count: 32)
        let expectedRemoteSecretHash = Data(repeating: 3, count: 32)
        let expectedIdentityHash = try deriveRemoteSecretHashForIdentity(
            remoteSecretHash: expectedRemoteSecretHash,
            userIdentity: identity
        )
        
        // Prepare
        
        let fakeHTTPSRequest = HttpsRequest(
            timeout: 0,
            url: testURLString,
            method: .get,
            headers: [],
            body: Data()
        )
        let fakeRemoteSecretCreateResult = RemoteSecretCreateResult(
            remoteSecret: Data(repeating: 1, count: 32),
            remoteSecretAuthenticationToken: expectedAuthenticationToken,
            remoteSecretHash: expectedRemoteSecretHash
        )
        let remoteSecretCreateTaskMock = RemoteSecretCreateTaskMock(pollResponses: [
            .instruction(fakeHTTPSRequest),
            .done(fakeRemoteSecretCreateResult),
        ])
                
        let sut = RemoteSecretCreate(
            appInfo: appInfo,
            maxNumberOfRetries: 0,
            createTaskResolver: TestingRemoteSecretCreateTaskResolver(
                answer: .success(remoteSecretCreateTaskMock)
            ),
            httpClient: RemoteSecretHTTPSClientMock()
        )
        
        // Run
        
        let (actualAuthenticationToken, actualIdentityHash) = try await sut.run(
            workServerBaseURL: testURLString,
            licenseUsername: "",
            licensePassword: "",
            identity: ThreemaIdentity(rawValue: identity),
            clientKey: Data(repeating: 4, count: 32)
        )
        
        // Validate
        
        #expect(actualAuthenticationToken == expectedAuthenticationToken)
        #expect(actualIdentityHash == expectedIdentityHash)
        #expect(remoteSecretCreateTaskMock.responses.wrappedValue.count == 1)
    }
    
    @Test(
        "Poll with retry",
        arguments: [
            RemoteSecretSetupError.InvalidState(message: ""),
            .NetworkError(message: ""),
            .ServerError(message: ""),
            .RateLimitExceeded(message: ""),
        ]
    )
    func pollWithRetry(error: RemoteSecretSetupError) async throws {
        // Basic values
        let expectedAuthenticationToken = Data(repeating: 2, count: 32)
        let expectedRemoteSecretHash = Data(repeating: 3, count: 32)
        let expectedIdentityHash = try deriveRemoteSecretHashForIdentity(
            remoteSecretHash: expectedRemoteSecretHash,
            userIdentity: identity
        )
        
        // Prepare
        
        let fakeRemoteSecretCreateResult = RemoteSecretCreateResult(
            remoteSecret: Data(repeating: 1, count: 32),
            remoteSecretAuthenticationToken: expectedAuthenticationToken,
            remoteSecretHash: expectedRemoteSecretHash
        )
        let remoteSecretCreateTaskMock = RemoteSecretCreateTaskMock(pollResponses: [
            .error(error),
            .done(fakeRemoteSecretCreateResult),
        ])
        
        let sut = RemoteSecretCreate(
            appInfo: appInfo,
            maxNumberOfRetries: 2,
            retryWaitInterval: 0,
            createTaskResolver: TestingRemoteSecretCreateTaskResolver(
                answer: .success(remoteSecretCreateTaskMock)
            ),
            httpClient: RemoteSecretHTTPSClientMock()
        )
        
        // Run
        
        let (actualAuthenticationToken, actualIdentityHash) = try await sut.run(
            workServerBaseURL: testURLString,
            licenseUsername: "",
            licensePassword: "",
            identity: ThreemaIdentity(rawValue: identity),
            clientKey: Data(repeating: 4, count: 32)
        )
        
        // Validate
        
        #expect(actualAuthenticationToken == expectedAuthenticationToken)
        #expect(actualIdentityHash == expectedIdentityHash)
        #expect(remoteSecretCreateTaskMock.pollResponses.wrappedValue.isEmpty == true)
        #expect(remoteSecretCreateTaskMock.responses.wrappedValue.isEmpty == true)
    }
    
    // MARK: Errors
    
    @Test("Creation error")
    func creationError() async throws {
        // Prepare
        
        let remoteSecretCreateTaskResolver = TestingRemoteSecretCreateTaskResolver(
            answer: .failure(RemoteSecretSetupError.InvalidParameter(message: ""))
        )
        
        let sut = RemoteSecretCreate(
            appInfo: appInfo,
            maxNumberOfRetries: 0,
            createTaskResolver: remoteSecretCreateTaskResolver,
            httpClient: RemoteSecretHTTPSClientMock()
        )
        
        // Run & validate
        await #expect(throws: RemoteSecretManagerError.invalidParameter) {
            _ = try await sut.run(
                workServerBaseURL: testURLString,
                licenseUsername: "",
                licensePassword: "",
                identity: ThreemaIdentity(rawValue: identity),
                clientKey: Data(repeating: 0, count: 32)
            )
        }
    }
    
    @Test(
        "Error mapping",
        arguments: [
            (RemoteSecretSetupError.InvalidParameter(message: ""), RemoteSecretManagerError.invalidParameter),
            (.InvalidState(message: ""), .invalidState),
            (.NetworkError(message: ""), .networkError),
            (.ServerError(message: ""), .serverError),
            (.InvalidCredentials(message: ""), .invalidCredentials),
            (.RateLimitExceeded(message: ""), .exceededRateLimit),
        ]
    )
    func errorMapping(inputError: RemoteSecretSetupError, expectedError: RemoteSecretManagerError) async throws {
        // Prepare
        
        let remoteSecretCreateTaskMock = RemoteSecretCreateTaskMock(pollResponses: [
            .error(inputError),
        ])
                
        let sut = RemoteSecretCreate(
            appInfo: appInfo,
            maxNumberOfRetries: 0,
            createTaskResolver: TestingRemoteSecretCreateTaskResolver(
                answer: .success(remoteSecretCreateTaskMock)
            ),
            httpClient: RemoteSecretHTTPSClientMock()
        )
        
        // Run & validate
        await #expect(throws: expectedError) {
            _ = try await sut.run(
                workServerBaseURL: testURLString,
                licenseUsername: "",
                licensePassword: "",
                identity: ThreemaIdentity(rawValue: identity),
                clientKey: Data(repeating: 0, count: 32)
            )
        }
    }
}

// MARK: - Helper

private struct TestingRemoteSecretCreateTaskResolver: RemoteSecretCreateTaskResolver {
    enum Answer {
        case success(any RemoteSecretCreateTaskProtocol)
        case failure(RemoteSecretSetupError)
    }
    
    let answer: Answer
    
    func createNewTask(with context: RemoteSecretSetupContext) throws -> any RemoteSecretCreateTaskProtocol {
        switch answer {
        case let .success(remoteSecretCreateTaskProtocol):
            return remoteSecretCreateTaskProtocol
        case let .failure(error):
            throw error
        }
    }
}
