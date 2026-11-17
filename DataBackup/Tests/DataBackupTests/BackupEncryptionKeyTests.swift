import DataBackup
import Foundation
import Testing

@Suite("Backup Encryption Key Tests")
struct BackupEncryptionKeyTests {

    @Test func `rawValue of a generated key is the key`() {
        let key = BackupEncryptionKey.generated(key: "A1B2C3D4")

        #expect(key.rawValue == "A1B2C3D4")
    }

    @Test func `rawValue of a default key is the key`() {
        let key = BackupEncryptionKey.default(key: "A1B2C3D4", lastBackupDate: Date())

        #expect(key.rawValue == "A1B2C3D4")
    }

    @Test func `rawValue of an unresolved key is empty`() {
        #expect(BackupEncryptionKey.none.rawValue.isEmpty)
    }

    @Test func `abbreviatedValue keeps the first and last four characters of a long key`() {
        let key = BackupEncryptionKey.generated(key: String(repeating: "A1B2C3D4", count: 8))

        #expect(key.abbreviatedValue == "A1B2...C3D4")
    }

    @Test func `abbreviatedValue abbreviates a key of nine characters`() {
        let key = BackupEncryptionKey.generated(key: "A1B2C3D4E")

        #expect(key.abbreviatedValue == "A1B2...3D4E")
    }

    @Test(arguments: ["", "A", "A1B2", "A1B2C3D", "A1B2C3D4"])
    func `abbreviatedValue returns a key of eight characters or less unchanged`(rawKey: String) {
        let key = BackupEncryptionKey.default(key: rawKey, lastBackupDate: Date())

        #expect(key.abbreviatedValue == rawKey)
    }

    @Test func `abbreviatedValue of an unresolved key is empty`() {
        #expect(BackupEncryptionKey.none.abbreviatedValue.isEmpty)
    }

    @Test func `isDefault is true for a default key`() {
        #expect(BackupEncryptionKey.default(key: "A1B2C3D4", lastBackupDate: Date()).isDefault)
    }

    @Test func `isDefault is false for a generated key`() {
        #expect(!BackupEncryptionKey.generated(key: "A1B2C3D4").isDefault)
    }

    @Test func `isDefault is false for an unresolved key`() {
        #expect(!BackupEncryptionKey.none.isDefault)
    }

    @Test func `lastBackupDate of a default key is the stored date`() {
        let date = Date(timeIntervalSince1970: 1_234_567_890)
        let key = BackupEncryptionKey.default(key: "A1B2C3D4", lastBackupDate: date)

        #expect(key.lastBackupDate == date)
    }

    @Test func `lastBackupDate of a generated key is nil`() {
        #expect(BackupEncryptionKey.generated(key: "A1B2C3D4").lastBackupDate == nil)
    }

    @Test func `lastBackupDate of an unresolved key is nil`() {
        #expect(BackupEncryptionKey.none.lastBackupDate == nil)
    }

    @Test func `prettyFormatted separates a 64 character key into groups of four`() {
        let key = BackupEncryptionKey.generated(
            key: "45S9KSPB6JVQZ12Y99BX8MS744Y4HNJSX19HQ7C4A7Q4WSZU722X789T745QT418"
        )

        #expect(
            key.prettyFormatted
                == "45S9-KSPB-6JVQ-Z12Y-99BX-8MS7-44Y4-HNJS-X19H-Q7C4-A7Q4-WSZU-722X-789T-745Q-T418"
        )
    }

    @Test(arguments: [
        (rawKey: "A1B2C3D4", expected: "A1B2-C3D4"),
        (rawKey: "A1B2C3D4E", expected: "A1B2-C3D4-E"),
        (rawKey: "A1B2C3", expected: "A1B2-C3"),
        (rawKey: "A1B2", expected: "A1B2"),
        (rawKey: "A1", expected: "A1"),
    ])
    func `prettyFormatted groups keys of various lengths`(rawKey: String, expected: String) {
        let key = BackupEncryptionKey.default(key: rawKey, lastBackupDate: Date())

        #expect(key.prettyFormatted == expected)
    }

    @Test func `prettyFormatted has no leading or trailing separator`() {
        let formatted = BackupEncryptionKey.generated(key: "A1B2C3D4E5F6G7H8").prettyFormatted

        #expect(formatted.first != BackupEncryptionKey.prettyFormatSeparator)
        #expect(formatted.last != BackupEncryptionKey.prettyFormatSeparator)
    }

    @Test func `prettyFormatted removing separators returns the raw value`() {
        let key = BackupEncryptionKey.default(key: "A1B2C3D4E5F6G7H8J", lastBackupDate: Date())

        #expect(key.prettyFormatted.filter { $0 != BackupEncryptionKey.prettyFormatSeparator } == key.rawValue)
    }

    @Test func `prettyFormatted of an unresolved key is empty`() {
        #expect(BackupEncryptionKey.none.prettyFormatted.isEmpty)
    }
}
