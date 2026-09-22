public protocol BackupEncryptionKeyServiceProtocol: Sendable, AnyObject {

    /// The current recovery key, resolved from the keychain (or freshly generated) at initialization.
    var currentKey: BackupEncryptionKey { get }

    /// Discards any stored default key (deleting it from the keychain) and generates a fresh key.
    ///
    /// The freshly generated key is kept in memory only; it is not persisted until it has been used
    /// for a successful backup
    func renewKey() throws

    /// Deletes the stored default key from the keychain and resets the current key to `.none`.
    func deleteKey() throws

    /// Persists the current key as the default — the key reused for the next backup — stamped with
    /// the backup date. Call this after a backup completes successfully with the current key.
    func markKeyAsDefault() throws
}
