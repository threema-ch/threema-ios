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
                "arrow.down.circle.fill"
            case .complete:
                "checkmark.circle.fill"
            case .failed:
                "exclamationmark.circle.fill"
            }
        }
    }

    enum Step: Int, CaseIterable, Comparable {
        case preparing
        case chats

        case media

        case finalizing

        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
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
    let hasDefaultRecoveryKey: Bool

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

    var exportItems: [ExportItem] {
        let steps = Step.allCases.filter { step in
            step != .media || includesMedia
        }

        return steps.map { step in
            let itemState = itemState(for: step)

            return ExportItem(
                state: itemState,
                title: step.title,
                statusText: itemState.label
            )
        }
    }

    /// The phase the backup last reported, or `nil` if it has not reported anything yet.
    private(set) var currentPhase: DataBackupProgress.Phase?

    // MARK: - Private properties

    private let manager: any BackupCreateManagerProtocol
    private let includesMedia: Bool
    private var backupHasStarted = false

    @ObservationIgnored
    private var backupTask: Task<Void, Never>?

    // MARK: - Lifecycle

    init(manager: any BackupCreateManagerProtocol) {
        self.manager = manager
        self.hasDefaultRecoveryKey = manager.currentRecoveryKey.isDefault
        self.includesMedia = manager.backupSettings.includesMedia
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
            for try await progress in manager.create(password: password) {
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

    private func itemState(for step: Step) -> ExportItem.State {
        let currentStep = currentPhase?.step

        switch state {
        case .complete:
            return .done

        case .failed:
            // Nothing runs after a failure, so every step that did not finish is settled as failed rather than left
            // waiting — including all of them when the backup failed before reporting a single phase.
            guard let currentStep, step < currentStep else {
                return .failed
            }

            return .done

        case .inProgress:
            guard let currentStep else {
                return .waiting
            }

            // Phases are monotonic, so everything before the current step is done even if its snapshots were never
            // observed.
            if step < currentStep {
                return .done
            }

            if step == currentStep {
                return .inProgress
            }

            return .waiting
        }
    }
}

// MARK: - DataBackupProgress.Phase + Step

extension DataBackupProgress.Phase {
    /// The step this phase is shown in.
    fileprivate var step: LocalBackupCreateBackupViewModel.Step {
        switch self {
        case .userData, .contacts:
            .preparing
        case .distributionLists, .groups, .cspNonces, .polls, .messages:
            .chats
        case .finalizing:
            .finalizing
        }
    }
}

// MARK: - LocalBackupCreateBackupViewModel.Step + Localization

extension LocalBackupCreateBackupViewModel.Step {
    fileprivate var title: String {
        switch self {
        case .preparing:
            #localize("backup_local_create_backup_step_preparing_title")
        case .chats:
            #localize("backup_local_create_backup_step_chats_title")
        case .media:
            #localize("backup_local_create_backup_step_media_title")
        case .finalizing:
            #localize("backup_local_create_backup_step_finalize_title")
        }
    }
}
