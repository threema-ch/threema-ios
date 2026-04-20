import Foundation

protocol SSLCAHelperProtocol {
    static func canAuthenticate(_ protectionSpace: URLProtectionSpace) -> Bool
    func handle(challenge: URLAuthenticationChallenge) async throws
        -> (disposition: URLSession.AuthChallengeDisposition, credential: URLCredential?)
    func evaluate(trust: SecTrust, domain: String, completionHandler: @escaping (Bool) -> Void)
    func evaluate(trust: SecTrust, domain: String) async -> Bool
}
