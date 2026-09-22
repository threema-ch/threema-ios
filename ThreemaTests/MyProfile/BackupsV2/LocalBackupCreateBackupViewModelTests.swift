import DataBackup
import Testing

@testable import Threema

@Suite("Local Backup Creating Backup Tests")
@MainActor
struct LocalBackupCreateBackupViewModelTests {

    @Test func `Shared resources are correctly set in the primary language`() {
        let sut = makeSUT()

        #expect(sut.state.iconSymbolName == "arrow.trianglehead.2.counterclockwise.rotate.90")
        #expect(sut.cancelButtonTitle == "Cancel")
        #expect(sut.dismissButtonTitle == "Dismiss")
        #expect(sut.doneButtonTitle == "Done")
        #expect(sut.tryAgainButtonTitle == "Try Again")
        #expect(sut.errorIconName == "exclamationmark.circle")
        #expect(sut.backupError == nil)
    }

    @Test func `Export item state resources are correctly set in the primary language`() {
        #expect(ItemState.waiting.label == "Waiting…")
        #expect(ItemState.waiting.symbolName == "circle.dotted")

        #expect(ItemState.inProgress.label == "In progress")
        #expect(ItemState.inProgress.symbolName == "arrow.clockwise")

        #expect(ItemState.done.label == "Done")
        #expect(ItemState.done.symbolName == "checkmark")

        #expect(ItemState.failed.label == "Failed")
        #expect(ItemState.failed.symbolName == "xmark")
    }

    @Test func `Not started state resources are correctly set in the primary language`() {
        let sut = makeSUT()

        #expect(sut.headerTitle == "Creating backup")
        #expect(sut.headerSubtitle == "This may take a few minutes depending on your backup size.")
        #expect(sut.headerStep == "STEP 3 OF 3")
        #expect(sut.note == "Do not lock your screen or force-close the app.")

        #expect(sut.currentPhase == nil)
        #expect(sut.exportItems.map(\.title) == stepTitles)
        #expect(sut.exportItems.map(\.state) == Array(repeating: .waiting, count: stepTitles.count))
        #expect(sut.exportItems.map(\.statusText) == Array(repeating: "Waiting…", count: stepTitles.count))
    }

    @Test func `In progress state resources are correctly set in the primary language`() {
        let sut = makeSUT()
        sut.apply(DataBackupProgress.mock(phase: .messages, itemsProcessed: 5))

        #expect(sut.state.iconSymbolName == "arrow.trianglehead.2.counterclockwise.rotate.90")
        #expect(sut.headerTitle == "Creating backup")
        #expect(sut.headerSubtitle == "This may take a few minutes depending on your backup size.")
        #expect(sut.headerStep == "STEP 3 OF 3")
        #expect(sut.note == "Do not lock your screen or force-close the app.")

        #expect(sut.exportItems.map(\.title) == stepTitles)
        #expect(sut.exportItems.map(\.state) == [.done, .done, .done, .done, .done, .inProgress, .waiting])
    }

    @Test func `Complete state resources are correctly set in the primary language`() {
        let sut = makeSUT()
        sut.apply(DataBackupProgress.mock(phase: .finalizing))
        sut.state = .complete

        #expect(sut.state.iconSymbolName == "checkmark")
        #expect(sut.headerTitle == "Backup Complete")
        #expect(sut.headerSubtitle == "Your messages and media have been encrypted and saved securely.")
        #expect(sut.headerStep == nil)
        #expect(sut.note == nil)

        #expect(sut.exportItems.map(\.title) == stepTitles)
        #expect(sut.exportItems.map(\.state) == Array(repeating: .done, count: stepTitles.count))
    }

    @Test func `Failed state resources are correctly set in the primary language`() {
        let sut = makeSUT()
        sut.apply(DataBackupProgress.mock(phase: .finalizing))
        sut.state = .failed

        #expect(sut.state.iconSymbolName == "exclamationmark")
        #expect(sut.headerTitle == "Backup failed")
        #expect(sut.headerSubtitle == "Your backup could not be completed. No data was lost.")
        #expect(sut.headerStep == nil)
        #expect(sut.note == nil)

        #expect(sut.exportItems.map(\.title) == stepTitles)
        #expect(sut.exportItems.map(\.state) == [.done, .done, .done, .done, .done, .done, .failed])
    }

    @Test(arguments: [
        (Phase.initializing, [
            ItemState.inProgress,
            .waiting,
            .waiting,
            .waiting,
            .waiting,
            .waiting,
            .waiting
        ]),
        (.contacts, [.done, .inProgress, .waiting, .waiting, .waiting, .waiting, .waiting]),
        (.distributionLists, [.done, .done, .waiting, .waiting, .waiting, .waiting, .waiting]),
        (.groups, [.done, .done, .inProgress, .waiting, .waiting, .waiting, .waiting]),
        (.cspNonces, [.done, .done, .done, .inProgress, .waiting, .waiting, .waiting]),
        (.polls, [.done, .done, .done, .done, .inProgress, .waiting, .waiting]),
        (.messages, [.done, .done, .done, .done, .done, .inProgress, .waiting]),
        (.finalizing, [.done, .done, .done, .done, .done, .done, .inProgress]),
    ])
    func `Steps before the reported phase are done and later ones are waiting`(
        phase: Phase,
        expected: [ItemState]
    ) {
        let sut = makeSUT()
        sut.apply(DataBackupProgress.mock(phase: phase))

        #expect(sut.exportItems.map(\.state) == expected)
    }

    @Test func `A skipped phase still marks the earlier steps as done`() {
        let sut = makeSUT()

        // Only the most recent snapshot is buffered, so the phases in between can be missed entirely.
        sut.apply(DataBackupProgress.mock(phase: .initializing))
        sut.apply(DataBackupProgress.mock(phase: .messages, itemsProcessed: 9000))

        #expect(sut.exportItems.map(\.state) == [.done, .done, .done, .done, .done, .inProgress, .waiting])
    }

    @Test func `A step that runs shows how many items it wrote so far`() {
        let sut = makeSUT()

        sut.apply(DataBackupProgress.mock(phase: .contacts, itemsProcessed: 1))
        #expect(sut.exportItems[1].statusText == "1 contact")

        sut.apply(DataBackupProgress.mock(phase: .contacts, itemsProcessed: 5))
        #expect(sut.exportItems[1].statusText == "5 contacts")

        sut.apply(DataBackupProgress.mock(phase: .messages, itemsProcessed: 42))
        #expect(sut.exportItems[5].statusText == "42 messages")

        // Steps that are not running show their state instead.
        #expect(sut.exportItems[1].statusText == "Done")
        #expect(sut.exportItems[6].statusText == "Waiting…")
    }

    @Test(arguments: [Phase.initializing, .finalizing])
    func `A step without items to count shows its state`(phase: Phase) {
        let sut = makeSUT()
        sut.apply(DataBackupProgress.mock(phase: phase, itemsProcessed: 7))

        let runningItem = sut.exportItems.first { $0.state == .inProgress }
        #expect(runningItem?.statusText == "In progress")
    }

    @Test func `A backup that completes leaves every step done`() async {
        let sut = makeSUT(createBehavior: .succeeding(progress: DataBackupProgress.mockRun, delay: .zero))

        await sut.runBackup()

        #expect(sut.state == .complete)
        #expect(sut.currentPhase == .finalizing)
        #expect(sut.exportItems.map(\.state) == Array(repeating: .done, count: stepTitles.count))
    }

    @Test func `A backup that fails reports the error and settles every unfinished step as failed`() async {
        let sut = makeSUT(
            createBehavior: .failing(
                after: [DataBackupProgress.mock(phase: .messages, itemsProcessed: 3)],
                error: .createFailed
            )
        )

        await sut.runBackup()

        #expect(sut.state == .failed)
        #expect(sut.currentPhase == .messages)
        #expect(sut.backupError?.title == "Backup Error")
        #expect(sut.backupError?.content == "The mock backup failed.")
        #expect(sut.exportItems.map(\.state) == [.done, .done, .done, .done, .done, .failed, .failed])
    }

    @Test func `A backup that fails before reporting a phase settles every step as failed`() async {
        // What happens when the backup file cannot even be opened: the stream fails without reporting any progress, so
        // there is no phase to anchor the failure to.
        let sut = makeSUT(createBehavior: .immediateFailure)

        await sut.runBackup()

        #expect(sut.state == .failed)
        #expect(sut.currentPhase == nil)
        #expect(sut.exportItems.map(\.state) == Array(repeating: .failed, count: stepTitles.count))
        #expect(sut.exportItems.map(\.statusText) == Array(repeating: "Failed", count: stepTitles.count))
    }

    @Test func `A cancelled backup is not reported as complete`() async {
        // Never finishes on its own, so the run can only end by being cancelled.
        let sut = makeSUT(createBehavior: .idle)

        let task = Task { await sut.runBackup() }
        task.cancel()
        await task.value

        #expect(sut.state == .inProgress)
        #expect(sut.backupError == nil)
    }

    @Test func `Calling startBackup twice starts only one backup`() async {
        let manager = BackupCreateManagerMock(createBehavior: .immediateSuccess)
        let sut = LocalBackupCreateBackupViewModel(manager: manager)

        sut.startBackup()
        sut.startBackup()

        // The backup runs in a task of its own, so wait for the state it ends in.
        await waitUntil { sut.state == .complete }

        #expect(manager.createCallCount == 1)
    }

    // MARK: - Recording the backup

    @Test func `A backup that completes is recorded`() async {
        let manager = BackupCreateManagerMock(createBehavior: .immediateSuccess)
        let sut = LocalBackupCreateBackupViewModel(manager: manager)

        await sut.runBackup()

        #expect(manager.recordSuccessfulBackupCallCount == 1)
        #expect(manager.lastBackup != nil)
    }

    @Test func `A backup that fails is not recorded`() async {
        let manager = BackupCreateManagerMock(createBehavior: .immediateFailure)
        let sut = LocalBackupCreateBackupViewModel(manager: manager)

        await sut.runBackup()

        #expect(sut.state == .failed)
        #expect(manager.recordSuccessfulBackupCallCount == 0)
    }

    @Test func `A cancelled backup is not recorded`() async {
        let manager = BackupCreateManagerMock(createBehavior: .idle)
        let sut = LocalBackupCreateBackupViewModel(manager: manager)

        let task = Task { await sut.runBackup() }
        task.cancel()
        await task.value

        #expect(manager.recordSuccessfulBackupCallCount == 0)
    }

    @Test func `A backup that cannot be recorded is reported as failed`() async {
        let manager = BackupCreateManagerMock(createBehavior: .immediateSuccess)
        manager.mockRecordError = .recordFailed
        let sut = LocalBackupCreateBackupViewModel(manager: manager)

        await sut.runBackup()

        // Without the record there is nothing to show on the details screen, so the file alone is not a usable backup.
        #expect(sut.state == .failed)
        #expect(sut.backupError?.title == "Backup Error")
        #expect(sut.backupError?.content == "The mock backup could not be recorded.")
    }

    // MARK: - Private methods

    typealias ItemState = LocalBackupCreateBackupViewModel.ExportItem.State
    typealias Phase = DataBackupProgress.Phase

    private let stepTitles = [
        "Initializing backup",
        "Exporting contacts",
        "Exporting groups",
        "Exporting nonces",
        "Exporting polls",
        "Exporting messages",
        "Finalizing backup",
    ]

    private func makeSUT(
        createBehavior: BackupCreateManagerMock.CreateBehavior = .idle
    ) -> LocalBackupCreateBackupViewModel {
        LocalBackupCreateBackupViewModel(
            manager: BackupCreateManagerMock(
                createBehavior: createBehavior
            )
        )
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
