import Foundation

public enum DataBackupError: Error, LocalizedError, Equatable {
    case backupCreateFileFailed
    case backupCreateFileWrittenBytesMismatch(actual: UInt64, expected: UInt64)
    case remoteBackupNotSupported

    public var errorDescription: String? {
        switch self {
        case .backupCreateFileFailed:
            "Failed to create a backup file"
        case let .backupCreateFileWrittenBytesMismatch(actual, expected):
            """
            Failed to write the correct number of bytes to the backup file.
            Expected: \(expected), got \(actual) instead.
            """
        case .remoteBackupNotSupported:
            "Remote backups are not supported"
        }
    }
}
