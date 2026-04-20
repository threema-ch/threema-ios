import Foundation

public protocol URLSessionProvider {
        
    /// Provides a default ephemeral session
    /// - Parameter delegate: Optional delegate for this session
    /// - Returns: New ephemeral session with default configuration
    func defaultSession(delegate: URLSessionDelegate?) -> URLSession
    
    /// Creates a background session
    /// - Parameters:
    ///   - identifier: Identifier for session
    ///   - delegate: URLSessionDelegate
    /// - Returns: Created URLSession
    func backgroundSession(identifier: String, delegate: URLSessionDelegate) -> URLSession
}

extension URLSessionProvider {
    func defaultSession() -> URLSession {
        defaultSession(delegate: nil)
    }
}
