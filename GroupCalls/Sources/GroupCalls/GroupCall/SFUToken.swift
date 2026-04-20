import CocoaLumberjackSwift
import Foundation

public struct SFUToken: Sendable {
    // MARK: - Public Properties
    
    public var stillValid: Bool {
        DDLogNotice(
            "[GroupCall] SFUToken expiration date is \(expirationDate) and is \(expirationDate.timeIntervalSinceNow > 0 ? "still valid" : "not valid anymore")"
        )
        
        return expirationDate.timeIntervalSinceNow > 0
    }
    
    // MARK: - Internal Properties

    let sfuBaseURL: URL
    let hostNameSuffixes: [String]
    let sfuToken: String
    
    // MARK: - Private Properties
    
    fileprivate let expirationDate: Date
    
    fileprivate let expirationOffset = 5
    
    // MARK: - Lifecycle
    
    public init(sfuBaseURL: URL, hostNameSuffixes: [String], sfuToken: String, expiration: Int) {
        self.sfuBaseURL = sfuBaseURL
        self.hostNameSuffixes = hostNameSuffixes
        self.sfuToken = sfuToken
        
        self.expirationDate = Date().addingTimeInterval(TimeInterval(expiration - expirationOffset))
    }
    
    public func isValidSFUBaseURL(_ url: URL) -> Bool {
        hasAllowedProtocol(url: url) && hasAllowedHostnameSuffix(url: url)
    }
    
    public func hasAllowedProtocol(url: URL) -> Bool {
        url.scheme == ProtocolDefines.allowedBaseURLProtocol
    }
    
    // TODO: (IOS-3880) Add test
    public func hasAllowedHostnameSuffix(url: URL) -> Bool {
        var host = ""
        
        if let givenHost = url.host() {
            host = givenHost
        }
        
        if let port = url.port {
            switch port {
            case -1:
                break
            default:
                var components = URLComponents()
                components.host = host
                components.port = port
                if let componentsString = components.string {
                    host = componentsString
                }
                else {
                    DDLogError("[GroupCall] [SFUToken] Could not create host from \(host):\(port)")
                    host = "\(host):\(port)"
                }
            }
        }
        
        return hostNameSuffixes.contains {
            host.hasSuffix($0)
        }
    }
}
