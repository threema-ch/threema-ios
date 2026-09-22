import DataBackup
import Foundation
import KeychainTestHelper
import Testing

@Suite("Backup Encryption Key Service Tests")
struct BackupEncryptionKeyServiceTests {

    @Test func `Generates a fresh in-memory key when the keychain is empty`() throws {
        let keychain = KeychainManagerMock()

        let sut = BackupEncryptionKeyService(
            keychainManager: keychain,
            recoveryKeyGenerator: FixedRecoveryKeyGenerator(key: "GENERATED")
        )

        #expect(sut.currentKey.rawValue == "GENERATED")
        #expect(sut.currentKey.isDefault == false)
        #expect(try keychain.loadDataBackupRecoveryKey() == nil)
    }

    @Test func `markKeyAsDefault persists the key so a new service loads it as the default`() throws {
        let date = Date(timeIntervalSinceReferenceDate: 1000)
        let keychain = KeychainManagerMock()

        let service = BackupEncryptionKeyService(
            keychainManager: keychain,
            recoveryKeyGenerator: FixedRecoveryKeyGenerator(key: "REUSABLE"),
            now: { date }
        )
        #expect(service.currentKey.isDefault == false)
        #expect(try keychain.loadDataBackupRecoveryKey() == nil)

        try service.markKeyAsDefault()

        #expect(service.currentKey.isDefault)
        #expect(service.currentKey.rawValue == "REUSABLE")
        #expect(service.currentKey.lastBackupDate == date)

        // A brand-new service backed by the same keychain must load the persisted default.
        let reloaded = BackupEncryptionKeyService(
            keychainManager: keychain,
            recoveryKeyGenerator: FixedRecoveryKeyGenerator(key: "UNUSED")
        )
        #expect(reloaded.currentKey.isDefault)
        #expect(reloaded.currentKey.rawValue == "REUSABLE")
        #expect(reloaded.currentKey.lastBackupDate == date)
    }

    @Test func `deleteKey removes the persisted key and resets to none`() throws {
        let keychain = makeKeychainWithStoredDefault(key: "OLD", date: Date(timeIntervalSinceReferenceDate: 1000))

        let sut = BackupEncryptionKeyService(
            keychainManager: keychain,
            recoveryKeyGenerator: FixedRecoveryKeyGenerator(key: "IGNORED")
        )
        #expect(sut.currentKey.isDefault) // Precondition: the stored default was loaded.

        try sut.deleteKey()

        let isNone: Bool =
            if case .none = sut.currentKey {
                true
            }
            else {
                false
            }
        #expect(isNone)
        #expect(try keychain.loadDataBackupRecoveryKey() == nil)
    }

    @Test func `renewKey discards the stored default and generates a fresh key`() throws {
        let keychain = makeKeychainWithStoredDefault(key: "OLD", date: Date(timeIntervalSinceReferenceDate: 1000))

        let sut = BackupEncryptionKeyService(
            keychainManager: keychain,
            recoveryKeyGenerator: FixedRecoveryKeyGenerator(key: "FRESH")
        )
        #expect(sut.currentKey.isDefault) // Precondition.

        try sut.renewKey()

        #expect(sut.currentKey.rawValue == "FRESH")
        #expect(sut.currentKey.isDefault == false)
        // The previously stored default is deleted and the fresh key is not persisted.
        #expect(try keychain.loadDataBackupRecoveryKey() == nil)
    }

    // MARK: - Helpers

    private func makeKeychainWithStoredDefault(key: String, date: Date) -> KeychainManagerMock {
        let keychain = KeychainManagerMock()
        let seeder = BackupEncryptionKeyService(
            keychainManager: keychain,
            recoveryKeyGenerator: FixedRecoveryKeyGenerator(key: key),
            now: { date }
        )
        try? seeder.markKeyAsDefault()
        return keychain
    }
}

// MARK: - Test doubles

private struct FixedRecoveryKeyGenerator: RecoveryKeyGeneratorProtocol {
    let key: String
    func generate() throws -> String { key }
}
