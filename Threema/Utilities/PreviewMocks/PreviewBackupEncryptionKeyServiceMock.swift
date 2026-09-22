#if DEBUG

    import DataBackup

    public final class PreviewBackupEncryptionKeyServiceMock: BackupEncryptionKeyServiceProtocol {

        // MARK: - Public types

        public enum Call: Equatable, Sendable {
            case renewKey
            case deleteKey
            case markKeyAsDefault
        }

        // MARK: - Private types

        private struct State {
            var currentKey: BackupEncryptionKey
            var calls: [Call] = []
            var mockRenewKey: @Sendable () throws -> Void = { /* no-op */ }
            var mockDeleteKey: @Sendable () throws -> Void = { /* no-op */ }
            var mockMarkKeyAsDefault: @Sendable () throws -> Void = { /* no-op */ }
        }

        // MARK: - Private properties

        private let state: OSAllocatedUnfairLock<State>

        // MARK: - Lifecycle

        public init(currentKey: BackupEncryptionKey = .none) {
            state = OSAllocatedUnfairLock(initialState: State(currentKey: currentKey))
        }

        // MARK: - Public properties

        public var currentKey: BackupEncryptionKey {
            get { state.withLock { $0.currentKey } }
            set { state.withLock { $0.currentKey = newValue } }
        }

        public var calls: [Call] {
            state.withLock { $0.calls }
        }

        public var mockRenewKey: @Sendable () throws -> Void {
            get { state.withLock { $0.mockRenewKey } }
            set { state.withLock { $0.mockRenewKey = newValue } }
        }

        public var mockDeleteKey: @Sendable () throws -> Void {
            get { state.withLock { $0.mockDeleteKey } }
            set { state.withLock { $0.mockDeleteKey = newValue } }
        }

        public var mockMarkKeyAsDefault: @Sendable () throws -> Void {
            get { state.withLock { $0.mockMarkKeyAsDefault } }
            set { state.withLock { $0.mockMarkKeyAsDefault = newValue } }
        }

        // MARK: - Public methods

        public func reset() {
            state.withLock { $0.calls.removeAll() }
        }

        public func renewKey() throws {
            let stub: @Sendable () throws -> Void = state.withLock {
                $0.calls.append(.renewKey)
                return $0.mockRenewKey
            }
            try stub()
        }

        public func deleteKey() throws {
            let stub: @Sendable () throws -> Void = state.withLock {
                $0.calls.append(.deleteKey)
                return $0.mockDeleteKey
            }
            try stub()
        }

        public func markKeyAsDefault() throws {
            let stub: @Sendable () throws -> Void = state.withLock {
                $0.calls.append(.markKeyAsDefault)
                return $0.mockMarkKeyAsDefault
            }
            try stub()
        }
    }

    extension BackupEncryptionKeyServiceProtocol where Self == PreviewBackupEncryptionKeyServiceMock {
        public static var returningNone: Self {
            PreviewBackupEncryptionKeyServiceMock(
                currentKey: .none
            )
        }

        public static func returningGeneratedKey(
            _ key: String = String(repeating: "A1B2C3D4", count: 8)
        ) -> Self {
            PreviewBackupEncryptionKeyServiceMock(
                currentKey: .generated(key: key)
            )
        }

        public static func returningDefaultKey(
            _ key: String = String(repeating: "A1B2C3D4", count: 8),
            date: Date = .now
        ) -> Self {
            PreviewBackupEncryptionKeyServiceMock(
                currentKey: .default(key: key, lastBackupDate: date)
            )
        }
    }

#endif
