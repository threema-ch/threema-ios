import DataBackup
import DataBackupTestHelper
import FileUtility
import FileUtilityTestHelper
import Foundation
import libthreemaSwift
import libthreemaSwiftTestHelper
import Testing

// Deliberately not `@MainActor`: `DataRestore` is a non-Sendable class, so isolating the suite would
// mean sending the SUT (and the mocks in its region) into the nonisolated `perform()`.
@Suite("Data Backup Restore Tests")
struct DataRestoreTests {

    // - MARK: perform() tests

    @Test func `Perform completes the poll with success`() async throws {
        let backupURL = testBackupURL()

        let fileUtilityMock = FileUtilityMock()

        let restoreTask = BackupRestoreTaskMock()
        restoreTask.mockResponseReadResponse = { _ in 1100 }
        restoreTask.mockPoll(returning: .success([
            .identityDataInstruction,
            .stateUpdateInstruction(.contacts),
            .localReadInstruction(offset: 0, length: 100),
            .stateUpdateInstruction(.cspNonces),
            .localReadInstruction(offset: 101, length: 200),
            .stateUpdateInstruction(.distributionLists),
            .localReadInstruction(offset: 201, length: 300),
            .stateUpdateInstruction(.groups),
            .localReadInstruction(offset: 301, length: 400),
            .stateUpdateInstruction(.messages),
            .localReadInstruction(offset: 401, length: 500),
            .stateUpdateInstruction(.polls),
            .localReadInstruction(offset: 501, length: 600),
            .done
        ]))

        let delegate = DataRestoreDelegateMock()

        let sut = makeSUT(
            backupURL: backupURL,
            fileUtility: fileUtilityMock,
            restoreTask: restoreTask,
            delegate: delegate
        )

        try await sut.perform()

        #expect(delegate.calls == [
            .didReceiveIdentityData(
                IdentityData(
                    userIdentity: "ECHOECHO",
                    clientKey: ClientKey(repeating: 0, count: 32),
                    cspServerGroup: "ae"
                )
            ),
            .didReceiveStateUpdate(.contacts),
            .didReceiveStateUpdate(.cspNonces),
            .didReceiveStateUpdate(.distributionLists),
            .didReceiveStateUpdate(.groups),
            .didReceiveStateUpdate(.messages),
            .didReceiveStateUpdate(.polls),
        ])

        #expect(fileUtilityMock.calls == [
            .createFileHandleForReading(url: backupURL),
            .readFromHandle(offset: 0, length: 100, fileURL: backupURL),
            .readFromHandle(offset: 101, length: 200, fileURL: backupURL),
            .readFromHandle(offset: 201, length: 300, fileURL: backupURL),
            .readFromHandle(offset: 301, length: 400, fileURL: backupURL),
            .readFromHandle(offset: 401, length: 500, fileURL: backupURL),
            .readFromHandle(offset: 501, length: 600, fileURL: backupURL),
            .closeFileHandle
        ])

        let responses = restoreTask.calls.compactMap { call -> BackupRestoreResponse? in
            if case let .response(readResponse) = call {
                return readResponse
            }
            return nil
        }

        #expect(responses == [
            BackupRestoreResponse(offset: StreamOffset(offset: 0), chunk: Data()),
            BackupRestoreResponse(offset: StreamOffset(offset: 101), chunk: Data()),
            BackupRestoreResponse(offset: StreamOffset(offset: 201), chunk: Data()),
            BackupRestoreResponse(offset: StreamOffset(offset: 301), chunk: Data()),
            BackupRestoreResponse(offset: StreamOffset(offset: 401), chunk: Data()),
            BackupRestoreResponse(offset: StreamOffset(offset: 501), chunk: Data()),
        ])
    }

    @Test func `Perform throws when the poll sends successive identity data`() async throws {
        let restoreTask = BackupRestoreTaskMock()
        restoreTask.mockPoll(returning: .success([
            .identityDataInstruction,
            .stateUpdateInstruction(.contacts),
            .localReadInstruction(offset: 0, length: 100),
            .identityDataInstruction, // <-- DUPLICATE
            .done
        ]))

        await #expect(throws: DataRestoreError.duplicatedIdentityDataInstruction) {
            let sut = makeSUT(
                backupURL: testBackupURL(),
                restoreTask: restoreTask
            )
            try await sut.perform()
        }
    }

    @Test func `Perform throws when the backup file cannot be opened`() async throws {
        await #expect(throws: FileUtilityMockError.createReadFileHandleFailed) {
            let sut = makeSUT(
                backupURL: testBackupURL(),
                fileUtility: .failingToOpenForReading
            )
            try await sut.perform()
        }
    }

    @Test func `Perform throws when the poll call throws`() async throws {
        await #expect(throws: BackupRestoreTaskError.pollError) {
            let sut = makeSUT(
                backupURL: testBackupURL(),
                restoreTask: .failingOnPoll
            )
            try await sut.perform()
        }
    }

    @Test func `Perform throws when the poll sends a remote read instruction`() async throws {
        let restoreTask = BackupRestoreTaskMock()
        restoreTask.mockPoll(returning: .success([.remoteReadInstruction(), .done]))

        await #expect(throws: DataRestoreError.remoteRestoreNotSupported) {
            let sut = makeSUT(
                backupURL: testBackupURL(),
                restoreTask: restoreTask
            )
            try await sut.perform()
        }
    }

    @Test func `Perform throws when the poll sends a read instruction but the backup file cannot be read`() async throws {
        let restoreTask = BackupRestoreTaskMock()
        restoreTask.mockPoll(returning: .success([.localReadInstruction(offset: 0, length: 100), .done]))

        await #expect(throws: FileUtilityError.readFailed) {
            let sut = makeSUT(
                backupURL: testBackupURL(),
                fileUtility: .failingOnRead,
                restoreTask: restoreTask
            )
            try await sut.perform()
        }
    }

    @Test func `Perform throws when the poll sends a read instruction but libthreema cannot handle the read response`() async throws {
        let restoreTask = BackupRestoreTaskMock()
        restoreTask.mockPoll(returning: .success([.localReadInstruction(offset: 0, length: 100), .done]))
        restoreTask.mockResponseReadResponse = { _ in throw LibThreemaSwiftError.restoreResponse }

        await #expect(throws: LibThreemaSwiftError.restoreResponse) {
            let sut = makeSUT(
                backupURL: testBackupURL(),
                restoreTask: restoreTask
            )
            try await sut.perform()
        }
    }

    @Test func `Perform logs when the backup file cannot be closed`() async throws {
        let backupURL = testBackupURL()
        let fileUtilityMock = FileUtilityMock.failingOnClose
        let restoreTask = BackupRestoreTaskMock()

        let sut = makeSUT(
            backupURL: backupURL,
            fileUtility: fileUtilityMock,
            restoreTask: restoreTask
        )

        do {
            try await sut.perform()
        }
        catch {
            Issue.record("Expected no errors thrown, got instead: \"\(error.localizedDescription)\".")
        }

        #expect(fileUtilityMock.calls == [
            .createFileHandleForReading(url: backupURL),
            .closeFileHandle,
        ])

        #expect(restoreTask.calls == [.poll])
    }

    // - MARK: addProviders() tests

    @Test func `Add providers forwards the providers to the restore task`() throws {
        let restoreTask = BackupRestoreTaskMock()

        let sut = makeSUT(
            backupURL: testBackupURL(),
            restoreTask: restoreTask
        )

        try sut.addProviders(.mock)

        #expect(restoreTask.calls.filter { $0 == .addProviders }.count == 1)
    }

    @Test func `Add providers throws when the restore task throws`() throws {
        let restoreTask = BackupRestoreTaskMock()
        restoreTask.mockAddProviders = { _ in throw BackupRestoreTaskError.addProvidersError }

        let sut = makeSUT(
            backupURL: testBackupURL(),
            restoreTask: restoreTask
        )

        #expect(throws: BackupRestoreTaskError.addProvidersError) {
            try sut.addProviders(.mock)
        }
    }

    // MARK: - Helpers

    private func makeSUT(
        backupURL: URL,
        fileUtility: any FileUtilityProtocol = .mock,
        restoreTask: any BackupRestoreTaskProtocol = .working,
        delegate: (any DataRestoreDelegate)? = nil
    ) -> DataRestore {
        DataRestore(
            backupURL: backupURL,
            fileUtility: fileUtility,
            restoreTask: restoreTask,
            delegate: delegate ?? self.retainedDelegate
        )
    }

    private func testBackupURL() -> URL {
        // Unique per test so parallel tests/suites never write to the same file on disk.
        let filename = "backup-\(UUID().uuidString).data"
        let backupDataURL = URL.temporaryDirectory.appending(path: filename, directoryHint: .notDirectory)
        do {
            try Data(repeating: 0, count: 100).write(to: backupDataURL)
        }
        catch {
            Issue.record("Test setup failed: \(error).")
        }
        return backupDataURL
    }

    private let retainedDelegate = DataRestoreDelegateMock()
}
