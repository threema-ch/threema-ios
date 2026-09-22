import Foundation
@testable import Threema

/// A configurable implementation of `OnboardingLicenseCredentialsLoading` for testing
final class LicenseCredentialsLoaderMock: OnboardingLicenseCredentialsLoading {

    /// Credentials to return, `nil` for a keychain without usable credentials
    var credentials: LicenseCredentials?

    /// Error to throw instead of returning credentials
    var error: Error?

    private(set) var loadCredentialsCallCount = 0

    init(credentials: LicenseCredentials? = nil, error: Error? = nil) {
        self.credentials = credentials
        self.error = error
    }

    func loadCredentials() throws -> LicenseCredentials? {
        loadCredentialsCallCount += 1

        if let error {
            throw error
        }

        return credentials
    }
}
