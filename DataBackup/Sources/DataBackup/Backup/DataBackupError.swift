import Foundation

public enum DataBackupError: Error, LocalizedError, Equatable {
    case backupCreateFileFailed
    case remoteBackupNotSupported

    public var errorDescription: String? {
        switch self {
        case .backupCreateFileFailed:
            "Failed to create a backup file"
        case .remoteBackupNotSupported:
            "Remote backups are not supported"
        }
    }
}
