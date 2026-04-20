import Foundation
@testable import GroupCalls

final class MockHTTPHelper: GroupCallSFUTokenFetchAdapterProtocol {
    fileprivate var sfuToken: GroupCalls.SFUToken
    
    convenience init() {
        let token = SFUToken(
            sfuBaseURL: URL(string: "http://sfu.threema.ch")!,
            hostNameSuffixes: ["test", "test"],
            sfuToken: "",
            expiration: Int.max
        )
        
        self.init(token: token)
    }
    
    init(token: GroupCalls.SFUToken) {
        self.sfuToken = token
    }
    
    func sfuCredentials() async throws -> GroupCalls.SFUToken {
        sfuToken
    }
    
    func refreshTokenWithTimeout(_ timeout: TimeInterval) async throws -> GroupCalls.SFUToken? {
        sfuToken
    }
}
