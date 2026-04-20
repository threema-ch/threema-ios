import Foundation
@testable import ThreemaFramework

final class SSLCAHelperMock: SSLCAHelperProtocol {
    var handleCalls = [URLAuthenticationChallenge]()
    var evaluateCalls = [(trust: SecTrust, domain: String)]()

    static func canAuthenticate(_ protectionSpace: URLProtectionSpace) -> Bool {
        true
    }

    func handle(challenge: URLAuthenticationChallenge) async throws
        -> (disposition: URLSession.AuthChallengeDisposition, credential: URLCredential?) {
        handleCalls.append(challenge)
        return (URLSession.AuthChallengeDisposition.useCredential, nil)
    }

    func evaluate(trust: SecTrust, domain: String, completionHandler: @escaping (Bool) -> Void) {
        Task {
            await completionHandler(evaluate(trust: trust, domain: domain))
        }
    }

    func evaluate(trust: SecTrust, domain: String) async -> Bool {
        evaluateCalls.append((trust, domain))
        return true
    }
}
