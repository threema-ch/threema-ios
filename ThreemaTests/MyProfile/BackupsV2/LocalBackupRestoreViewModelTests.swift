import DataBackup
import Testing

@testable import Threema

@Suite("Local Backup Restore Tests")
@MainActor
struct LocalBackupRestoreViewModelTests {

    @Test func `Shared resources are correctly set in the primary language`() {
        let sut = LocalBackupRestoreViewModel(state: .inProgress)

        #expect(sut.cancelButtonTitle == "Cancel")
        #expect(sut.tryAgainButtonTitle == "Try Again")
        #expect(sut.errorIconName == "exclamationmark.circle")
        #expect(sut.restoreError == nil)
    }

    @Test func `Restore item state resources are correctly set in the primary language`() {
        #expect(ItemState.waiting.label == "Waiting…")
        #expect(ItemState.waiting.symbolName == "circle.dotted")

        #expect(ItemState.inProgress.label == "In progress")
        #expect(ItemState.inProgress.symbolName == "arrow.clockwise")

        #expect(ItemState.done.label == "Done")
        #expect(ItemState.done.symbolName == "checkmark")

        #expect(ItemState.failed.label == "Failed")
        #expect(ItemState.failed.symbolName == "xmark")
    }

    @Test func `In progress state resources are correctly set in the primary language`() {
        let sut = LocalBackupRestoreViewModel(state: .inProgress)

        #expect(sut.state.headerIconName == "arrow.trianglehead.clockwise")
        #expect(sut.headerTitle == "Restoring Backup")
        #expect(sut.headerSubtitle == "This may take a few minutes depending on your backup size.")

        #expect(sut.currentPhase == .userData)
        #expect(sut.restoreItems.map(\.title) == stepTitles)
        #expect(sut.restoreItems.map(\.state) == [.inProgress, .waiting, .waiting, .waiting, .waiting, .waiting])
    }

    @Test func `Complete state resources are correctly set in the primary language`() {
        let sut = LocalBackupRestoreViewModel(state: .complete)

        #expect(sut.state.headerIconName == "checkmark.circle")
        #expect(sut.headerTitle == "Restoring Complete")
        #expect(sut.headerSubtitle == "The app is ready to be used!")

        #expect(sut.restoreItems.map(\.title) == stepTitles)
        #expect(sut.restoreItems.map(\.state) == Array(repeating: .done, count: stepTitles.count))
    }

    @Test func `Failed state resources are correctly set in the primary language`() {
        let sut = LocalBackupRestoreViewModel(state: .failed)
        sut.apply(DataRestoreProgress.mock(phase: .messages))

        #expect(sut.state.headerIconName == "exclamationmark.circle")
        #expect(sut.headerTitle == "Restoring Failed")
        #expect(
            sut.headerSubtitle ==
                "We couldn’t restore your backup. This may be due to a corrupted file, incorrect key, or insufficient storage space."
        )

        #expect(sut.restoreItems.map(\.title) == stepTitles)
        #expect(sut.restoreItems.map(\.state) == [.done, .done, .done, .done, .done, .failed])
    }

    @Test(arguments: [
        (Phase.userData, [ItemState.inProgress, .waiting, .waiting, .waiting, .waiting, .waiting]),
        (.contacts, [.done, .inProgress, .waiting, .waiting, .waiting, .waiting]),
        (.distributionLists, [.done, .done, .waiting, .waiting, .waiting, .waiting]),
        (.groups, [.done, .done, .inProgress, .waiting, .waiting, .waiting]),
        (.cspNonces, [.done, .done, .done, .inProgress, .waiting, .waiting]),
        (.polls, [.done, .done, .done, .done, .inProgress, .waiting]),
        (.messages, [.done, .done, .done, .done, .done, .inProgress]),
    ])
    func `Steps before the reported phase are done and later ones are waiting`(
        phase: Phase,
        expected: [ItemState]
    ) {
        let sut = LocalBackupRestoreViewModel(state: .inProgress)
        sut.apply(DataRestoreProgress.mock(phase: phase))

        #expect(sut.restoreItems.map(\.state) == expected)
    }

    @Test func `A skipped phase still marks the earlier steps as done`() {
        let sut = LocalBackupRestoreViewModel(state: .inProgress)

        sut.apply(DataRestoreProgress.mock(phase: .contacts))
        sut.apply(DataRestoreProgress.mock(phase: .messages))

        #expect(sut.restoreItems.map(\.state) == [.done, .done, .done, .done, .done, .inProgress])
    }

    @Test func `A restore that completes leaves every step done`() async {
        let sut = makeSUT(reporting: DataRestoreProgress.mockRun)

        await sut.runRestore()

        #expect(sut.state == .complete)
        #expect(sut.currentPhase == .messages)
        #expect(sut.restoreItems.map(\.state) == Array(repeating: .done, count: stepTitles.count))
    }

    @Test func `A restore that fails reports the error and settles every unfinished step as failed`() async {
        let sut = makeSUT(
            reporting: [DataRestoreProgress.mock(phase: .polls)],
            thenThrowing: TestError.restoreFailed
        )

        await sut.runRestore()

        #expect(sut.state == .failed)
        #expect(sut.currentPhase == .polls)
        #expect(sut.restoreError?.title == "Restore failed")
        #expect(sut.restoreItems.map(\.state) == [.done, .done, .done, .done, .failed, .failed])
    }

    @Test func `A restore that fails before reporting a phase settles every step as failed`() async {
        // What happens when the backup file cannot even be opened: the restore fails while it is still preparing, so
        // there is no phase to anchor the failure to.
        let sut = makeSUT(reporting: [], thenThrowing: TestError.restoreFailed)

        await sut.runRestore()

        #expect(sut.state == .failed)
        #expect(sut.currentPhase == .userData)
        #expect(sut.restoreItems.map(\.state) == Array(repeating: .failed, count: stepTitles.count))
    }

    @Test func `A cancelled restore is not reported as complete`() async {
        // Never finishes on its own, so the run can only end by being cancelled.
        let sut = makeSUT(reporting: [], stalling: true)

        let task = Task { await sut.runRestore() }
        task.cancel()
        await task.value

        #expect(sut.state == .inProgress)
        #expect(sut.restoreError == nil)
    }

    @Test func `Calling startRestore twice starts only one restore`() async {
        let counter = CallCounter()
        let sut = LocalBackupRestoreViewModel(state: .inProgress) { _ in
            counter.count += 1
        }

        sut.startRestore()
        sut.startRestore()

        // The restore runs in a task of its own, so wait for the state it ends in.
        await waitUntil { sut.state == .complete }

        #expect(counter.count == 1)
    }

    // MARK: - Private methods

    typealias ItemState = LocalBackupRestoreViewModel.RestoreItem.State
    typealias Phase = DataRestoreProgress.Phase

    private enum TestError: Error {
        case restoreFailed
    }

    @MainActor
    private final class CallCounter {
        var count = 0
    }

    private let stepTitles = [
        "Restoring user data",
        "Restoring contacts",
        "Restoring groups",
        "Restoring nonces",
        "Restoring polls",
        "Restoring messages",
    ]

    private func makeSUT(
        reporting progress: [DataRestoreProgress],
        thenThrowing error: (any Error)? = nil,
        stalling: Bool = false
    ) -> LocalBackupRestoreViewModel {
        LocalBackupRestoreViewModel(state: .inProgress) { onProgress in
            for progress in progress {
                onProgress(progress)
            }

            if stalling {
                try await Task.sleep(for: .seconds(60 * 60))
            }

            if let error {
                throw error
            }
        }
    }

    /// Waits for `condition` by letting other tasks run, and records an issue if it does not hold in time.
    private func waitUntil(
        _ condition: () -> Bool,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        for _ in 0..<1000 {
            if condition() {
                return
            }
            await Task.yield()
        }

        Issue.record("Condition did not hold in time.", sourceLocation: sourceLocation)
    }
}
