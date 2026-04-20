protocol SafeManagerProtocol {
    var isActivated: Bool { get }
    var isBackupRunning: Bool { get }

    func deactivate()

    func testServer(
        serverURL: URL,
        user: String?,
        password: String?
    ) async throws -> (maxBackupBytes: Int, retentionDays: Int)

    func activate(
        identity: String,
        safePassword: String?,
        customServer: String?,
        serverUser: String?,
        serverPassword: String?,
        server: String?,
        maxBackupBytes: NSNumber?,
        retentionDays: NSNumber?
    ) async throws

    func startBackup(force: Bool) async throws
}

#if DEBUG

    final class MockSafeManager: SafeManagerProtocol {
        static var mockIsPasswordBad = false
        var mockIsActivated = false
        var mockIsBackupRunning = false
        var mockTestServerReturn: Result<(maxBackupBytes: Int, retentionDays: Int), Error> = .success((1000, 3))
        var mockActivateReturn: Result<Void, Error> = .success(())
        var mockStartBackupReturn: Result<Void, Error> = .success(())
        var verifyActivateCalls: [
            (
                identity: String,
                safePassword: String?,
                customServer: String?,
                serverUser: String?,
                serverPassword: String?,
                server: String?,
                maxBackupBytes: NSNumber?,
                retentionDays: NSNumber?
            )
        ] = []

        var verifyDeactivateCalls = 0

        var verifyStartBackupCalls: [Bool] = []

        var isActivated: Bool {
            mockIsActivated
        }

        var isBackupRunning: Bool {
            mockIsBackupRunning
        }

        func deactivate() {
            verifyDeactivateCalls += 1
            mockIsActivated = false
        }

        func testServer(
            serverURL: URL,
            user: String?,
            password: String?
        ) async throws -> (maxBackupBytes: Int, retentionDays: Int) {
            try mockTestServerReturn.get()
        }

        func activate(
            identity: String,
            safePassword: String?,
            customServer: String?,
            serverUser: String?,
            serverPassword: String?,
            server: String?,
            maxBackupBytes: NSNumber?,
            retentionDays: NSNumber?
        ) async throws {
            verifyActivateCalls.append((
                identity: identity,
                safePassword: safePassword,
                customServer: customServer,
                serverUser: serverUser,
                serverPassword: serverPassword,
                server: server,
                maxBackupBytes: maxBackupBytes,
                retentionDays: retentionDays
            ))
            try mockActivateReturn.get()
            mockIsActivated = true
        }

        func startBackup(force: Bool) async throws {
            verifyStartBackupCalls.append(force)
            mockStartBackupReturn = .success(())
        }
    }

    extension SafeManagerProtocol where Self == MockSafeManager {
        static var mock: Self { activated }
        
        static var deactivated: Self {
            let m = MockSafeManager()
            m.mockIsActivated = false
            return m
        }

        static var activated: Self {
            let m = MockSafeManager()
            m.mockIsActivated = true
            return m
        }
    }

#endif
