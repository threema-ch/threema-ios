import DataBackup
import Testing

@testable import Threema

@Suite("Local Backup Recovery Key Tests")
@MainActor
struct LocalBackupRecoveryKeyConfirmationViewModelTests {

    @Test func `Screen resources are correctly set in the primary language`() {
        let sut = LocalBackupRecoveryKeyConfirmationViewModel(manager: .mock)

        #expect(sut.continueButtonTitle == "Continue")
        #expect(sut.headerTitle == "Confirm your key")
        #expect(sut.headerSubtitle == "Type the last digits of your recovery key to confirm you’ve saved it correctly.")
        #expect(sut.headerIconName == "key")
        #expect(sut.stepLabel == "STEP 1 OF 3")
        #expect(sut.prompt == "e.g.N9CQ")
        #expect(sut.recoveryKeyHeader == "Recovery key")
        #expect(sut.confirmationError == "Key does not match. Try again.")
    }
}
