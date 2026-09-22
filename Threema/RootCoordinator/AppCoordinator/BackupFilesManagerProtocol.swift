import ThreemaFramework

/// Narrow seam over `BackupFilesManager` so `AppCoordinator` can be tested without touching the
/// real backup-exclusion files. Kept local to `AppCoordinator`: `BackupFilesManager` is only used
/// here, so it does not belong in the shared `AppDependencyContainer`.
protocol BackupFilesManagerProtocol {
    func setIsExcludedFromBackup(exclude: Bool)
}

// MARK: - BackupFilesManager + BackupFilesManagerProtocol

extension BackupFilesManager: BackupFilesManagerProtocol { }
