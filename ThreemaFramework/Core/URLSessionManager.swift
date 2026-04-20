import Foundation

public final class URLSessionManager {
    
    // MARK: - Properties

    /// Shared URLSessionManager using a DefaultURLSessionProvider
    public static let shared = URLSessionManager(with: DefaultURLSessionProvider())
    
    let sessionProvider: URLSessionProvider
    
    private var sessionStoreMutationLock = DispatchQueue(label: "sessionStoreMutationLock")
    private(set) var sessionStore = [Int: URLSession]()
    
    // MARK: - Lifecycle

    init(with sessionProvider: URLSessionProvider) {
        self.sessionProvider = sessionProvider
    }
    
    // MARK: - Sessions
      
    /// Returns the session for a given delegate if it exists. Otherwise it creates one and stores it if a delegate is
    /// provided.
    /// - Parameters:
    ///   - delegate: Optional URLSessionDelegate for created session
    ///   - createAsBackgroundSession: If created session is a background session
    /// - Returns: Fetched or created URLSession
    func storedSession(for delegate: URLSessionDelegate?, createAsBackgroundSession: Bool) -> URLSession {
        sessionStoreMutationLock.sync {
    
            // If no delegate is provided, we return a default session
            guard let delegate else {
                return sessionProvider.defaultSession()
            }
            
            let hash = delegate.hash
            
            // We return the stored session if it exists
            if let storedSession = sessionStore[hash] {
                return storedSession
            }
            
            // No session found, creating new one. If it is a background session we store it. Else we just return the
            // default session
            let createdSession: URLSession =
                if createAsBackgroundSession {
                    sessionProvider.backgroundSession(
                        identifier: String(hash),
                        delegate: delegate
                    )
                }
                else {
                    sessionProvider.defaultSession(delegate: delegate)
                }
            
            sessionStore[hash] = createdSession
            return createdSession
        }
    }
    
    /// Invalidates and cancels session for a given delegate
    /// - Parameter delegate: URLSessionDelegate of to be canceled session
    public func invalidateAndCancelSession(for delegate: URLSessionDelegate) {
        sessionStoreMutationLock.sync {
            let identifier = delegate.hash
            if let session = sessionStore[identifier] {
                session.invalidateAndCancel()
            }
        }
    }
}
