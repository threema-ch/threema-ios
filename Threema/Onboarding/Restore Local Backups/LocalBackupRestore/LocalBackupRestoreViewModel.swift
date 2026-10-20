import CocoaLumberjackSwift
import DataBackup
import Observation
import ThreemaFramework
import ThreemaMacros

@MainActor
@Observable
final class LocalBackupRestoreViewModel {

    // MARK: Internal types

    typealias ProgressHandler = @MainActor @Sendable (DataRestoreProgress) -> Void

    enum State {
        case inProgress
        case complete
        case failed

        var headerIconName: String {
            switch self {
            case .inProgress:
                "arrow.trianglehead.clockwise"
            case .complete:
                "checkmark.circle"
            case .failed:
                "exclamationmark.circle"
            }
        }
    }

    struct RestoreItem: Identifiable, Hashable {
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
    }

    // MARK: - Internal properties

    let cancelButtonTitle = #localize("cancel")
    let contactButtonTitle = #localize("Contact_Support")
    let tryAgainButtonTitle = #localize("try_again")
    let continueButtonTitle = #localize("Continue_To_Chats")
    let errorIconName = "exclamationmark.circle"

    var state: State

    var restoreError: (title: String, content: String)?

    @ObservationIgnored
    var onTryAgainButtonTapped: () -> Void = { /* no-op */ }

    @ObservationIgnored
    var onDismissButtonTapped: () -> Void = { /* no-op */ }

    @ObservationIgnored
    var onContinueButtonTapped: () -> Void = { /* no-op */ }

    var headerTitle: String {
        switch state {
        case .inProgress:
            #localize("restoring_in_progress_title")

        case .complete:
            #localize("restoring_complete_title")

        case .failed:
            #localize("restoring_failed_title")
        }
    }

    var headerSubtitle: String? {
        switch state {
        case .inProgress:
            #localize("restoring_in_progress_message")

        case .complete:
            #localize("restoring_backup_complete_message")

        case .failed:
            #localize("restoring_backup_failed_message")
        }
    }

    var restoreItems: [RestoreItem] {
        let phases = DataRestoreProgress.Phase.allCases.filter { phase in
            if phase != .distributionLists {
                true
            }
            else {
                ThreemaEnvironment.distributionListsActive
            }
        }

        return phases.map { phase in
            RestoreItem(state: itemState(for: phase), title: phase.title)
        }
    }

    private(set) var currentPhase: DataRestoreProgress.Phase = .userData

    // MARK: - Private properties

    private let restore: (@escaping ProgressHandler) async throws -> Void

    private var restoreHasStarted = false

    @ObservationIgnored
    private var restoreTask: Task<Void, Never>?

    // MARK: - Lifecycle

    /// - Parameters:
    ///   - state: State the screen starts in.
    ///   - restore: The restore to run, started once by ``startRestore()``. Reports its progress through the handler
    ///     it is given. Throwing puts the screen into `.failed`.
    init(
        state: State = .inProgress,
        restore: @escaping (@escaping ProgressHandler) async throws -> Void = { _ in /* no-op */ }
    ) {
        self.state = state
        self.restore = restore
    }

    // MARK: - Internal methods

    func startRestore() {
        guard !restoreHasStarted else {
            return
        }

        restoreHasStarted = true
        restoreTask = Task {
            await runRestore()
        }
    }

    func cancelButtonTapped() {
        restoreTask?.cancel()
    }

    func tryAgainButtonTapped() {
        onTryAgainButtonTapped()
    }

    func dimissButtonTapped() {
        onDismissButtonTapped()
    }

    func continueButtonTapped() {
        onContinueButtonTapped()
    }

    /// Runs the restore to completion and reflects its outcome.
    func runRestore() async {
        do {
            try await restore { [weak self] progress in
                self?.apply(progress)
            }

            // Without this check a cancelled restore would report itself as complete.
            guard !Task.isCancelled else {
                return
            }

            state = .complete
        }
        catch is CancellationError {
            // Cancelled while the restore was running: whoever cancelled owns the state of the screen.
        }
        catch {
            state = .failed
            restoreError = (title: #localize("safe_restore_failed"), content: error.localizedDescription)
            DDLogError("Restoring a local data backup failed: \(error)")
        }
    }

    func apply(_ progress: DataRestoreProgress) {
        currentPhase = progress.phase
    }

    // MARK: - Private methods

    private func itemState(for phase: DataRestoreProgress.Phase) -> RestoreItem.State {
        switch state {
        case .complete:
            return .done

        case .failed:
            guard phase < currentPhase else {
                return .failed
            }

            return .done

        case .inProgress:
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

// MARK: - DataRestoreProgress.Phase + Localization

extension DataRestoreProgress.Phase {
    fileprivate var title: String {
        switch self {
        case .userData:
            #localize("backup_local_restore_step_user_data_title")
        case .contacts:
            #localize("backup_local_restore_step_contacts_title")
        case .distributionLists:
            #localize("backup_local_restore_step_distribution_lists_title")
        case .groups:
            #localize("backup_local_restore_step_groups_title")
        case .cspNonces:
            #localize("backup_local_restore_step_nonces_title")
        case .polls:
            #localize("backup_local_restore_step_polls_title")
        case .messages:
            #localize("backup_local_restore_step_messages_title")
        }
    }
}
