import CocoaLumberjackSwift
import Foundation
import Keychain
import os

/// Resolves, generates and persists the recovery key of the local data backups.
///
/// Persistence goes through the `KeychainManager`, so the stored key is encrypted with the remote secret whenever one
/// is in use, like the other secrets of the app.
public final class BackupEncryptionKeyService: BackupEncryptionKeyServiceProtocol {

    // MARK: - Private types

    /// A recovery key and its last backup date, encoded and stored as a single keychain entry.
    private struct StoredEncryptionKey: Codable {
        let key: String
        let lastBackupDate: Date
    }

    // MARK: - Private properties

    private let keychainManager: any KeychainManagerProtocol
    private let recoveryKeyGenerator: any RecoveryKeyGeneratorProtocol
    private let now: @Sendable () -> Date

    private let lockedCurrentKey = OSAllocatedUnfairLock<BackupEncryptionKey>(initialState: .none)

    // MARK: - Public properties

    public var currentKey: BackupEncryptionKey {
        lockedCurrentKey.withLock { $0 }
    }

    // MARK: - Lifecycle

    public init(
        keychainManager: any KeychainManagerProtocol,
        recoveryKeyGenerator: any RecoveryKeyGeneratorProtocol = RecoveryKeyGenerator(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.keychainManager = keychainManager
        self.recoveryKeyGenerator = recoveryKeyGenerator
        self.now = now

        // TODO: Surface an error to the user if the key cannot be resolved
        do {
            try resolveKey()
        }
        catch {
            DDLogError("Couldn't resolve the backup encryption key: \(error)")
        }
    }

    // MARK: - Public methods

    public func renewKey() throws {
        let key = try generatedKey()
        try deleteKey()
        setCurrentKey(key)
    }

    public func deleteKey() throws {
        do {
            try keychainManager.deleteDataBackupRecoveryKey()
        }
        catch {
            DDLogError("Couldn't delete the backup encryption key from the keychain: \(error)")
            throw error
        }

        setCurrentKey(.none)
    }

    public func markKeyAsDefault() throws {
        let usedKey = BackupEncryptionKey.default(key: currentKey.rawValue, lastBackupDate: now())
        try save(usedKey)
        setCurrentKey(usedKey)
    }

    // MARK: - Private methods

    private func setCurrentKey(_ key: BackupEncryptionKey) {
        lockedCurrentKey.withLock { $0 = key }
    }

    private func resolveKey() throws {
        let key = try load()
        if case .none = key {
            let newKey = try generatedKey()
            setCurrentKey(newKey)
        }
        else {
            setCurrentKey(key)
        }
    }

    private func generatedKey() throws -> BackupEncryptionKey {
        do {
            return try .generated(key: recoveryKeyGenerator.generate())
        }
        catch {
            DDLogError("Couldn't generate a backup encryption key: \(error)")
            throw error
        }
    }

    private func load() throws -> BackupEncryptionKey {
        let storedData: Data?
        do {
            storedData = try keychainManager.loadDataBackupRecoveryKey()
        }
        catch {
            DDLogError("Couldn't load the backup encryption key from the keychain: \(error)")
            throw error
        }

        guard let storedData else {
            return .none
        }

        do {
            let stored = try JSONDecoder().decode(StoredEncryptionKey.self, from: storedData)
            return .default(key: stored.key, lastBackupDate: stored.lastBackupDate)
        }
        catch {
            DDLogError("Couldn't decode the stored backup encryption key: \(error)")
            throw error
        }
    }

    private func save(_ key: BackupEncryptionKey) throws {
        // Only the default key (used for a successful backup) is persisted; a generated key stays in memory.
        guard case let .default(recoveryKey, lastBackupDate) = key else {
            return
        }

        let stored = StoredEncryptionKey(key: recoveryKey, lastBackupDate: lastBackupDate)

        let data: Data
        do {
            data = try JSONEncoder().encode(stored)
        }
        catch {
            DDLogError("Couldn't encode the backup encryption key: \(error)")
            throw error
        }

        do {
            try keychainManager.storeDataBackupRecoveryKey(data)
        }
        catch {
            DDLogError("Couldn't store the backup encryption key in the keychain: \(error)")
            throw error
        }
    }
}
