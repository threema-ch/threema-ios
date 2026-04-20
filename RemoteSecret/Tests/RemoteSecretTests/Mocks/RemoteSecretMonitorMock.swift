import Foundation
import ThreemaEssentials
@testable import RemoteSecret

final actor RemoteSecretMonitorMock: RemoteSecretMonitorSwiftProtocol {
    
    var unlockCalls = 0
    var runCalls = 0
    var stopCalls = 0
    
    private let remoteSecret: RemoteSecret
    
    init(remoteSecret: RemoteSecret) {
        self.remoteSecret = remoteSecret
    }
    
    func createAndStart(
        workServerBaseURL: String,
        identity: ThreemaIdentity,
        remoteSecretAuthenticationToken: Data,
        remoteSecretIdentityHash: Data
    ) async throws -> RemoteSecret {
        unlockCalls += 1
        return remoteSecret
    }
    
    func runCheck() async {
        runCalls += 1
    }
    
    func restart(
        workServerBaseURL: String,
        identity: ThreemaIdentity,
        remoteSecretAuthenticationToken: Data,
        remoteSecretIdentityHash: Data
    ) async throws {
        // no-op
    }
    
    func stop() async {
        stopCalls += 1
    }
}
