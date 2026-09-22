public enum BackupRestoreDataManagerError: Error {
    /// The backup belongs to another identity than the one on the device.
    case identityNotRestored
}
