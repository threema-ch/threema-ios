import Foundation
import ThreemaEssentials
@testable import RemoteSecret

final class RemoteSecretCreateMock: RemoteSecretCreateProtocol {
    struct CreateInfo: Equatable {
        let workServerBaseURL: String
        let licenseUsername: String
        let licensePassword: String
        let identity: ThreemaIdentity
        let clientKey: Data
    }
    
    var runs = [CreateInfo]()
    
    private let authenticationToken: Data
    private let identityHash: Data
    
    init(authenticationToken: Data, identityHash: Data) {
        self.authenticationToken = authenticationToken
        self.identityHash = identityHash
    }
    
    func run(
        workServerBaseURL: String,
        licenseUsername: String,
        licensePassword: String,
        identity: ThreemaIdentity,
        clientKey: Data,
    ) async throws -> (authenticationToken: Data, identityHash: Data) {
        runs.append(
            CreateInfo(
                workServerBaseURL: workServerBaseURL,
                licenseUsername: licenseUsername,
                licensePassword: licensePassword,
                identity: identity,
                clientKey: clientKey
            )
        )
        return (authenticationToken, identityHash)
    }
}
