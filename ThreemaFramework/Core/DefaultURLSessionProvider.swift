import Foundation

final class DefaultURLSessionProvider: URLSessionProvider {
    func defaultSession(delegate: URLSessionDelegate?) -> URLSession {
        // We first need to create the configuration. Changes made to a session after its initialization are not
        // respected.
        let configuration = URLSessionConfiguration.ephemeral

        // General
        configuration.allowsCellularAccess = true
        
        // Should this be enabled?
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

    func backgroundSession(identifier: String, delegate: URLSessionDelegate) -> URLSession {
        // We first need to create the configuration. Changes made to a session after its initialization are not
        // respected.
        let configuration = URLSessionConfiguration.background(withIdentifier: identifier)

        // General
        configuration.allowsCellularAccess = true
        configuration.waitsForConnectivity = true
        
        // Caching, this might not be needed since configuration is ephemeral anyways
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil

        return URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: .current
        )
    }
}
