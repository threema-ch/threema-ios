import CocoaLumberjackSwift
import FileUtility
import Foundation
import libthreemaSwift

public final actor DataBackup: DataBackupProtocol {

    // MARK: - Public types

    public typealias ProgressHandler = @Sendable (DataBackupProgress) -> Void

    // MARK: - Private properties

    private let backupURL: URL
    private let fileUtility: FileUtilityProtocol
    private let createTask: any DataBackupCreateTaskProtocol
    private let progressInterval: Duration
    private let onProgress: ProgressHandler?

    private var incompleteBackupURL: URL?
    private var lastReportedPhase: DataBackupProgress.Phase?
    private var lastReportedAt = ContinuousClock.now

    // MARK: - Lifetime

    public init(
        backupURL: URL,
        fileUtility: any FileUtilityProtocol,
        createTask: any DataBackupCreateTaskProtocol,
        progressInterval: Duration = .milliseconds(500),
        onProgress: ProgressHandler? = nil
    ) {
        self.backupURL = backupURL
        self.fileUtility = fileUtility
        self.createTask = createTask
        self.progressInterval = progressInterval
        self.onProgress = onProgress
    }

    // MARK: - Public methods

    public func perform() async throws {
        try createEmptyFile(at: backupURL)
        incompleteBackupURL = backupURL

        defer { cleanUpIfNeeded() }

        let fileHandle = try openFileHandle(url: backupURL)

        defer { closeFileHandle(fileHandle) }

        var done = false

        while !done {
            // Polling and writing never suspend, so this loop is not cancelled implicitly.
            try Task.checkCancellation()

            switch try createTask.poll() {
            case let .instruction(instruction):
                try handleInstruction(instruction, fileHandle: fileHandle)

            case .done:
                done = true
                incompleteBackupURL = nil
            }
        }
    }

    // MARK: - Private methods

    private func handleInstruction(_ payload: DataBackupCreateInstruction, fileHandle: FileHandle) throws {
        if let writeInstruction = payload.writeInstruction {
            try handleWriteInstruction(writeInstruction, fileHandle: fileHandle)
        }

        if let stateUpdate = payload.stateUpdate {
            handleStateUpdate(stateUpdate)
        }
    }

    private func handleWriteInstruction(_ instruction: DataBackupCreateWriteInstruction, fileHandle: FileHandle) throws {
        switch instruction {
        case let .local(.append(data)):
            try fileUtility.write(contents: data, offset: nil, to: fileHandle, fileURL: backupURL)

        case let .local(.writeAt(offset, data)):
            try fileUtility.write(contents: data, offset: offset, to: fileHandle, fileURL: backupURL)
        }
    }

    /// Reports progress, throttled.
    ///
    /// The backup task recomputes its state update on every poll, so within a phase only the item count moves and an
    /// update arrives once per written item. Phase changes are always reported, item counts of the phase that is
    /// already reported at most once per ``progressInterval``.
    private func handleStateUpdate(_ stateUpdate: DataBackupCreateStateUpdate) {
        let progress = DataBackupProgress(stateUpdate)
        let now = ContinuousClock.now

        guard progress.phase != lastReportedPhase || lastReportedAt.duration(to: now) >= progressInterval else {
            return
        }

        lastReportedPhase = progress.phase
        lastReportedAt = now

        DDLogVerbose("Backup create progress: \(progress.phase)")

        onProgress?(progress)
    }

    private func createEmptyFile(at url: URL) throws {
        do {
            if fileUtility.fileExists(at: url) {
                try fileUtility.delete(at: url)
            }
            try fileUtility.createEmptyFile(atURL: url)
        }
        catch {
            let fileName = backupURL.lastPathComponent
            DDLogError("Couldn't create an empty file named \(fileName): \(error)")
            throw error
        }
    }

    private func openFileHandle(url: URL) throws -> FileHandle {
        do {
            return try fileUtility.createFileHandle(forWritingToURL: backupURL)
        }
        catch {
            let fileName = backupURL.lastPathComponent
            DDLogError("Couldn't open the file handle for file name \(fileName): \(error)")
            throw error
        }
    }

    private func closeFileHandle(_ fileHandle: FileHandle) {
        do {
            try fileUtility.closeFileHandle(fileHandle)
        }
        catch {
            let fileDescriptor = fileHandle.fileDescriptor
            let fileName = backupURL.lastPathComponent
            DDLogError("Couldn't close the file handle \(fileDescriptor) for file name \(fileName): \(error)")
            // Absorb the error and only log the error.
        }
    }

    private func cleanUpIfNeeded() {
        guard let incompleteBackupURL else {
            return
        }
        do {
            try fileUtility.delete(at: incompleteBackupURL)
        }
        catch {
            let fileName = incompleteBackupURL.lastPathComponent
            DDLogError("Couldn't delete the file \(fileName): \(error)")
            // Absorb the error and only log the error.
        }
    }
}
