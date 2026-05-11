import Foundation

enum WorkDataFetchError: Error, LocalizedError, CustomNSError {
    case missingCredentials
    case serverInfoUnavailable
    case httpError(statusCode: Int)
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            "Missing credentials (user name or password)"
        case .serverInfoUnavailable:
            "Work server info unavailable"
        case let .httpError(statusCode):
            "HTTP error \(statusCode)"
        case .invalidResponse:
            "Invalid server response"
        case let .serverError(message):
            message
        }
    }

    static var errorDomain: String { NSURLErrorDomain }

    /// Preserves the HTTP status code when bridged to `NSError`,
    /// matching the behavior of the legacy `ServerAPIRequest` implementation.
    var errorCode: Int {
        switch self {
        case let .httpError(statusCode):
            statusCode
        default:
            -1
        }
    }
}
