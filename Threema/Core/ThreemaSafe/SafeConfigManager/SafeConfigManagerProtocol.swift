protocol SafeConfigManagerProtocol {
    func destroy()
    func getKey() -> [UInt8]?
    func setKey(_ value: [UInt8]?)
    func getCustomServer() -> String?
    func setCustomServer(_ value: String?)
    func getServerUser() -> String?
    func setServerUser(_ value: String?)
    func getServerPassword() -> String?
    func setServerPassword(_ value: String?)
    func getServer() -> String?
    func setServer(_ value: String?)
    func getMaxBackupBytes() -> Int?
    func setMaxBackupBytes(_ value: Int?)
    func getRetentionDays() -> Int?
    func setRetentionDays(_ value: Int?)
    func getBackupSize() -> Int64?
    func setBackupSize(_ value: Int64?)
    func getBackupStartedAt() -> Date?
    func setBackupStartedAt(_ value: Date?)
    func getLastBackup() -> Date?
    func setLastBackup(_ value: Date?)
    func getLastResult() -> String?
    func setLastResult(_ value: String?)
    func getLastChecksum() -> [UInt8]?
    func setLastChecksum(_ value: [UInt8]?)
    func getLastAlertBackupFailed() -> Date?
    func setLastAlertBackupFailed(_ value: Date?)
    func getIsTriggered() -> Bool
    func setIsTriggered(_ value: Bool)
}

#if DEBUG

    final class MockSafeConfigManager: SafeConfigManagerProtocol {
        var mockGetKey: [UInt8]?
        var mockGetCustomServer: String?
        var mockGetServerUser: String?
        var mockGetServerPassword: String?
        var mockGetServer: String?
        var mockGetMaxBackupBytes: Int?
        var mockGetRetentionDays: Int?
        var mockGetBackupSize: Int64?
        var mockGetBackupStartedAt: Date?
        var mockGetLastBackup: Date?
        var mockGetLastResult: String?
        var mockGetLastChecksum: [UInt8]?
        var mockGetLastAlertBackupFailed: Date?
        var mockGetIsTriggered = false

        func destroy() { /* no-op */ }
        func getKey() -> [UInt8]? { mockGetKey }
        func setKey(_ value: [UInt8]?) { /* no-op */ }
        func getCustomServer() -> String? { mockGetCustomServer }
        func setCustomServer(_ value: String?) { /* no-op */ }
        func getServerUser() -> String? { mockGetServerUser }
        func setServerUser(_ value: String?) { /* no-op */ }
        func getServerPassword() -> String? { mockGetServerPassword }
        func setServerPassword(_ value: String?) { /* no-op */ }
        func getServer() -> String? { mockGetServer }
        func setServer(_ value: String?) { /* no-op */ }
        func getMaxBackupBytes() -> Int? { mockGetMaxBackupBytes }
        func setMaxBackupBytes(_ value: Int?) { /* no-op */ }
        func getRetentionDays() -> Int? { mockGetRetentionDays }
        func setRetentionDays(_ value: Int?) { /* no-op */ }
        func getBackupSize() -> Int64? { mockGetBackupSize }
        func setBackupSize(_ value: Int64?) { /* no-op */ }
        func getBackupStartedAt() -> Date? { mockGetBackupStartedAt }
        func setBackupStartedAt(_ value: Date?) { /* no-op */ }
        func getLastBackup() -> Date? { mockGetLastBackup }
        func setLastBackup(_ value: Date?) { /* no-op */ }
        func getLastResult() -> String? { mockGetLastResult }
        func setLastResult(_ value: String?) { /* no-op */ }
        func getLastChecksum() -> [UInt8]? { mockGetLastChecksum }
        func setLastChecksum(_ value: [UInt8]?) { /* no-op */ }
        func getLastAlertBackupFailed() -> Date? { mockGetLastAlertBackupFailed }
        func setLastAlertBackupFailed(_ value: Date?) { /* no-op */ }
        func getIsTriggered() -> Bool { mockGetIsTriggered }
        func setIsTriggered(_ value: Bool) { /* no-op */ }
    }

    extension SafeConfigManagerProtocol where Self == MockSafeConfigManager {
        static var mock: Self { backupSucceeded }

        static var backupSucceeded: Self {
            let m = MockSafeConfigManager()
            m.mockGetKey = Array(repeating: UInt8(ascii: "A"), count: 64)
            m
                .mockGetMaxBackupBytes = Int(
                    Measurement<UnitInformationStorage>(value: 1024.0, unit: .kilobytes)
                        .converted(to: .bytes).value
                )
            m.mockGetRetentionDays = 10
            m.mockGetLastResult = "Successful"
            m.mockGetLastBackup = Date(timeIntervalSince1970: 1_234_567_890)
            m
                .mockGetBackupSize = Int64(
                    Measurement<UnitInformationStorage>(value: 5, unit: .kilobytes)
                        .converted(to: .bytes).value
                )
            return m
        }

        static var backupFailed: Self {
            let m = MockSafeConfigManager()
            m.mockGetKey = Array(repeating: UInt8(ascii: "A"), count: 64)
            m
                .mockGetMaxBackupBytes = Int(
                    Measurement<UnitInformationStorage>(value: 1024.0, unit: .kilobytes)
                        .converted(to: .bytes).value
                )
            m.mockGetRetentionDays = 10
            m.mockGetLastResult = "Failing error message."
            m.mockGetLastBackup = Date(timeIntervalSince1970: 1_234_567_890)
            m
                .mockGetBackupSize = Int64(
                    Measurement<UnitInformationStorage>(value: 5, unit: .kilobytes)
                        .converted(to: .bytes).value
                )
            return m
        }
    }

#endif
