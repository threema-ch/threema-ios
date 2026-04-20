import Foundation
import ThreemaFramework

final class TestSessionProvider: URLSessionProvider {

    // MARK: - Sessions
    
    /// Provides a standard ephemeral session
    func defaultSession(delegate: URLSessionDelegate?) -> URLSession {
        // We first need to create the configuration. Changes made to a session after its initialization are not
        // respected.
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolMock.self]
        
        // General
        configuration.allowsCellularAccess = true
        // configuration.waitsForConnectivity = true
        
        // Caching, this might not be needed since configuration is ephemeral anyways
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil

        if let delegate {
            return URLSession(
                configuration: configuration,
                delegate: delegate,
                delegateQueue: OperationQueue.current
            )
        }
        else {
            return URLSession(configuration: configuration)
        }
    }
    
    /// Creates a background session
    /// - Parameters:
    ///   - identifier: Identifier for session
    ///   - delegate: Delegate for session
    /// - Returns: Created URLSession
    func backgroundSession(identifier: String, delegate: URLSessionDelegate) -> URLSession {
        // Return default session, because background session not working in unit tests
        defaultSession(delegate: delegate)
    }
}
