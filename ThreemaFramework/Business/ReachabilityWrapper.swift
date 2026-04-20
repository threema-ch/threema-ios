import CocoaLumberjack
import Foundation
import Reachability

@objc final class ReachabilityWrapper: NSObject {
    
    private let reachability = try! Reachability()
    private var lastConnectionType: Reachability.Connection
    
    override init() {
        do {
            try reachability.startNotifier()
            self.lastConnectionType = reachability.connection
        }
        catch {
            DDLogNotice("Reachability init failed due to error: \(error.localizedDescription)")
            self.lastConnectionType = .unavailable
        }
        
        super.init()
    }
    
    deinit {
        reachability.stopNotifier()
    }
    
    @objc func isReachabilityUnavailable() -> Bool {
        lastConnectionType == .unavailable
    }
    
    @objc func didLastConnectionTypeChange() -> Bool {
        let newConnectionType = reachability.connection
        
        switch newConnectionType {
        case .unavailable:
            DDLogNotice("Internet is not reachable")
        case .wifi:
            DDLogNotice("Internet is reachable via WiFi")
        case .cellular:
            DDLogNotice("Internet is reachable via cellular")
        }
        
        if newConnectionType != lastConnectionType {
            lastConnectionType = newConnectionType
            return true
        }
        
        return false
    }
}
