// MARK: - BootstrapBackupStoreProtocol

@MainActor
protocol BootstrapBackupStoreProtocol {
    func loadIdentityBackup() -> String?
    func isValidBackupFormat(_ backup: String) -> Bool
}

// MARK: - BootstrapBackupStoreAdapter

@MainActor
final class BootstrapBackupStoreAdapter: BootstrapBackupStoreProtocol {
    func isValidBackupFormat(_ backup: String) -> Bool {
        IdentityBackupStore.isValidBackupFormat(backup)
    }
    
    func loadIdentityBackup() -> String? {
        IdentityBackupStore.loadIdentityBackup()
    }
}
