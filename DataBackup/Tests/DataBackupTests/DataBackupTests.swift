import DataBackupTestHelper
import FileUtility
import FileUtilityTestHelper
import Foundation
import libthreemaSwift
import libthreemaSwiftTestHelper
import os
import Testing

@testable import DataBackup

@MainActor
@Suite("Data Backup Create Tests")
struct DataBackupTests {

    @Test func `Perform completes the poll with success`() async throws {

        let fileUtility = FileUtility()
        let backupURL = testBackupURL()

        deleteFile(at: backupURL)
        defer { deleteFile(at: backupURL) }

        let createTask = BackupCreateTaskMock()
        createTask.mockPoll(
            returning: .success(
                [
                    .stateUpdateInstruction(state: .initialState),
                    .writeAtInstruction(count: 10),
                    .stateUpdateInstruction(state: .contacts(10)),
                    .writeAppendInstruction(count: 20),
                    .stateUpdateInstruction(state: .cspNonces(20)),
                    .writeAppendInstruction(count: 30),
                    .stateUpdateInstruction(state: .distributionLists(30)),
                    .writeAppendInstruction(count: 40),
                    .stateUpdateInstruction(state: .groups(40)),
                    .writeAppendInstruction(count: 50),
                    .stateUpdateInstruction(state: .messages(50)),
                    .writeAppendInstruction(count: 60),
                    .stateUpdateInstruction(state: .polls(60)),
                    .stateUpdateInstruction(state: .finalizeState),
                    .done(210)
                ]
            )
        )

        let sut = makeSUT(
            backupURL: backupURL,
            fileUtility: fileUtility,
            createTask: createTask
        )

        try await sut.perform()

        // The real `FileUtility` is not `Sendable`, so it is handed over to the actor: check the file system
        // directly instead of going through it again.
        #expect(FileManager.default.fileExists(atPath: backupURL.path(percentEncoded: false)))

        let writtenData = try Data(contentsOf: backupURL)
        #expect(writtenData.count == 210)
        #expect(writtenData == Data(repeating: 1, count: 210))

        #expect(createTask.calls == Array(repeating: .poll, count: 15))
    }

    @Test func `Perform throws when the reported total bytes mismatch the actual bytes written`() async throws {
        let backupURL = testBackupURL()

        try Data().write(to: backupURL) // 0 bytes actual in the file
        defer { deleteFile(at: backupURL) }

        let fileUtilityMock = FileUtilityMock()
        fileUtilityMock.mockCreateFileHandleForWriting = { try FileHandle(forWritingTo: $0) }
        fileUtilityMock.mockCloseFileHandle = { try $0.close() }

        let createTask = BackupCreateTaskMock()
        createTask.mockPoll = { .done(210) } // No bytes are written, but the task reports a total of 210.

        let sut = makeSUT(
            backupURL: backupURL,
            fileUtility: fileUtilityMock,
            createTask: createTask
        )

        await #expect(throws: DataBackupError.backupCreateFileWrittenBytesMismatch(actual: 0, expected: 210)) {
            try await sut.perform()
        }

        // cleanUpIfNeeded() must delete the incomplete backup file.
        #expect(fileUtilityMock.calls.contains(.deleteAtURL(backupURL)))
    }

    @Test func `Perform logs when clean up cannot delete the incomplete backup file`() async throws {
        let backupURL = testBackupURL()

        try Data().write(to: backupURL) // 0 bytes actual in the file
        defer { deleteFile(at: backupURL) }

        let fileUtilityMock = FileUtilityMock()
        fileUtilityMock.mockCreateFileHandleForWriting = { try FileHandle(forWritingTo: $0) }
        fileUtilityMock.mockCloseFileHandle = { try $0.close() }
        fileUtilityMock.mockDeleteAtURL = { _ in throw FileUtilityMockError.deleteAtURLFailed } // The delete fails.

        let createTask = BackupCreateTaskMock()
        createTask.mockPoll = { .done(210) } // Byte mismatch cleanUpIfNeeded() runs

        let sut = makeSUT(
            backupURL: backupURL,
            fileUtility: fileUtilityMock,
            createTask: createTask
        )

        await #expect(throws: DataBackupError.backupCreateFileWrittenBytesMismatch(actual: 0, expected: 210)) {
            try await sut.perform()
        }

        // The delete was attempted (and failed).
        #expect(fileUtilityMock.calls.contains(.deleteAtURL(backupURL)))

        // Since the delete failed, the incomplete backup file is still on disk.
        #expect(FileManager.default.fileExists(atPath: backupURL.path(percentEncoded: false)))
    }

    @Test func `Perform logs when the backup file cannot be closed`() async throws {
        let backupURL = testBackupURL()

        try Data().write(to: backupURL) // 0 bytes actual in the file
        defer { deleteFile(at: backupURL) }

        let fileHandle = try FileHandle(forWritingTo: backupURL)
        defer { try? fileHandle.close() }

        let fileUtilityMock = FileUtilityMock()
        fileUtilityMock.mockCreateFileHandleForWriting = { _ in fileHandle }

        // Fail to close file
        fileUtilityMock.mockCloseFileHandle = { _ in throw FileUtilityMockError.closeFileHandleFailed }

        let createTask = BackupCreateTaskMock()
        createTask.mockPoll = { .done(0) }

        let sut = makeSUT(
            backupURL: backupURL,
            fileUtility: fileUtilityMock,
            createTask: createTask
        )

        try await sut.perform()

        // The close was attempted (and failed); its error was swallowed.
        #expect(fileUtilityMock.calls.contains(.closeFileHandle))
    }

    @Test func `Perform throws when an existing backup file cannot be deleted`() async throws {
        let fileUtilityMock = FileUtilityMock()
        fileUtilityMock.mockFileExistsAtURL = { _ in true }
        fileUtilityMock.mockDeleteAtURL = { _ in throw FileUtilityMockError.deleteAtURLFailed }

        let sut = makeSUT(
            backupURL: testBackupURL(),
            fileUtility: fileUtilityMock
        )

        await #expect(throws: FileUtilityMockError.deleteAtURLFailed) {
            try await sut.perform()
        }
    }

    @Test func `Perform throws when the empty backup file cannot be created`() async throws {
        let fileUtility = FileUtilityMock()
        fileUtility.mockFileExistsAtURL = { _ in false }
        fileUtility.mockCreateEmptyFile = { _ in throw FileUtilityMockError.createEmptyFileFailed }

        let sut = makeSUT(
            backupURL: testBackupURL(),
            fileUtility: fileUtility
        )

        await #expect(throws: FileUtilityMockError.createEmptyFileFailed) {
            try await sut.perform()
        }
    }

    @Test func `Perform throws when the backup file cannot be opened`() async throws {
        let backupURL = testBackupURL()
        let fileUtility = FileUtilityMock.failingToOpenForWriting

        let sut = makeSUT(
            backupURL: backupURL,
            fileUtility: fileUtility
        )

        await #expect(throws: FileUtilityMockError.createWriteFileHandleFailed) {
            try await sut.perform()
        }

        // The empty file created just before the failed open must not be left behind.
        #expect(fileUtility.calls.contains(.deleteAtURL(backupURL)))
    }

    @Test func `Perform throws when the poll task throws an error`() async throws {
        let createTask = BackupCreateTaskMock()
        createTask.mockPoll = { throw BackupCreateTaskError.pollError }

        let sut = makeSUT(
            backupURL: testBackupURL(),
            createTask: createTask
        )

        await #expect(throws: BackupCreateTaskError.pollError) {
            try await sut.perform()
        }
    }

    @Test func `Perform throws when the poll task returns a remote instruction`() async throws {
        let createTask = BackupCreateTaskMock()
        createTask.mockPoll(returning: .success([
            .writeRemoteInstruction(),
            .done(0),
        ]))

        let sut = makeSUT(
            backupURL: testBackupURL(),
            createTask: createTask
        )

        await #expect(throws: DataBackupError.remoteBackupNotSupported) {
            try await sut.perform()
        }
    }

    @Test func `Perform throws when data cannot be written at an offset`() async throws {
        let fileUtilityMock = FileUtilityMock()
        fileUtilityMock.mockWriteToHandle = { _, _, _, _ in throw FileUtilityMockError.writeFailed }

        let createTask = BackupCreateTaskMock()
        createTask.mockPoll(returning: .success([
            .writeAtInstruction(count: 10),
            .done(0),
        ]))

        let sut = makeSUT(
            backupURL: testBackupURL(),
            fileUtility: fileUtilityMock,
            createTask: createTask
        )

        await #expect(throws: FileUtilityMockError.writeFailed) {
            try await sut.perform()
        }
    }

    @Test func `Perform throws when appended data cannot be written`() async throws {
        let fileUtilityMock = FileUtilityMock()
        fileUtilityMock.mockWriteToHandle = { _, _, _, _ in throw FileUtilityMockError.writeFailed }

        let createTask = BackupCreateTaskMock()
        createTask.mockPoll(returning: .success([
            .writeAppendInstruction(count: 10),
            .done(0),
        ]))

        let sut = makeSUT(
            backupURL: testBackupURL(),
            fileUtility: fileUtilityMock,
            createTask: createTask
        )

        await #expect(throws: FileUtilityMockError.writeFailed) {
            try await sut.perform()
        }
    }

    @Test func `Perform reports a progress snapshot for every state update, in order`() async throws {
        let backupURL = testBackupURL()

        deleteFile(at: backupURL)
        defer { deleteFile(at: backupURL) }

        let createTask = BackupCreateTaskMock()

        createTask.mockPoll(
            returning: .success(
                [
                    .stateUpdateInstruction(state: .initialState),
                    .writeAtInstruction(count: 10),
                    .stateUpdateInstruction(state: .contacts(10)),
                    .writeAppendInstruction(count: 20),
                    .stateUpdateInstruction(state: .cspNonces(20)),
                    .writeAppendInstruction(count: 30),
                    .stateUpdateInstruction(state: .distributionLists(30)),
                    .writeAppendInstruction(count: 40),
                    .stateUpdateInstruction(state: .groups(40)),
                    .writeAppendInstruction(count: 50),
                    .stateUpdateInstruction(state: .messages(50)),
                    .writeAppendInstruction(count: 60),
                    .stateUpdateInstruction(state: .polls(60)),
                    .stateUpdateInstruction(state: .finalizeState),
                    .done(210)
                ]
            )
        )

        let recorder = ProgressRecorder()

        let sut = makeSUT(
            backupURL: backupURL,
            fileUtility: FileUtility(),
            createTask: createTask,
            onProgress: recorder.handler
        )

        try await sut.perform()

        #expect(recorder.recorded == [
            DataBackupProgress(phase: .initializing),
            DataBackupProgress(phase: .contacts, itemsProcessed: 10),
            DataBackupProgress(phase: .cspNonces, itemsProcessed: 20),
            DataBackupProgress(phase: .distributionLists, itemsProcessed: 30),
            DataBackupProgress(phase: .groups, itemsProcessed: 40),
            DataBackupProgress(phase: .messages, itemsProcessed: 50),
            DataBackupProgress(phase: .polls, itemsProcessed: 60),
            DataBackupProgress(phase: .finalizing),
        ])
    }

    @Test func `Perform reports no progress for instructions that only write`() async throws {
        let backupURL = testBackupURL()

        deleteFile(at: backupURL)
        defer { deleteFile(at: backupURL) }

        let createTask = BackupCreateTaskMock()
        createTask.mockPoll(returning: .success([
            .writeAtInstruction(count: 10),
            .writeAppendInstruction(count: 20),
            .done(30),
        ]))

        let recorder = ProgressRecorder()

        let sut = makeSUT(
            backupURL: backupURL,
            fileUtility: FileUtility(),
            createTask: createTask,
            onProgress: recorder.handler
        )

        try await sut.perform()

        #expect(recorder.recorded.isEmpty) // no state updates
    }

    @Test func `Perform reports a phase only once while the throttle interval has not passed`() async throws {
        let backupURL = testBackupURL()

        deleteFile(at: backupURL)
        defer { deleteFile(at: backupURL) }

        let createTask = BackupCreateTaskMock()

        // Within a phase only the item count moves, and the backup task reports it once per written item.
        createTask.mockPoll(returning: .success([
            .stateUpdateInstruction(state: .contacts(1)),
            .stateUpdateInstruction(state: .contacts(2)),
            .stateUpdateInstruction(state: .contacts(3)),
            .stateUpdateInstruction(state: .groups(1)),
            .stateUpdateInstruction(state: .groups(2)),
            .done(0),
        ]))

        let recorder = ProgressRecorder()

        let sut = makeSUT(
            backupURL: backupURL,
            fileUtility: FileUtility(),
            createTask: createTask,
            progressInterval: .seconds(60),
            onProgress: recorder.handler
        )

        try await sut.perform()

        // A phase change is always reported, the counts in between are dropped.
        #expect(recorder.recorded == [
            DataBackupProgress(phase: .contacts, itemsProcessed: 1),
            DataBackupProgress(phase: .groups, itemsProcessed: 1),
        ])
    }

    @Test(arguments: [
        (
            BackupCreateStateUpdate.initialState,
            DataBackupProgress(phase: .initializing)
        ),
        (
            .contacts(1),
            DataBackupProgress(phase: .contacts, itemsProcessed: 1)
        ),
        (
            .distributionLists(2),
            DataBackupProgress(phase: .distributionLists, itemsProcessed: 2)
        ),
        (
            .groups(3),
            DataBackupProgress(phase: .groups, itemsProcessed: 3)
        ),
        (
            .cspNonces(4),
            DataBackupProgress(phase: .cspNonces, itemsProcessed: 4)
        ),
        (
            .polls(5),
            DataBackupProgress(phase: .polls, itemsProcessed: 5)
        ),
        (
            .messages(6),
            DataBackupProgress(phase: .messages, itemsProcessed: 6)
        ),
        (
            .finalizeState,
            DataBackupProgress(phase: .finalizing)
        ),
    ])
    func `Progress maps a state update of the backup task`(
        stateUpdate: BackupCreateStateUpdate,
        expected: DataBackupProgress
    ) {
        #expect(DataBackupProgress(stateUpdate) == expected)
    }

    @Test func `Progress phases are ordered the way they are reported`() {
        let phases = DataBackupProgress.Phase.allCases

        #expect(phases == [
            .initializing, .contacts, .distributionLists, .groups, .cspNonces, .polls, .messages, .finalizing,
        ])
        #expect(zip(phases, phases.dropFirst()).allSatisfy(<))
    }

    @Test func `Perform stops before polling when the task is already cancelled`() async throws {
        let backupURL = testBackupURL()

        try Data().write(to: backupURL)
        defer { deleteFile(at: backupURL) }

        let fileHandle = try FileHandle(forWritingTo: backupURL)
        defer { try? fileHandle.close() }

        let fileUtilityMock = FileUtilityMock()
        fileUtilityMock.mockCreateFileHandleForWriting = { _ in fileHandle }

        let createTask = BackupCreateTaskMock()

        let sut = makeSUT(
            backupURL: backupURL,
            fileUtility: fileUtilityMock,
            createTask: createTask
        )

        // Cancelled before the task body can run, because nothing suspends this test in between.
        let task = Task { try await sut.perform() }
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }

        #expect(createTask.calls.isEmpty)

        // A cancelled backup leaves a partial file behind, so it has to be cleaned up.
        #expect(fileUtilityMock.calls.contains(.deleteAtURL(backupURL)))
    }

    @Test func `Perform deletes the partial backup file when polling fails`() async throws {
        let backupURL = testBackupURL()

        try Data().write(to: backupURL)
        defer { deleteFile(at: backupURL) }

        let fileHandle = try FileHandle(forWritingTo: backupURL)
        defer { try? fileHandle.close() }

        let fileUtilityMock = FileUtilityMock()
        fileUtilityMock.mockCreateFileHandleForWriting = { _ in fileHandle }

        let sut = makeSUT(
            backupURL: backupURL,
            fileUtility: fileUtilityMock,
            createTask: .failingOnPoll
        )

        await #expect(throws: BackupCreateTaskError.pollError) {
            try await sut.perform()
        }

        #expect(fileUtilityMock.calls.contains(.deleteAtURL(backupURL)))
    }

    // MARK: - Private types

    /// Collects the progress the actor reports, so a test can inspect it afterwards.
    private final class ProgressRecorder: Sendable {
        private let snapshots = OSAllocatedUnfairLock<[DataBackupProgress]>(initialState: [])

        var handler: DataBackup.ProgressHandler {
            { [snapshots] progress in
                snapshots.withLock { $0.append(progress) }
            }
        }

        var recorded: [DataBackupProgress] {
            snapshots.withLock { $0 }
        }
    }

    // MARK: - Private methods

    private func makeSUT(
        backupURL: URL,
        fileUtility: sending any FileUtilityProtocol = FileUtilityMock(),
        createTask: any BackupCreateTaskProtocol = BackupCreateTaskMock(),
        progressInterval: Duration = .zero,
        onProgress: DataBackup.ProgressHandler? = nil
    ) -> DataBackup {
        DataBackup(
            backupURL: backupURL,
            fileUtility: fileUtility,
            createTask: createTask,
            progressInterval: progressInterval,
            onProgress: onProgress
        )
    }

    private func testBackupURL() -> URL {
        // Unique per test so parallel tests/suites never write to the same file on disk.
        let filename = "backup-\(UUID().uuidString).data"
        return URL.temporaryDirectory.appending(path: filename, directoryHint: .notDirectory)
    }

    private func deleteFile(at url: URL) {
        do {
            if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                try FileManager.default.removeItem(at: url)
            }
        }
        catch {
            Issue.record("Test setup failed: \(error).")
        }
    }
}
