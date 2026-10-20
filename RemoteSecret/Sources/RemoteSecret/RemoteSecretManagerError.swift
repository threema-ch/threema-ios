/// Public errors of RemoteSecret package
public enum RemoteSecretManagerError: Error, CustomStringConvertible, Equatable {
    case conversionError
    case contractViolation
    case internalError
    case serverError
    case timeout
    case remoteSecretNotFound
    case blocked
    case mismatch
    
    case networkError
    /// Invalid Work/OnPrem credentials. Request them (again) from the user
    case invalidCredentials
    case exceededRateLimit
    
    case preexistingRemoteSecret
    case noThreemaIdentityAvailable
    case noRemoteSecretCredentialsAvailable
    case noWorkServerBaseURL

    case unknown
    
    public var description: String {
        switch self {
        case .conversionError:
            "Conversion error"
        case .contractViolation:
            "Contract violation"
        case .internalError:
            "Internal error"
        case .serverError:
            "Server error"
        case .timeout:
            "Timeout"
        case .remoteSecretNotFound:
            "Remote secret not found"
        case .blocked:
            "Blocked"
        case .mismatch:
            "Mismatch"
        case .networkError:
            "Network error"
        case .invalidCredentials:
            "Invalid credentials"
        case .exceededRateLimit:
            "Exceeded rate limit"
        case .preexistingRemoteSecret:
            "Preexisting remote secret"
        case .noThreemaIdentityAvailable:
            "No Threema identity available"
        case .noRemoteSecretCredentialsAvailable:
            "No remote secret credentials available"
        case .noWorkServerBaseURL:
            "No Work/OnPrem base URL"
        case .unknown:
            "Unknown error"
        }
    }
}
