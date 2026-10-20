import CocoaLumberjackSwift
import FileUtility
import Foundation
import libthreemaSwift

public final class DataRestore: DataRestoreProtocol {

    // MARK: - Private properties

    private let backupURL: URL
    private let fileUtility: any FileUtilityProtocol
    private let restoreTask: any DataBackupRestoreTaskProtocol
    private weak let delegate: (any DataRestoreDelegate)!
    private var identityRestored = false

    // MARK: - Lifecycle

    public init(
        backupURL: URL,
        fileUtility: any FileUtilityProtocol,
        restoreTask: any DataBackupRestoreTaskProtocol,
        delegate: any DataRestoreDelegate
    ) {
        self.backupURL = backupURL
        self.fileUtility = fileUtility
        self.restoreTask = restoreTask
        self.delegate = delegate
    }

    // MARK: - Public methods

    public func perform() async throws {
        try performOnCurrentThread()
    }

    /// Sync call for keeping in the same caller' thread.
    public func performOnCurrentThread() throws {
        let fileHandle = try openFileHandle(url: backupURL)

        defer {
            closeFileHandle(fileHandle)
        }

        var done = false

        while !done {
            switch try restoreTask.poll() {
            case let .instruction(instruction):
                try handleInstruction(instruction, fileHandle: fileHandle)

            case .done:
                done = true
            }
        }
    }

    /// Runs the restore only as far as the identity, which the backup hands over as its first instruction, and stops
    /// there.
    ///
    /// Nothing of the backup is applied by this: the restore task stays in the state that waits for the providers, and
    /// the providers are what every later step writes through. It exists so a caller can learn which identity the
    /// backup belongs to — and set the app up for it — before any of its data arrives.
    ///
    /// The task this ran on is spent afterwards. Reading the backup in is a fresh ``DataRestore`` over the same file.
    public func performUntilIdentityData() throws {
        let fileHandle = try openFileHandle(url: backupURL)

        defer {
            closeFileHandle(fileHandle)
        }

        while !identityRestored {
            switch try restoreTask.poll() {
            case let .instruction(instruction):
                try handleInstruction(instruction, fileHandle: fileHandle)

            case .done:
                throw DataRestoreError.missingIdentityDataInstruction
            }
        }
    }

    public func addProviders(_ providers: DataBackupProviders) throws {
        try restoreTask.response(
            response: DataBackupRestoreResponse(providers: providers, readResponse: nil)
        )
    }

    // MARK: - Private methods

    private func handleInstruction(_ instruction: DataBackupRestoreInstruction, fileHandle: FileHandle) throws {
        if let identityData = instruction.identityData {
            if identityRestored {
                throw DataRestoreError.duplicatedIdentityDataInstruction
            }
            try delegate.dataRestore(self, didReceiveIdentityData: identityData)
            identityRestored = true
        }
        if let stateUpdate = instruction.stateUpdate {
            try handleStateUpdateInstruction(stateUpdate)
        }
        if let readInstruction = instruction.readInstruction {
            try handleReadInstruction(readInstruction, fileHandle: fileHandle)
        }
    }

    private func handleReadInstruction(_ instruction: DataBackupRestoreReadInstruction, fileHandle: FileHandle) throws {
        switch instruction {
        case let .local(instruction):
            let streamOffset = instruction.offset
            let chunk = try fileUtility.read(
                offset: streamOffset,
                length: UInt64(instruction.length),
                from: fileHandle,
                fileURL: backupURL
            )
            let readResponse = DataBackupRestoreReadResponse(offset: streamOffset, chunk: chunk)
            try restoreTask.response(
                response: DataBackupRestoreResponse(providers: nil, readResponse: readResponse)
            )
        }
    }

    private func handleStateUpdateInstruction(_ stateUpdate: DataBackupRestoreStateUpdate) throws {
        switch stateUpdate {
        case .userData:
            DDLogInfo("Restoring user data...")

        case .contacts:
            DDLogInfo("Restoring contacts...")

        case .groups:
            DDLogInfo("Restoring groups...")

        case .distributionLists:
            DDLogInfo("Restoring distribution lists...")

        case .cspNonces:
            DDLogInfo("Restoring nonces...")

        case .polls:
            DDLogInfo("Restoring polls...")

        case .messages:
            DDLogInfo("Restoring messages...")
        }

        delegate.dataRestore(self, didReceiveStateUpdate: stateUpdate)
    }

    private func openFileHandle(url: URL) throws -> FileHandle {
        do {
            return try fileUtility.createFileHandle(forReadingFromURL: url)
        }
        catch {
            let fileName = backupURL.lastPathComponent
            DDLogError("Couldn't open the file handle for \(fileName): \(error)")
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
            DDLogError("Couldn't close the file handle (\(fileDescriptor)) for \(fileName): \(error)")
            // Absorb the error and only log the error.
        }
    }
}
