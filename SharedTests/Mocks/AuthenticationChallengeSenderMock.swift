import Foundation

final class AuthenticationChallengeSenderMock: NSObject, URLAuthenticationChallengeSender {
    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {
        // no-op
    }

    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {
        // no-op
    }

    func cancel(_ challenge: URLAuthenticationChallenge) {
        // no-op
    }
}
