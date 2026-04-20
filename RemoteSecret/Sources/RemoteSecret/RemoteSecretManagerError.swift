/// Public errors of RemoteSecret package
public enum RemoteSecretManagerError: Error, CustomStringConvertible, Equatable {
    case invalidParameter
    case invalidState
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
        case .invalidParameter:
            "Invalid parameter"
        case .invalidState:
            "Invalid state"
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
