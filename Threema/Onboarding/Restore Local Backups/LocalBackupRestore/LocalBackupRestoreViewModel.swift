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

        // No phase of the restore belongs to the media and finalizing steps, so they never show as in progress: they
        // wait until the restore completes or fails.
        case media
        case finalizing

        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
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
        Step.allCases.map { step in
            RestoreItem(state: itemState(for: step), title: step.title)
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

    private func itemState(for step: Step) -> RestoreItem.State {
        let currentStep = currentPhase.step

        switch state {
        case .complete:
            return .done

        case .failed:
            guard step < currentStep else {
                return .failed
            }

            return .done

        case .inProgress:
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

// MARK: - DataRestoreProgress.Phase + Step

extension DataRestoreProgress.Phase {
    /// The step this phase is shown in.
    fileprivate var step: LocalBackupRestoreViewModel.Step {
        switch self {
        case .userData, .contacts:
            .preparing
        case .distributionLists, .groups, .cspNonces, .polls, .messages:
            .chats
        }
    }
}

// MARK: - LocalBackupRestoreViewModel.Step + Localization

extension LocalBackupRestoreViewModel.Step {
    fileprivate var title: String {
        switch self {
        case .preparing:
            #localize("backup_local_restore_step_preparing_title")
        case .chats:
            #localize("backup_local_restore_step_chats_title")
        case .media:
            #localize("backup_local_restore_step_media_title")
        case .finalizing:
            #localize("backup_local_restore_step_finalize_title")
        }
    }
}
