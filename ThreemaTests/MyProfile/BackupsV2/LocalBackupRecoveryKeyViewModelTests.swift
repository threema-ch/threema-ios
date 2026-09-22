import DataBackup
import Testing

@testable import Threema

@Suite("Local Backup Recovery Key Tests")
@MainActor
struct LocalBackupRecoveryKeyViewModelTests {

    @Test func `Screen resources are correctly set in the primary language`() {
        let sut = makeSUT(
            currentRecoveryKey: .generated(key: String(repeating: "A1B2C3D4", count: 8))
        )

        sut.onAppear()

        #expect(sut.copyIconName == "document.on.document")
        #expect(sut.deleteIconName == "trash")
        #expect(sut.errorIconName == "exclamationmark.circle")
        #expect(sut.headerSymbolName == "key.fill")
        #expect(sut.createKeyIconName == "chevron.forward")
        #expect(sut.warningIconName == "info.circle")

        #expect(sut.cancelButtonTitle == "Cancel")
        #expect(sut.copyLabel == "Copy")
        #expect(sut.copiedLabel == "Copied!")
        #expect(sut.createKeyLabel == "Create New Key")
        #expect(sut.createKeyDescription == "Generate a new key for future backups")
        #expect(sut.currentKeyLabel == "Current Key")
        #expect(sut.deleteAlertTitle == "Remove recovery key from this device?")
        #expect(sut.deleteAlertMessage == """
            Before removing this key from the app, make sure you’ve saved it safely.
            
            You’ll still need it to restore backups encrypted with this key. If lost, those backups can’t be accessed.
            
            Removing it here won’t invalidate the key and any saved copies will continue to work.
            """)
        #expect(sut.deleteLabel == "Remove key")
        #expect(sut.keyDescription == "This password will be used to encrypt your backup and to restore the backup.")
        #expect(sut.keyTitle == "Recovery Key")
        #expect(sut.saveButtonTitle == "I’ve saved my key")
        #expect(sut.stepLabel == "STEP 1 OF 3")
        #expect(sut.warning == """
            **Important**: This password cannot be recovered if lost. Store it securely in a \
            password manager or write it down and keep it somewhere safe.
            """)
    }

    @Test func `Recovery key info is correctly set in the primary language`() {
        let sut = makeSUT(
            currentRecoveryKey: .default(key: String(repeating: "E1F2G3H4", count: 8), lastBackupDate: Date())
        )

        sut.onAppear()

        #expect(sut.info?.title == "Never share this key with anyone.")
        #expect(sut.info?.content == "Anyone with it can restore your encrypted backup and read your messages.")
    }

    // MARK: - Helpers

    private func makeSUT(currentRecoveryKey: BackupEncryptionKey) -> LocalBackupRecoveryKeyViewModel {
        LocalBackupRecoveryKeyViewModel(
            manager: BackupCreateManagerMock(
                currentRecoveryKey: currentRecoveryKey
            )
        )
    }
}
