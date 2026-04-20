import Foundation
import KeychainTestHelper
import RemoteSecretProtocolTestHelper
import Testing
import ThreemaEssentials
@testable import RemoteSecret

// They need to be serialized because the RS content in keychain is static
@Suite("Remote Secret", .serialized)
struct RemoteSecretTests {
    
    @Suite("Remote Secret Manager Creator", .serialized)
    struct RemoteSecretManagerCreatorTests {
        private let appInfo = AppInfo(
            version: "1.0",
            locale: "en/CH",
            deviceModel: "iPhone1,0",
            osVersion: "18.0"
        )
        
        @Test("Basic creation of remote secret")
        func basicCreate() async throws {
            let expectedAuthenticationToken = Data(repeating: 1, count: 32)
            let expectedIdentityHash = Data(repeating: 2, count: 32)
            let expectedRemoteSecret = RemoteSecret(rawValue: Data(repeating: 3, count: 32))
            
            let expectedWorkServerBaseURL = "https://example.com"
            let expectedLicenseUsername = "username"
            let expectedLicensePassword = "password"
            let expectedIdentity = ThreemaIdentity("ABCDEFGH")
            let expectedClientKey = Data(repeating: 4, count: 32)
            
            let remoteSecretCreateMock = RemoteSecretCreateMock(
                authenticationToken: expectedAuthenticationToken,
                identityHash: expectedIdentityHash
            )
            let remoteSecretMonitorMock = RemoteSecretMonitorMock(remoteSecret: expectedRemoteSecret)
            
            let remoteSecretManagerCreator = RemoteSecretManagerCreator(
                appInfo: appInfo,
                httpClient: RemoteSecretHTTPSClientMock(),
                remoteSecretCreate: remoteSecretCreateMock,
                remoteSecretMonitor: remoteSecretMonitorMock,
                keychainManagerType: KeychainManagerMock.self
            )
            
            let emptyRemoteSecret = try KeychainManagerMock.loadRemoteSecret()
            #expect(emptyRemoteSecret == nil)
            
            let remoteSecretManager = try await remoteSecretManagerCreator.create(
                workServerBaseURL: expectedWorkServerBaseURL,
                licenseUsername: expectedLicenseUsername,
                licensePassword: expectedLicensePassword,
                identity: expectedIdentity,
                clientKey: expectedClientKey
            )
            
            #expect(remoteSecretManager.isRemoteSecretEnabled == true)
            
            #expect(remoteSecretCreateMock.runs.count == 1)
            let expectedCreateInfo = RemoteSecretCreateMock.CreateInfo(
                workServerBaseURL: expectedWorkServerBaseURL,
                licenseUsername: expectedLicenseUsername,
                licensePassword: expectedLicensePassword,
                identity: expectedIdentity,
                clientKey: expectedClientKey
            )
            #expect(remoteSecretCreateMock.runs[0] == expectedCreateInfo)
            
            await #expect(remoteSecretMonitorMock.unlockCalls == 1)
            await #expect(remoteSecretMonitorMock.runCalls == 0)
            
            let actualRemoteSecret = try #require(try KeychainManagerMock.loadRemoteSecret())
            #expect(actualRemoteSecret == (expectedAuthenticationToken, expectedIdentityHash))
            
            // Cleanup
            try KeychainManagerMock.deleteRemoteSecret()
        }
        
        @Test("No remote secret in keychain and thus not enabled")
        func notEnabledInitialize() async throws {
            let remoteSecretCreateMock = RemoteSecretCreateMock(
                authenticationToken: Data(),
                identityHash: Data()
            )
            let remoteSecretMonitorMock = RemoteSecretMonitorMock(
                remoteSecret: RemoteSecret(rawValue: Data())
            )
            
            let remoteSecretManagerCreator = RemoteSecretManagerCreator(
                appInfo: appInfo,
                httpClient: RemoteSecretHTTPSClientMock(),
                remoteSecretCreate: remoteSecretCreateMock,
                remoteSecretMonitor: remoteSecretMonitorMock,
                keychainManagerType: KeychainManagerMock.self
            )
            
            let remoteSecretManager = try await remoteSecretManagerCreator.initialize {
                nil
            }
            
            #expect(remoteSecretManager.isRemoteSecretEnabled == false)
            #expect(remoteSecretManager is EmptyRemoteSecretManager)
            #expect(remoteSecretManager.crypto is EmptyRemoteSecretCrypto)
            
            // Cleanup
            try KeychainManagerMock.deleteRemoteSecret()
        }
        
        @Test func enabledInitializeAndCheckValidity() async throws {
            let expectedAuthenticationToken = Data(repeating: 1, count: 32)
            let expectedIdentityHash = Data(repeating: 2, count: 32)
            let expectedRemoteSecret = RemoteSecret(rawValue: Data(repeating: 3, count: 32))
            
            let expectedWorkURL = URL(string: "https://example.com")!
            
            let remoteSecretCreateMock = RemoteSecretCreateMock(
                authenticationToken: expectedAuthenticationToken,
                identityHash: expectedIdentityHash
            )
            let remoteSecretMonitorMock = RemoteSecretMonitorMock(remoteSecret: expectedRemoteSecret)
            
            let remoteSecretManagerCreator = RemoteSecretManagerCreator(
                appInfo: appInfo,
                httpClient: RemoteSecretHTTPSClientMock(),
                remoteSecretCreate: remoteSecretCreateMock,
                remoteSecretMonitor: remoteSecretMonitorMock,
                keychainManagerType: KeychainManagerMock.self
            )
            
            try KeychainManagerMock.storeRemoteSecret(
                authenticationToken: expectedAuthenticationToken,
                identityHash: expectedIdentityHash
            )
            
            let remoteSecretManager = try await remoteSecretManagerCreator.initialize {
                expectedWorkURL.absoluteString
            }

            #expect(remoteSecretManager.isRemoteSecretEnabled == true)
            
            await #expect(remoteSecretMonitorMock.unlockCalls == 1)
            await #expect(remoteSecretMonitorMock.runCalls == 0)
            
            // Cleanup
            try KeychainManagerMock.deleteRemoteSecret()
        }
    }
    
    @Suite("Remote Secret Manager")
    struct RemoteSecretManagerTests {
        @Test("Check validity call")
        func checkValidity() async throws {
            let expectedRemoteSecret = RemoteSecret(rawValue: Data(repeating: 3, count: 32))
            
            let remoteSecretMonitorMock = RemoteSecretMonitorMock(remoteSecret: expectedRemoteSecret)
            let remoteSecretCrypto = try RemoteSecretCrypto(remoteSecret: expectedRemoteSecret)
            let remoteSecretManager = RemoteSecretManager(
                crypto: remoteSecretCrypto,
                monitor: remoteSecretMonitorMock,
                keychainManagerType: KeychainManagerMock.self
            )
            
            await #expect(remoteSecretMonitorMock.unlockCalls == 0)
            await #expect(remoteSecretMonitorMock.runCalls == 0)
            await #expect(remoteSecretMonitorMock.stopCalls == 0)

            // This should call the monitor once
            remoteSecretManager.checkValidity()
            
            // We need to wait as the run call is "async"
            try await Task.sleep(seconds: 0.1)
            
            await #expect(remoteSecretMonitorMock.unlockCalls == 0)
            await #expect(remoteSecretMonitorMock.runCalls == 1)
            await #expect(remoteSecretMonitorMock.stopCalls == 0)
        }
        
        @Suite("Stop Monitoring", .serialized)
        struct StopMonitoring {
            @Test("Successful Stop Monitoring")
            func successfulStopMonitoring() async throws {
                let expectedRemoteSecret = RemoteSecret(rawValue: Data(repeating: 3, count: 32))
                
                let remoteSecretMonitorMock = RemoteSecretMonitorMock(remoteSecret: expectedRemoteSecret)
                
                let remoteSecretManager = try RemoteSecretManager(
                    crypto: RemoteSecretCrypto(remoteSecret: expectedRemoteSecret),
                    monitor: remoteSecretMonitorMock,
                    keychainManagerType: KeychainManagerMock.self
                )
                
                await #expect(remoteSecretMonitorMock.unlockCalls == 0)
                await #expect(remoteSecretMonitorMock.runCalls == 0)
                await #expect(remoteSecretMonitorMock.stopCalls == 0)
                
                // This should call stop once, because no RS information is in the keychain
                await remoteSecretManager.stopMonitoring()
                
                await #expect(remoteSecretMonitorMock.unlockCalls == 0)
                await #expect(remoteSecretMonitorMock.runCalls == 0)
                await #expect(remoteSecretMonitorMock.stopCalls == 1)
            }
            
            @Test("Unsuccessfully Stop Monitoring")
            func unsuccessfullyStopMonitoring() async throws {
                let expectedAuthenticationToken = Data(repeating: 1, count: 32)
                let expectedIdentityHash = Data(repeating: 2, count: 32)
                let expectedRemoteSecret = RemoteSecret(rawValue: Data(repeating: 3, count: 32))
                            
                let remoteSecretMonitorMock = RemoteSecretMonitorMock(remoteSecret: expectedRemoteSecret)
                // A RS needs to be in the keychain for stopping to not work
                try KeychainManagerMock.storeRemoteSecret(
                    authenticationToken: expectedAuthenticationToken,
                    identityHash: expectedIdentityHash
                )
                
                let remoteSecretManager = try RemoteSecretManager(
                    crypto: RemoteSecretCrypto(remoteSecret: expectedRemoteSecret),
                    monitor: remoteSecretMonitorMock,
                    keychainManagerType: KeychainManagerMock.self
                )
                
                await #expect(remoteSecretMonitorMock.unlockCalls == 0)
                await #expect(remoteSecretMonitorMock.runCalls == 0)
                await #expect(remoteSecretMonitorMock.stopCalls == 0)
                
                // This should not call stop, because RS information is stored in the keychain
                await remoteSecretManager.stopMonitoring()
                
                await #expect(remoteSecretMonitorMock.unlockCalls == 0)
                await #expect(remoteSecretMonitorMock.runCalls == 0)
                await #expect(remoteSecretMonitorMock.stopCalls == 0)
            }
        }
    }
}
