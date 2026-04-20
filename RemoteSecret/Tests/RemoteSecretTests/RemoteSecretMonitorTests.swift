import Foundation
import libthreemaSwift
import libthreemaSwiftTestHelper
import RemoteSecretProtocolTestHelper
import Testing
import ThreemaEssentials
@testable import RemoteSecret

@Suite("Remote Secret Monitor")
struct RemoteSecretMonitorTests {
    
    @Suite("Create and Start")
    struct CreateAndStartTests {
        
        @Test("Basic create and start")
        func basicCreateAndStart() async throws {
            // Prepare

            let expectedRemoteSecret = Data(repeating: 1, count: 32)
            
            let remoteSecretMonitorProtocolMock = RemoteSecretMonitorProtocolMock(pollResponses: [
                .schedule(timeout: 10, remoteSecret: expectedRemoteSecret),
                .error(.Blocked(message: "")), // We expect this to never execute, otherwise we'll crash
            ])
            
            let appInfo = AppInfo(
                version: "1.0",
                locale: "en/CH",
                deviceModel: "iPhone1,0",
                osVersion: "18.0"
            )
            
            let sut = await RemoteSecretMonitor(
                appInfo: appInfo,
                monitorProtocolResolver: TestingRemoteSecretMonitorProtocolResolver(
                    answer: .success(remoteSecretMonitorProtocolMock)
                ),
                httpClient: RemoteSecretHTTPSClientMock()
            )
            
            // Run
            
            let actualRemoteSecret = try await sut.createAndStart(
                workServerBaseURL: "https://example.com",
                identity: ThreemaIdentity("ABCDEFGH"),
                remoteSecretAuthenticationToken: Data(repeating: 2, count: 32),
                remoteSecretIdentityHash: Data(repeating: 3, count: 32)
            )
            
            // Validate
            
            #expect(actualRemoteSecret.rawValue == expectedRemoteSecret)
            // This expects that the test never runs more than 10s
            #expect(remoteSecretMonitorProtocolMock.pollResponses.wrappedValue.count == 1)
        }
        
        @Test("Retry initial fetch")
        func retryInitialFetch() async throws {
            // Prepare
            
            let expectedRemoteSecret = Data(repeating: 1, count: 32)
            
            let remoteSecretMonitorProtocolMock = RemoteSecretMonitorProtocolMock(pollResponses: [
                .schedule(timeout: 0, remoteSecret: nil),
                .schedule(timeout: 10, remoteSecret: expectedRemoteSecret),
                .error(.Blocked(message: "")), // We expect this to never execute, otherwise we'll crash
            ])
            
            let appInfo = AppInfo(
                version: "1.0",
                locale: "en/CH",
                deviceModel: "iPhone1,0",
                osVersion: "18.0"
            )
            
            let sut = await RemoteSecretMonitor(
                appInfo: appInfo,
                monitorProtocolResolver: TestingRemoteSecretMonitorProtocolResolver(
                    answer: .success(remoteSecretMonitorProtocolMock)
                ),
                httpClient: RemoteSecretHTTPSClientMock()
            )
            
            // Run
            
            let actualRemoteSecret = try await sut.createAndStart(
                workServerBaseURL: "https://example.com",
                identity: ThreemaIdentity("ABCDEFGH"),
                remoteSecretAuthenticationToken: Data(repeating: 2, count: 32),
                remoteSecretIdentityHash: Data(repeating: 3, count: 32)
            )
            
            // Validate
            
            #expect(actualRemoteSecret.rawValue == expectedRemoteSecret)
            // This expects that the test never runs more than 10s
            #expect(remoteSecretMonitorProtocolMock.pollResponses.wrappedValue.count == 1)
        }
        
        @Test("Request and schedule")
        func requestAndSchedule() async throws {
            // Prepare
            
            let expectedRemoteSecret = Data(repeating: 1, count: 32)
            
            let fakeRequest = HttpsRequest(
                timeout: 0,
                url: "https://example.com",
                method: .get,
                headers: [],
                body: Data()
            )
            
            let remoteSecretMonitorProtocolMock = RemoteSecretMonitorProtocolMock(
                pollResponses: [
                    .request(fakeRequest),
                    .schedule(timeout: 10, remoteSecret: expectedRemoteSecret),
                    .error(.Blocked(message: "")), // We expect this to never execute, otherwise we'll crash
                ]
            )
            
            let appInfo = AppInfo(
                version: "1.0",
                locale: "en/CH",
                deviceModel: "iPhone1,0",
                osVersion: "18.0"
            )
            
            let sut = await RemoteSecretMonitor(
                appInfo: appInfo,
                monitorProtocolResolver: TestingRemoteSecretMonitorProtocolResolver(
                    answer: .success(remoteSecretMonitorProtocolMock)
                ),
                httpClient: RemoteSecretHTTPSClientMock()
            )
            
            // Run
            let actualRemoteSecret = try await sut.createAndStart(
                workServerBaseURL: "https://example.com",
                identity: ThreemaIdentity("ABCDEFGH"),
                remoteSecretAuthenticationToken: Data(repeating: 2, count: 32),
                remoteSecretIdentityHash: Data(repeating: 3, count: 32)
            )
            
            // Validate
            
            #expect(actualRemoteSecret.rawValue == expectedRemoteSecret)
            // This expects that the test never runs much more than 10s
            #expect(remoteSecretMonitorProtocolMock.pollResponses.wrappedValue.count == 1)
        }
        
        #if swift(>=6.2)
            @Test("Schedule and crash during monitoring")
            func scheduleAndCrash() async throws {
                await #expect(processExitsWith: .failure) {
                    // Prepare
                
                    let expectedRemoteSecret = Data(repeating: 1, count: 32)
                
                    let remoteSecretMonitorProtocolMock = RemoteSecretMonitorProtocolMock(pollResponses: [
                        .schedule(timeout: 0, remoteSecret: expectedRemoteSecret),
                        .schedule(timeout: 0, remoteSecret: nil),
                        .schedule(timeout: 0, remoteSecret: nil),
                        .error(.Blocked(message: "")),
                    ])
                
                    let appInfo = AppInfo(
                        version: "1.0",
                        locale: "en/CH",
                        deviceModel: "iPhone1,0",
                        osVersion: "18.0"
                    )
                    
                    let sut = await RemoteSecretMonitor(
                        appInfo: appInfo,
                        monitorProtocolResolver: TestingRemoteSecretMonitorProtocolResolver(
                            answer: .success(remoteSecretMonitorProtocolMock)
                        ),
                        httpClient: RemoteSecretHTTPSClientMock()
                    )
                    
                    // Run
                    let actualRemoteSecret = try await sut.createAndStart(
                        workServerBaseURL: "https://example.com",
                        identity: ThreemaIdentity("ABCDEFGH"),
                        remoteSecretAuthenticationToken: Data(repeating: 2, count: 32),
                        remoteSecretIdentityHash: Data(repeating: 3, count: 32)
                    )
                    
                    // Validate
                
                    #expect(actualRemoteSecret.rawValue == expectedRemoteSecret)
                
                    // Wait until the scheduled tasks complete & the process exits. `Task.yield()` doesn't work here
                    try await Task.sleep(seconds: 0.1)
                }
            }
        #endif
        
        // MARK: Errors
        
        @Test("Create error")
        func createError() async throws {
            // Prepare
            
            let appInfo = AppInfo(
                version: "1.0",
                locale: "en/CH",
                deviceModel: "iPhone1,0",
                osVersion: "18.0"
            )
            
            let sut = await RemoteSecretMonitor(
                appInfo: appInfo,
                monitorProtocolResolver: TestingRemoteSecretMonitorProtocolResolver(
                    answer: .failure(.InvalidParameter(message: ""))
                ),
                httpClient: RemoteSecretHTTPSClientMock()
            )
            
            // Run & validate
            await #expect(throws: RemoteSecretManagerError.invalidParameter) {
                try await sut.createAndStart(
                    workServerBaseURL: "https://example.com",
                    identity: ThreemaIdentity("ABCDEFGH"),
                    remoteSecretAuthenticationToken: Data(repeating: 2, count: 32),
                    remoteSecretIdentityHash: Data(repeating: 3, count: 32)
                )
            }
        }
        
        @Test(
            "Run error mapping",
            arguments: [
                (RemoteSecretMonitorError.InvalidParameter(message: ""), RemoteSecretManagerError.invalidParameter),
                (.InvalidState(message: ""), .invalidState),
                (.ServerError(message: ""), .serverError),
                (.Timeout(message: ""), .timeout),
                (.NotFound(message: ""), .remoteSecretNotFound),
                (.Blocked(message: ""), .blocked),
                (.Mismatch(message: ""), .mismatch),
            ]
        )
        func runErrorMapping(
            inputError: RemoteSecretMonitorError,
            expectedError: RemoteSecretManagerError
        ) async throws {
            // Prepare
            
            let remoteSecretMonitorProtocolMock = RemoteSecretMonitorProtocolMock(pollResponses: [
                .error(inputError),
            ])
            
            let appInfo = AppInfo(
                version: "1.0",
                locale: "en/CH",
                deviceModel: "iPhone1,0",
                osVersion: "18.0"
            )
            
            let sut = await RemoteSecretMonitor(
                appInfo: appInfo,
                monitorProtocolResolver: TestingRemoteSecretMonitorProtocolResolver(
                    answer: .success(remoteSecretMonitorProtocolMock)
                ),
                httpClient: RemoteSecretHTTPSClientMock()
            )
            
            // Run & validate
            await #expect(throws: expectedError) {
                try await sut.createAndStart(
                    workServerBaseURL: "https://example.com",
                    identity: ThreemaIdentity("ABCDEFGH"),
                    remoteSecretAuthenticationToken: Data(repeating: 2, count: 32),
                    remoteSecretIdentityHash: Data(repeating: 3, count: 32)
                )
            }
        }
    }
    
    @Suite("Run Check")
    struct RunCheckTests {
        @Test("Basic run check")
        func basicRunCheck() async throws {
            // Prepare
            
            let expectedRemoteSecret = Data(repeating: 1, count: 32)
            
            let remoteSecretMonitorProtocolMock = RemoteSecretMonitorProtocolMock(pollResponses: [
                .schedule(timeout: 10, remoteSecret: expectedRemoteSecret),
                .schedule(timeout: 10, remoteSecret: expectedRemoteSecret),
                .error(.Blocked(message: "")), // We expect this to never execute, otherwise we'll crash
            ])
            
            let appInfo = AppInfo(
                version: "1.0",
                locale: "en/CH",
                deviceModel: "iPhone1,0",
                osVersion: "18.0"
            )
            
            let sut = await RemoteSecretMonitor(
                appInfo: appInfo,
                monitorProtocolResolver: TestingRemoteSecretMonitorProtocolResolver(
                    answer: .success(remoteSecretMonitorProtocolMock)
                ),
                httpClient: RemoteSecretHTTPSClientMock()
            )
            
            // Run
            
            let actualRemoteSecret = try await sut.createAndStart(
                workServerBaseURL: "https://example.com",
                identity: ThreemaIdentity("ABCDEFGH"),
                remoteSecretAuthenticationToken: Data(repeating: 2, count: 32),
                remoteSecretIdentityHash: Data(repeating: 3, count: 32)
            )
            
            // This will immediately run the next poll (& cancel the scheduled task)
            await sut.runCheck()
            
            // Validate
            #expect(actualRemoteSecret.rawValue == expectedRemoteSecret)
            // This expects that the test never runs much more than 10s
            #expect(remoteSecretMonitorProtocolMock.pollResponses.wrappedValue.count == 1)
        }
    }
    
    @Suite("Stop")
    struct StopTests {
        @Test("Basic stop")
        func basicStop() async throws {
            // Prepare
            
            let expectedRemoteSecret = Data(repeating: 1, count: 32)
            
            let remoteSecretMonitorProtocolMock = RemoteSecretMonitorProtocolMock(pollResponses: [
                .schedule(timeout: 0, remoteSecret: expectedRemoteSecret),
                .schedule(timeout: 10, remoteSecret: expectedRemoteSecret),
                .error(.Blocked(message: "")), // We expect this to never execute, otherwise we'll crash
            ])
            
            let appInfo = AppInfo(
                version: "1.0",
                locale: "en/CH",
                deviceModel: "iPhone1,0",
                osVersion: "18.0"
            )
            
            let sut = await RemoteSecretMonitor(
                appInfo: appInfo,
                monitorProtocolResolver: TestingRemoteSecretMonitorProtocolResolver(
                    answer: .success(remoteSecretMonitorProtocolMock)
                ),
                httpClient: RemoteSecretHTTPSClientMock()
            )
            
            // Run
            
            let actualRemoteSecret = try await sut.createAndStart(
                workServerBaseURL: "https://example.com",
                identity: ThreemaIdentity("ABCDEFGH"),
                remoteSecretAuthenticationToken: Data(repeating: 2, count: 32),
                remoteSecretIdentityHash: Data(repeating: 3, count: 32)
            )
            
            // This will stop any scheduled task (we expect this is called less than 10s after the create & start)
            await sut.stop()
            
            // Validate
            
            #expect(actualRemoteSecret.rawValue == expectedRemoteSecret)
            #expect(remoteSecretMonitorProtocolMock.pollResponses.wrappedValue.count == 2)
        }
    }
}

private struct TestingRemoteSecretMonitorProtocolResolver: RemoteSecretMonitorProtocolResolver {
    enum Answer {
        case success(any RemoteSecretMonitorProtocolProtocol)
        case failure(RemoteSecretMonitorError)
    }
    
    let answer: Answer
    
    func createProtocol(
        clientInfo: ClientInfo,
        workServerBaseURLString: String,
        remoteSecretAuthenticationToken: Data,
        remoteSecretVerifier: RemoteSecretVerifier
    ) throws -> any RemoteSecretMonitorProtocolProtocol {
        switch answer {
        case let .success(protocolInstance):
            return protocolInstance
        case let .failure(error):
            throw error
        }
    }
}
