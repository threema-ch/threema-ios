import Foundation
import ThreemaEssentials

protocol RemoteSecretCreateProtocol {
    /// Create a new remote secret
    /// - Parameters:
    ///   - workServerBaseURL: Base URL of work API server
    ///   - licenseUsername: License username
    ///   - licensePassword: License password
    ///   - identity: Identity of this user
    ///   - clientKey: Client key of this user
    /// - Returns: Remote secret authentication token and identity hash that need to be persisted to request remote
    ///            secret again
    /// - Throws: `RemoteSecretManagerError` (all internal libthreema errors should be mapped)
    func run(
        workServerBaseURL: String,
        licenseUsername: String,
        licensePassword: String,
        identity: ThreemaIdentity,
        clientKey: Data
    ) async throws -> (authenticationToken: Data, identityHash: Data)
}
