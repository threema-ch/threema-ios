import CocoaLumberjackSwift
import DataBackup
import Observation
import ThreemaFramework
import ThreemaMacros

@MainActor
@Observable
final class LocalBackupCreateBackupViewModel {

    // MARK: Internal Types

    enum State {
        case inProgress
        case complete
        case failed

        var headerIconName: String {
            switch self {
            case .inProgress:
                "key"
            case .complete:
                "checkmark.circle"
            case .failed:
                "exclamationmark.circle"
            }
        }
    }

    struct ExportItem: Identifiable, Hashable {
        enum State: Hashable {
            case waiting
            case done
            case inProgress
            case failed

            var symbolName: String {
                switch self {
                case .waiting: "circle.dotted"
                case .done: "checkmark"
                case .inProgress: "arrow.clockwise"
                case .failed: "xmark"
                }
            }

            var label: String {
                switch self {
                case .waiting:
                    #localize("state_waiting")
                case .inProgress:
                    #localize("state_in_progress")
                case .done:
                    #localize("state_done")
                case .failed:
                    #localize("state_failed")
                }
            }
        }

        var id: String { title }

        let state: State
        let title: String
        let statusText: String
    }

    // MARK: - Internal Properties

    let cancelButtonTitle = #localize("cancel")
    let dismissButtonTitle = #localize("dismiss")
    let continueButtonTitle = #localize("continue")
    let tryAgainButtonTitle = #localize("try_again")
    let errorIconName = "exclamationmark.circle"
    let note = #localize("backup_local_create_backup_note")

    var state: State = .inProgress

    @ObservationIgnored var onCancelButtonTapped: () -> Void = { /* no-op */ }
    @ObservationIgnored var onContinueButtonTapped: () -> Void = { /* no-op */ }
    @ObservationIgnored var onDismissButtonTapped: () -> Void = { /* no-op */ }

    var backupError: (title: String, content: String)?

    var headerTitle: String {
        switch state {
        case .inProgress:
            #localize("backup_local_create_backup_title")

        case .complete:
            #localize("backup_local_complete_title")

        case .failed:
            #localize("backup_local_failed_title")
        }
    }

    var headerSubtitle: String? {
        switch state {
        case .inProgress:
            #localize("backup_local_in_progress_description")

        case .complete:
            #localize("backup_local_completed_description")

        case .failed:
            #localize("backup_local_failed_description")
        }
    }

    var headerStep: String? {
        switch state {
        case .inProgress, .complete:
            let currentStep = hasDefaultRecoveryKey ? 2 : 3
            let totalSteps = hasDefaultRecoveryKey ? 2 : 3
            return String.localizedStringWithFormat(
                #localize("step_count_from_total_steps"), currentStep, totalSteps
            ).uppercased()
        default:
            return nil
        }
    }

    var hasDefaultRecoveryKey: Bool {
        manager.currentRecoveryKey.isDefault
    }

    /// One item per backup phase, in the order the backup reports them.
    var exportItems: [ExportItem] {
        let phases = DataBackupProgress.Phase.allCases.filter { phase in
            if phase != .distributionLists {
                true
            }
            else {
                userSettings.distributionListsEnabled
            }
        }

        return phases.map { phase in
            let itemState = itemState(for: phase)

            return ExportItem(
                state: itemState,
                title: phase.title,
                statusText: itemState.label
            )
        }
    }

    /// The phase the backup last reported, or `nil` if it has not reported anything yet.
    private(set) var currentPhase: DataBackupProgress.Phase?

    // MARK: - Private properties

    private let manager: any BackupCreateManagerProtocol
    private let userSettings: any UserSettingsProtocol
    private var backupHasStarted = false

    @ObservationIgnored
    private var backupTask: Task<Void, Never>?

    // MARK: - Lifecycle

    init(manager: any BackupCreateManagerProtocol, userSettings: any UserSettingsProtocol) {
        self.manager = manager
        self.userSettings = userSettings
    }

    // MARK: - Public methods

    func startBackup() {
        guard !backupHasStarted else {
            return
        }
        backupHasStarted = true
        backupTask = Task {
            await runBackup()
        }
    }

    func cancelButtonTapped() {
        backupTask?.cancel()
        onCancelButtonTapped()
    }

    func continueButtonTapped() {
        onContinueButtonTapped()
    }

    func tryAgainButtonTapped() {
        backupTask?.cancel()

        currentPhase = nil
        backupError = nil
        state = .inProgress
        backupHasStarted = false

        startBackup()
    }

    func dismissButtonTapped() {
        onDismissButtonTapped()
    }

    func runBackup() async {
        let password = manager.currentRecoveryKey.rawValue

        do {
            for try await progress in manager.create(url: manager.backupURL, password: password) {
                apply(progress)
            }

            // Without this check a cancelled backup would report itself as complete.
            guard !Task.isCancelled else {
                return
            }

            try manager.recordSuccessfulBackup()

            state = .complete
        }
        catch is CancellationError {
            // Cancelled while the backup was running: whoever cancelled owns the state of the screen.
        }
        catch {
            state = .failed
            backupError = (title: #localize("safe_backup_error_title"), content: error.localizedDescription)
            DDLogError("Backup creation failed: \(error)")
        }
    }

    func apply(_ progress: DataBackupProgress) {
        currentPhase = progress.phase
    }

    // MARK: - Private methods

    private func itemState(for phase: DataBackupProgress.Phase) -> ExportItem.State {
        switch state {
        case .complete:
            return .done

        case .failed:
            // Nothing runs after a failure, so every step that did not finish is settled as failed rather than left
            // waiting — including all of them when the backup failed before reporting a single phase.
            guard let currentPhase, phase < currentPhase else {
                return .failed
            }

            return .done

        case .inProgress:
            guard let currentPhase else {
                return .waiting
            }

            // Phases are monotonic, so everything before the current one is done even if its snapshots were never
            // observed.
            if phase < currentPhase {
                return .done
            }

            if phase == currentPhase {
                return .inProgress
            }

            return .waiting
        }
    }
}

// MARK: - DataBackupProgress.Phase + Localization

extension DataBackupProgress.Phase {
    fileprivate var title: String {
        switch self {
        case .userData:
            #localize("backup_local_create_backup_step_user_data_title")
        case .contacts:
            #localize("backup_local_create_backup_step_contacts_title")
        case .distributionLists:
            #localize("backup_local_create_backup_step_distribution_lists_title")
        case .groups:
            #localize("backup_local_create_backup_step_groups_title")
        case .cspNonces:
            #localize("backup_local_create_backup_step_nonces_title")
        case .polls:
            #localize("backup_local_create_backup_step_polls_title")
        case .messages:
            #localize("backup_local_create_backup_step_export_title")
        case .finalizing:
            #localize("backup_local_create_backup_step_finalize_title")
        }
    }
}
