import DataBackup

/// Creates local data backups, and owns the recovery key their encryption is based on.
///
/// Reading one back is ``BackupRestoreDataManager``.
///
/// One manager instance owns one recovery key state, so the screens of a backup flow have to share the same instance
/// to agree on the key they show and confirm.
public protocol BackupCreateManagerProtocol: AnyObject {

    /// The recovery key of the next backup: the default key persisted in the keychain, or a freshly generated key that
    /// only becomes the default once a backup completed successfully with it.
    ///
    /// `.none` while no key is resolved, which is also the state right after ``deleteDefaultRecoveryKey()``.
    var currentRecoveryKey: BackupEncryptionKey { get }

    /// What the next backup includes.
    var backupSettings: BackupMetadata { get set }

    /// Where a local backup is written to.
    var backupURL: URL { get }

    /// The most recent backup that completed, or `nil` if none ever has.
    ///
    /// Persisted, so this outlives the app session it was written in.
    var lastBackup: BackupMetadata? { get }

    /// Writes a backup of this ID and its data to `url`, reporting progress as it goes.
    ///
    /// - Parameters:
    ///   - url: Destination of the backup file.
    ///   - password: Password the backup is encrypted with.
    func create(url: URL, password: String) -> AsyncThrowingStream<DataBackupProgress, any Error>

    /// Records the backup at ``backupURL`` as the most recent one, persisting when it was made, how big it is and what
    /// it includes.
    ///
    /// - Throws: If there is no readable file at ``backupURL``, or the record could not be written. A backup that
    ///           cannot be recorded is not usable, because the details screen shows nothing else.
    func recordSuccessfulBackup() throws

    /// Deletes a persisted default key and generates a fresh key in its place.
    ///
    /// The fresh key is held in memory only until a backup succeeds with it, so it is lost if the app terminates
    /// before that — which is why the user is asked to write it down.
    func createNewRecoveryKey() throws

    /// Deletes the default key from the keychain and resets ``currentRecoveryKey`` to `.none`.
    ///
    /// - Important: Backups made with that key stay encrypted with it, so they can only be restored with the copy the
    ///              user saved.
    func deleteDefaultRecoveryKey() throws

    /// Deletes the backup file from disk
    func removePreviousBackup() throws
}

#if DEBUG
    import os

    /// In-memory `BackupCreateManagerProtocol` for previews and tests.
    public final class BackupCreateManagerMock: BackupCreateManagerProtocol {

        /// What ``create(url:password:)`` reports.
        public enum CreateBehavior: Sendable {
            /// Reports nothing and never finishes, so a screen stays in the state it started in.
            case idle

            /// Reports `progress` and then never finishes, so a screen stays mid-backup.
            case stalling(after: [DataBackupProgress])

            /// Reports `progress`, waiting `delay` before each snapshot, and then finishes.
            case succeeding(progress: [DataBackupProgress], delay: Duration)

            /// Reports `progress` and then fails with `error`.
            case failing(after: [DataBackupProgress], error: MockError)

            /// Finishes right away without reporting any progress.
            public static let immediateSuccess = Self.succeeding(progress: [], delay: .zero)

            /// Fails right away without reporting any progress.
            public static let immediateFailure = Self.failing(after: [], error: .createFailed)
        }

        public enum MockError: Error, LocalizedError, Sendable {
            case createFailed
            case recordFailed

            public var errorDescription: String? {
                switch self {
                case .createFailed:
                    "The mock backup failed."
                case .recordFailed:
                    "The mock backup could not be recorded."
                }
            }
        }

        // MARK: - Lifecycle

        public init(
            currentRecoveryKey: BackupEncryptionKey = .generated(key: String(repeating: "A1B2C3D4", count: 8)),
            createBehavior: CreateBehavior = .immediateSuccess
        ) {
            self.currentRecoveryKey = currentRecoveryKey
            self.createBehavior = createBehavior
        }

        public var currentRecoveryKey: BackupEncryptionKey = .none
        public var backupSettings = BackupMetadata()
        public var createBehavior: CreateBehavior

        /// The record ``lastBackup`` reports. Set to `nil` for a manager that never made a backup.
        public var lastBackup: BackupMetadata? = BackupMetadata(
            date: Date(timeIntervalSince1970: 1_775_030_400), // 2026-04-01 08:00 UTC
            size: 1_288_490_188,
            includesMessages: true,
            includesMedia: true
        )

        /// An error ``recordSuccessfulBackup()`` throws instead of recording anything.
        public var mockRecordError: MockError?

        /// Number of ``recordSuccessfulBackup()`` calls so far.
        public private(set) var recordSuccessfulBackupCallCount = 0

        // Matches where the real manager writes, so a location derived from it
        // reads the same in previews and tests. Nothing is ever written through the mock.
        public var backupURL = URL.documentsDirectory
            .appending(path: "Backup", directoryHint: .notDirectory)
            .appendingPathExtension("dat")

        public func recordSuccessfulBackup() throws {
            recordSuccessfulBackupCallCount += 1

            if let mockRecordError {
                throw mockRecordError
            }

            lastBackup = BackupMetadata(
                date: Date(),
                size: 1_288_490_188,
                includesMessages: backupSettings.includesMessages,
                includesMedia: backupSettings.includesMedia
            )
        }

        public var createCallCount: Int {
            createCalls.withLock { $0 }
        }

        public func create(url: URL, password: String) -> AsyncThrowingStream<DataBackupProgress, any Error> {
            createCalls.withLock { $0 += 1 }

            // Read upfront so the replaying task never touches the mock itself.
            let behavior = createBehavior
            let (stream, continuation) = AsyncThrowingStream<DataBackupProgress, any Error>.makeStream()

            let task = Task {
                switch behavior {
                case .idle:
                    break

                case let .stalling(progress):
                    for progress in progress {
                        continuation.yield(progress)
                    }

                case let .succeeding(progress, delay):
                    for progress in progress {
                        if delay > .zero {
                            try? await Task.sleep(for: delay)
                        }
                        continuation.yield(progress)
                    }
                    continuation.finish()

                case let .failing(progress, error):
                    for progress in progress {
                        continuation.yield(progress)
                    }
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }

            return stream
        }

        public func createNewRecoveryKey() throws { /* no-op */ }

        public func deleteDefaultRecoveryKey() throws { /* no-op */ }

        public func deleteRecoveryKey(at index: Int) throws { /* no-op */ }

        public func removePreviousBackup() throws { /* no-op */ }

        // MARK: - Helpers

        private let createCalls = OSAllocatedUnfairLock(initialState: 0)
    }

    extension BackupCreateManagerProtocol where Self == BackupCreateManagerMock {
        public static var mock: Self {
            BackupCreateManagerMock()
        }
    }
#endif
