import DataBackup

/// Reads the data of a local data backup into the app.
///
/// The Threema ID the backup belongs to has to be on the device first, which is
/// ``BackupRestoreIdentityManagerProtocol``.
public protocol BackupRestoreDataManagerProtocol: AnyObject {

    /// Reads the backup at `url` into the app, reporting progress as it goes.
    ///
    /// The stream finishes when the restore is done, and finishes throwing if the backup cannot be read, decrypted or
    /// applied.
    ///
    /// - Precondition: The identity of this backup was restored, so the app already stands on it.
    /// - Parameters:
    ///   - url: The backup file to read.
    ///   - password: Password the backup was encrypted with.
    func restore(url: URL, password: String) -> AsyncThrowingStream<DataRestoreProgress, any Error>
}

#if DEBUG
    import os

    /// In-memory `BackupRestoreDataManagerProtocol` for previews and tests.
    public final class BackupRestoreDataManagerMock: BackupRestoreDataManagerProtocol {

        /// What ``restore(url:password:)`` reports.
        public enum RestoreBehavior: Sendable {
            /// Reports nothing and never finishes, so a screen stays in the state it started in.
            case idle

            /// Reports `progress`, waiting `delay` before each snapshot, and then finishes.
            case succeeding(progress: [DataRestoreProgress], delay: Duration)

            /// Reports `progress` and then fails with `error`.
            case failing(after: [DataRestoreProgress], error: MockError)

            /// Finishes right away without reporting any progress.
            public static let immediateSuccess = Self.succeeding(progress: [], delay: .zero)

            /// Fails right away without reporting any progress.
            public static let immediateFailure = Self.failing(after: [], error: .restoreFailed)
        }

        public enum MockError: Error, LocalizedError, Sendable {
            case restoreFailed

            public var errorDescription: String? {
                "The mock restore failed."
            }
        }

        // MARK: - Lifecycle

        public init(restoreBehavior: RestoreBehavior = .immediateSuccess) {
            self.restoreBehavior = restoreBehavior
        }

        public var restoreBehavior: RestoreBehavior

        public var restoreCallCount: Int {
            restoreCalls.withLock { $0 }
        }

        public func restore(url: URL, password: String) -> AsyncThrowingStream<DataRestoreProgress, any Error> {
            restoreCalls.withLock { $0 += 1 }

            // Read upfront so the replaying task never touches the mock itself.
            let behavior = restoreBehavior
            let (stream, continuation) = AsyncThrowingStream<DataRestoreProgress, any Error>.makeStream()

            let task = Task {
                switch behavior {
                case .idle:
                    break

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

        // MARK: - Helpers

        private let restoreCalls = OSAllocatedUnfairLock(initialState: 0)
    }

    extension BackupRestoreDataManagerProtocol where Self == BackupRestoreDataManagerMock {
        public static var mock: Self {
            BackupRestoreDataManagerMock()
        }
    }
#endif
