public enum BackupCreateManagerError: Error {
    /// There is no Threema ID to back up.
    case missingIdentity

    /// The Threema ID has no private key to back up.
    case missingClientKey

    /// The Threema ID has no chat server group to back up.
    case missingChatServerGroup

    /// Nothing readable where the backup was just written.
    case missingBackupFile

    /// The backup already on the device could not be deleted.
    case deletionPreviousBackupFailed
}
