import Observation
import ThreemaMacros

@MainActor
@Observable
final class LocalBackupRecoveryKeyConfirmationViewModel {
    // MARK: - Public types

    enum MessageType: Equatable {
        case none
        case error(String)
        case success
    }

    // MARK: - Public properties

    let confirmationError = #localize("backup_local_recovery_key_confirmation_message_error")
    let continueButtonTitle = #localize("continue")
    let headerTitle = #localize("backup_local_recovery_key_confirmation_title")
    let headerSubtitle = #localize("backup_local_recovery_key_confirmation_description")
    let prompt = #localize("for_example_abbreviation") + "N9CQ"
    let recoveryKeyHeader = #localize("Recovery_key")
    let stepLabel = String.localizedStringWithFormat(#localize("step_count_from_total_steps"), 1, 3).uppercased()
    let headerIconName = "key"

    var enteredLastDigits: String = ""
    @ObservationIgnored var onContinueButtonTapped: () -> Void = { /* no-op */ }

    var message: MessageType {
        guard hasEnoughDigits else {
            return .none
        }

        if codesAreMatching {
            return .success
        }
        else {
            return .error(confirmationError)
        }
    }

    var isContinueButtonDisabled: Bool {
        !codesAreMatching
    }

    // MARK: - Private properties

    private let manager: any BackupCreateManagerProtocol

    private static let lastDigitsCount = 4

    private var keyLastDigits: String {
        String(key.suffix(Self.lastDigitsCount))
    }

    private var key: String {
        manager.currentRecoveryKey.rawValue
    }

    private var hasEnoughDigits: Bool {
        enteredLastDigits.count >= Self.lastDigitsCount
    }

    private var codesAreMatching: Bool {
        let expected = keyLastDigits.uppercased()
        let entered = enteredLastDigits
            .trimmingCharacters(in: .whitespaces)
            .uppercased()

        return !expected.isEmpty && expected == entered
    }

    // MARK: - Lifecycle

    init(manager: any BackupCreateManagerProtocol) {
        self.manager = manager
    }

    // MARK: - Public methods

    func continueButtonTapped() {
        onContinueButtonTapped()
    }
}
