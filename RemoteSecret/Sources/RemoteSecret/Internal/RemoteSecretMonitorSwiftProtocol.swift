import Foundation
import ThreemaEssentials

// This has "Swift" in the name to prevent a name clash with libthreema's `RemoteSecretMonitorProtocol`
protocol RemoteSecretMonitorSwiftProtocol: Sendable {
    
    /// Fetch remote secret, and create & starting monitor
    ///
    /// - Parameters:
    ///   - workServerBaseURL: Base URL of work API server
    ///   - identity: Threema identity of user
    ///   - remoteSecretAuthenticationToken: Remote secret authentication token (rsat)
    ///   - remoteSecretIdentityHash: Remote secret identity hash (rshid)
    /// - Returns: Remote secret
    /// - Throws: `RemoteSecretManagerError`
    func createAndStart(
        workServerBaseURL: String,
        identity: ThreemaIdentity,
        remoteSecretAuthenticationToken: Data,
        remoteSecretIdentityHash: Data
    ) async throws -> RemoteSecret
    
    /// Enforce a monitor check right now
    func runCheck() async
    
    /// Stop monitor
    ///
    /// - Warning: Only call this during the reset of the app
    func stop() async
}
