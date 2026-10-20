import DataBackup
import Foundation
import Testing

@Suite("Backup Encryption Key Tests")
struct BackupEncryptionKeyTests {

    @Test func `trimmedValue keeps the first and last four characters of a long key`() {
        let key = BackupEncryptionKey.generated(key: String(repeating: "A1B2C3D4", count: 8))

        #expect(key.trimmedValue == "A1B2...C3D4")
    }

    @Test func `trimmedValue returns a key of eight characters or less unchanged`() {
        let key = BackupEncryptionKey.default(key: "A1B2C3D4", lastBackupDate: Date())

        #expect(key.trimmedValue == "A1B2C3D4")
    }

    @Test func `trimmedValue of an unresolved key is empty`() {
        #expect(BackupEncryptionKey.none.trimmedValue.isEmpty)
    }
}
