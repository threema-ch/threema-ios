import Foundation
import ThreemaEssentials

/// Takes the Threema ID out of a local data backup, and nothing else.
///
/// Reading the backup's data in afterwards is ``BackupRestoreDataManagerProtocol``.
public protocol BackupRestoreIdentityManagerProtocol: AnyObject {

    /// Reads the backup at `url` only as far as the identity it belongs to, restores that identity, and stops.
    ///
    /// None of the backup's data is applied, and no database is touched, so this can run before the app is migrated.
    ///
    /// - Parameters:
    ///   - url: The backup file to read.
    ///   - password: Password the backup was encrypted with.
    /// - Returns: The identity the backup belongs to.
    /// - Throws: If the backup cannot be read, decrypted, or holds no identity.
    func restoreIdentity(from url: URL, password: String) async throws -> ThreemaIdentity
}

#if DEBUG
    /// In-memory `BackupRestoreIdentityManagerProtocol` for previews and tests.
    public final class BackupRestoreIdentityManagerMock: BackupRestoreIdentityManagerProtocol {

        public enum MockError: Error, LocalizedError, Sendable {
            case restoreFailed

            public var errorDescription: String? {
                "The mock identity restore failed."
            }
        }

        // MARK: - Lifecycle

        public init(
            identity: ThreemaIdentity = ThreemaIdentity("ECHOECHO"),
            mockError: MockError? = nil
        ) {
            self.identity = identity
            self.mockError = mockError
        }

        /// The identity ``restoreIdentity(from:password:)`` reports.
        public var identity: ThreemaIdentity

        /// An error ``restoreIdentity(from:password:)`` throws instead of reporting an identity.
        public var mockError: MockError?

        /// Number of ``restoreIdentity(from:password:)`` calls so far.
        public private(set) var restoreIdentityCallCount = 0

        public func restoreIdentity(from url: URL, password: String) async throws -> ThreemaIdentity {
            restoreIdentityCallCount += 1

            if let mockError {
                throw mockError
            }

            return identity
        }
    }

    extension BackupRestoreIdentityManagerProtocol where Self == BackupRestoreIdentityManagerMock {
        public static var mock: Self {
            BackupRestoreIdentityManagerMock()
        }
    }
#endif
