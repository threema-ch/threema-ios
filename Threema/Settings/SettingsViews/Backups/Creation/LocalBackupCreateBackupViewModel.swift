import CocoaLumberjackSwift
import DataBackup
import Observation
import ThreemaMacros

@MainActor
@Observable
final class LocalBackupCreateBackupViewModel {

    // MARK: Internal Types

    enum State {
        case inProgress
        case complete
        case failed

        var iconSymbolName: String {
            switch self {
            case .inProgress:
                "arrow.trianglehead.2.counterclockwise.rotate.90"
            case .complete:
                "checkmark"
            case .failed:
                "exclamationmark"
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
    let doneButtonTitle = #localize("done")
    let tryAgainButtonTitle = #localize("try_again")
    let errorIconName = "exclamationmark.circle"

    var state: State = .inProgress

    @ObservationIgnored
    var onDoneButtonTapped: () -> Void = { /* no-op */ }

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
        case .inProgress:
            let currentStep = hasDefaultRecoveryKey ? 2 : 3
            let totalSteps = hasDefaultRecoveryKey ? 2 : 3
            return String.localizedStringWithFormat(
                #localize("step_count_from_total_steps"), currentStep, totalSteps
            ).uppercased()
        default:
            return nil
        }
    }

    var note: String? {
        switch state {
        case .inProgress:
            #localize("backup_local_create_backup_note")

        default:
            nil
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
                ThreemaEnvironment.distributionListsActive
            }
        }

        return phases.map { phase in
            let itemState = itemState(for: phase)

            return ExportItem(
                state: itemState,
                title: phase.title,
                statusText: statusText(for: phase, state: itemState)
            )
        }
    }

    /// The phase the backup last reported, or `nil` if it has not reported anything yet.
    private(set) var currentPhase: DataBackupProgress.Phase?

    /// Number of items the backup wrote in ``currentPhase`` so far.
    private(set) var itemsProcessed: UInt64 = 0

    // MARK: - Private properties

    private let manager: any BackupCreateManagerProtocol
    private var backupHasStarted = false

    @ObservationIgnored
    private var backupTask: Task<Void, Never>?

    // MARK: - Lifecycle

    init(manager: any BackupCreateManagerProtocol) {
        self.manager = manager
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
    }

    func doneButtonTapped() {
        onDoneButtonTapped()
    }

    func tryAgainButtonTapped() {
        backupTask?.cancel()

        currentPhase = nil
        itemsProcessed = 0
        backupError = nil
        state = .inProgress
        backupHasStarted = false

        startBackup()
    }

    func dismissButtonTapped() {
        // TODO: Implement
    }

    /// Runs a backup to completion and reflects its progress.
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
        itemsProcessed = progress.itemsProcessed
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

    private func statusText(for phase: DataBackupProgress.Phase, state itemState: ExportItem.State) -> String {
        guard itemState == .inProgress, let countLabel = phase.countLabel(itemsProcessed) else {
            return itemState.label
        }

        return countLabel
    }
}

// MARK: - DataBackupProgress.Phase + Localization

extension DataBackupProgress.Phase {
    fileprivate var title: String {
        switch self {
        case .initializing:
            #localize("backup_local_create_backup_step_initialize_title")
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

    fileprivate func countLabel(_ itemsProcessed: UInt64) -> String? {
        let format: String? =
            switch self {
            case .initializing, .finalizing:
                nil
            case .contacts:
                #localize("backup_local_create_backup_step_contacts_count")
            case .distributionLists:
                #localize("backup_local_create_backup_step_distribution_lists_count")
            case .groups:
                #localize("backup_local_create_backup_step_groups_count")
            case .cspNonces:
                #localize("backup_local_create_backup_step_nonces_count")
            case .polls:
                #localize("backup_local_create_backup_step_polls_count")
            case .messages:
                #localize("backup_local_create_backup_step_messages_count")
            }

        guard let format else {
            return nil
        }

        return String.localizedStringWithFormat(format, Int64(itemsProcessed))
    }
}
