public protocol MDMSetupProtocol {

    func isSafeBackupDisable() -> Bool
    func isSafeBackupForce() -> Bool
    func isSafeBackupPasswordPreset() -> Bool
    func isSafeBackupServerPreset() -> Bool
    func isSafeRestoreDisable() -> Bool
    func isSafeRestoreForce() -> Bool
    func isSafeRestorePasswordPreset() -> Bool
    func isSafeRestoreServerPreset() -> Bool

    func safeEnable() -> NSNumber?
    func safePassword() -> String?
    func safePasswordPattern() -> String?
    func safePasswordMessage() -> String?
    func safeServerURL() -> String?
    func safeServerUsername() -> String?
    func safeServerPassword() -> String?

    func disableIDExport() -> Bool
}

// MARK: - MDMSetup + MDMSetupProtocol

extension MDMSetup: MDMSetupProtocol { /* already conforming */ }

#if DEBUG

    public final class MockMDMSetup: MDMSetupProtocol {
        var mockIsSafeBackupForce = false
        var mockIsSafeBackupServerPreset = false
        var mockIsSafeBackupDisable = false
        var mockIsSafeBackupPasswordPreset = false
        var mockIsSafeRestoreDisable = false
        var mockIsSafeRestoreForce = false
        var mockIsSafeRestorePasswordPreset = false
        var mockIsSafeRestoreServerPreset = false

        var mockSafeEnable: NSNumber? = NSNumber(integerLiteral: 1)
        var mockSafePass: String?
        var mockSafePasswordPattern: String?
        var mockSafePasswordMessage: String?
        var mockSafeServerURL: String?
        var mockSafeServerUsername: String?
        var mockSafeServerPassword: String?

        var mockDisableIDExport = false

        public init() { /* no-op */ }

        public func isSafeBackupForce() -> Bool { mockIsSafeBackupForce }

        public func isSafeBackupServerPreset() -> Bool { mockIsSafeBackupServerPreset }

        public func isSafeBackupDisable() -> Bool { mockIsSafeBackupDisable }

        public func isSafeBackupPasswordPreset() -> Bool { mockIsSafeBackupPasswordPreset }

        public func isSafeRestoreDisable() -> Bool { mockIsSafeRestoreDisable }

        public func isSafeRestoreForce() -> Bool { mockIsSafeRestoreForce }

        public func isSafeRestorePasswordPreset() -> Bool { mockIsSafeRestorePasswordPreset }

        public func isSafeRestoreServerPreset() -> Bool { mockIsSafeRestoreServerPreset }

        public func safeEnable() -> NSNumber? { mockSafeEnable }

        public func safePassword() -> String? { mockSafePass }

        public func safePasswordPattern() -> String? { mockSafePasswordPattern }

        public func safePasswordMessage() -> String? { mockSafePasswordMessage }

        public func safeServerURL() -> String? { mockSafeServerURL }

        public func safeServerUsername() -> String? { mockSafeServerUsername }

        public func safeServerPassword() -> String? { mockSafeServerPassword }

        public func disableIDExport() -> Bool { mockDisableIDExport }
    }

    extension MDMSetupProtocol where Self == MockMDMSetup {
        public static var mock: Self { .init() }

        public static var safePasswordPreset: Self {
            let m = MockMDMSetup()
            m.mockIsSafeBackupPasswordPreset = true
            m.mockSafePass = "q1w2e3r4!@#"
            return m
        }

        public static var safeServerPreset: Self {
            let m = MockMDMSetup()
            m.mockIsSafeBackupServerPreset = true
            m.mockSafeServerURL = "https://any-server.com"
            return m
        }

        public static var safePasswordAndServerPreset: Self {
            let m = MockMDMSetup()
            m.mockIsSafeBackupServerPreset = true
            m.mockSafeServerURL = "https://any-server.com"
            m.mockIsSafeBackupPasswordPreset = true
            m.mockSafePass = "q1w2e3r4!@#"
            return m
        }

        public static var safeForced: Self {
            let m = MockMDMSetup()
            m.mockIsSafeBackupForce = true
            return m
        }

        public static var safeForcedWithPasswordPreset: Self {
            let m = MockMDMSetup()
            m.mockIsSafeBackupForce = true
            m.mockSafePass = "q1w2e3r4!@#"
            m.mockIsSafeBackupPasswordPreset = true
            return m
        }

        public static var safeForcedWithServerPreset: Self {
            let m = MockMDMSetup()
            m.mockIsSafeBackupForce = true

            m.mockIsSafeBackupServerPreset = true
            m.mockSafeServerURL = "https://any-server.com"

            return m
        }

        public static var safeForcedWithPasswordAndServerPreset: Self {
            let m = MockMDMSetup()
            m.mockIsSafeBackupForce = true

            m.mockSafePass = "q1w2e3r4!@#"
            m.mockIsSafeBackupPasswordPreset = true

            m.mockSafeServerURL = "https://any-server.com"
            m.mockIsSafeBackupServerPreset = true

            return m
        }

        public static var safeBackupDisabled: Self {
            let m = MockMDMSetup()
            m.mockIsSafeBackupDisable = true
            return m
        }

        public static var safeRestoreDisabled: Self {
            let m = MockMDMSetup()
            m.mockIsSafeRestoreDisable = true
            return m
        }

        public static var idExportDisabled: Self {
            let m = MockMDMSetup()
            m.mockDisableIDExport = true
            return m
        }
    }

#endif
