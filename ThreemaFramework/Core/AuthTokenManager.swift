import Foundation

/// Obtains and manages authentication tokens for access to OnPrem servers.
public final class AuthTokenManager: NSObject {
    public typealias AuthTokenCompletionHandler = (String?, Error?) -> Void

    private var authToken: String?
    private var queue = DispatchQueue(label: "AuthTokenManager")
    private var isFetching = false
    private var completionHandlers: [AuthTokenCompletionHandler] = []
    
    private static let authTokenManager = AuthTokenManager()
    
    @objc public static func shared() -> AuthTokenManager {
        authTokenManager
    }
    
    @objc public func obtainToken(completionHandler: @escaping AuthTokenCompletionHandler) {
        if !TargetManager.isOnPrem {
            completionHandler(nil, nil)
            return
        }
        
        queue.async {
            if self.authToken != nil {
                // Cached token
                completionHandler(self.authToken, nil)
                return
            }
            
            self.completionHandlers.append(completionHandler)
            
            if !self.isFetching {
                self.isFetching = true
                ServerAPIConnector().obtainAuthToken(onCompletion: { authToken in
                    self.queue.async {
                        self.isFetching = false
                        self.authToken = authToken
                        for completionHandler in self.completionHandlers {
                            completionHandler(authToken, nil)
                        }
                        self.completionHandlers.removeAll()
                    }
                }, onError: { err in
                    self.queue.async {
                        for completionHandler in self.completionHandlers {
                            completionHandler(nil, err)
                        }
                        self.completionHandlers.removeAll()
                    }
                })
            }
        }
    }
    
    public func clearCache() {
        queue.async {
            self.authToken = nil
        }
    }
}
