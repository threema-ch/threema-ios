import Foundation

public protocol GroupCallSFUTokenFetchAdapterProtocol {
    func sfuCredentials() async throws -> SFUToken
    func refreshTokenWithTimeout(_ timeout: TimeInterval) async throws -> SFUToken?
}
