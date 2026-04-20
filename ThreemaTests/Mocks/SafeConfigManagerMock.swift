import Foundation

@testable import Threema

final class SafeConfigManagerMock: NSObject, SafeConfigManagerProtocol {

    var safeConfigDestroyCallCount = 0
    
    private var server: String?
    
    init(server: String?) {
        self.server = server
    }
    
    func destroy() {
        safeConfigDestroyCallCount += 1
    }
    
    func getKey() -> [UInt8]? {
        nil
    }
    
    func setKey(_ value: [UInt8]?) { }
    
    func getCustomServer() -> String? {
        nil
    }
    
    func setCustomServer(_ value: String?) { }
    
    func getServerUser() -> String? {
        nil
    }

    func setServerUser(_ value: String?) {
        // no-op
    }

    func getServerPassword() -> String? {
        nil
    }

    func setServerPassword(_ value: String?) {
        // no-op
    }

    func getServer() -> String? {
        server
    }
    
    func setServer(_ value: String?) { }
    
    func getMaxBackupBytes() -> Int? {
        nil
    }
    
    func setMaxBackupBytes(_ value: Int?) { }
    
    func getRetentionDays() -> Int? {
        nil
    }
    
    func setRetentionDays(_ value: Int?) { }
    
    func getBackupSize() -> Int64? {
        nil
    }
    
    func setBackupSize(_ value: Int64?) { }
    
    func getBackupStartedAt() -> Date? {
        nil
    }
    
    func setBackupStartedAt(_ value: Date?) { }
    
    func getLastBackup() -> Date? {
        nil
    }
    
    func setLastBackup(_ value: Date?) { }
    
    func getLastResult() -> String? {
        nil
    }
    
    func setLastResult(_ value: String?) { }
    
    func getLastChecksum() -> [UInt8]? {
        nil
    }
    
    func setLastChecksum(_ value: [UInt8]?) { }
    
    public func getLastAlertBackupFailed() -> Date? {
        nil
    }
    
    public func setLastAlertBackupFailed(_ value: Date?) { }

    func getIsTriggered() -> Bool {
        false
    }
    
    func setIsTriggered(_ value: Bool) { }
}
