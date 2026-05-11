import Foundation
import ThreemaFramework

// MARK: - WCSessionManagerProtocol

protocol WCSessionManagerProtocol {
    var isRunningWCSession: Bool { get }
    func connectAllRunningSessions()
}

// MARK: - WCSessionManagerAdapter

final class WCSessionManagerAdapter: WCSessionManagerProtocol {
    
    private var manager: WCSessionManager {
        WCSessionManager.shared
    }
    
    var isRunningWCSession: Bool {
        manager.isRunningWCSession()
    }
    
    func connectAllRunningSessions() {
        manager.connectAllRunningSessions()
    }
}
