import Foundation

public enum RecoveryKeyGeneratorError: Error, LocalizedError, Equatable {
    /// The system secure random number generator (`SecRandomCopyBytes`) failed with the given `OSStatus`.
    case secureRandomFailed(status: OSStatus)

    public var errorDescription: String? {
        switch self {
        case let .secureRandomFailed(status):
            "Secure random number generation failed with OSStatus \(status)."
        }
    }
}
