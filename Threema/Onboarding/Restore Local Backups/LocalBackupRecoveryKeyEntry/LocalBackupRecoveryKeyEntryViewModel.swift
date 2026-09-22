import Observation
import ThreemaMacros

@MainActor
@Observable
final class LocalBackupRecoveryKeyEntryViewModel {
    let continueButtonTitle = #localize("continue")
    let headerTitle = #localize("restore_backup_title")
    let headerSubtitle = #localize("backup_local_recovery_key_description")
    let keyFieldHeader = #localize("backup_recovery_key")
    let symbolName = "key.fill"

    var enteredKey = ""

    @ObservationIgnored
    var onContinueButtonTapped: (String) -> Void = { _ in /* no-op */ }

    var recoveryKey: String {
        enteredKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isContinueButtonDisabled: Bool {
        recoveryKey.isEmpty
    }

    // MARK: - Internal methods

    func continueButtonTapped() {
        onContinueButtonTapped(recoveryKey)
    }
}
