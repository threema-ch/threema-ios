import FileUtility
import FileUtilityTestHelper
import Foundation
import Testing
@testable import ThreemaFramework

@Suite("PartialBackupFiles")
struct PartialBackupFilesTests {

    private let backupURL = fileURL("2026-10-12T10-00-00-threema.backup")

    private let fileUtility = FileUtilityMock()
    private let partialBackupFiles: PartialBackupFiles

    init() {
        self.partialBackupFiles = PartialBackupFiles(fileUtility: fileUtility)
    }

    @Test("Writes the backup next to its final location, under a partial name")
    func partialURL() {
        #expect(partialBackupFiles.partialURL(for: backupURL) == fileURL("2026-10-12T10-00-00-threema.backup.partial"))
    }

    @Test("Renames the partial file to its final name")
    func movesToFinalName() throws {
        try partialBackupFiles.moveToFinalName(backupURL)

        #expect(fileUtility.calls == [.replaceFile(from: partialBackupFiles.partialURL(for: backupURL), to: backupURL)])
    }

    @Test("Deletes only partial files")
    func removesOnlyPartialFiles() {
        let partialURLs = [
            fileURL("2026-10-12T10-00-00-threema.backup.partial"),
            fileURL("2026-10-12T10-05-00-threema.backup.partial"),
        ]
        fileUtility.mockContentsOfDirectoryAtURL = { _, _, _ in
            [fileURL("2026-10-01T08-00-00-threema.backup"), fileURL("notes.txt")] + partialURLs
        }

        partialBackupFiles.removeLeftovers()

        #expect(deleteCalls == partialURLs)
    }

    @Test("Looks for partial files in the documents directory only")
    func listsDocumentsDirectory() {
        partialBackupFiles.removeLeftovers()

        #expect(fileUtility.calls == [.contentsOfDirectoryAtURL(.documentsDirectory, keys: nil, options: [])])
    }

    @Test("Keeps deleting after a partial file could not be deleted")
    func continuesAfterFailedDelete() {
        let failingURL = fileURL("2026-10-12T10-00-00-threema.backup.partial")
        let otherURL = fileURL("2026-10-12T10-05-00-threema.backup.partial")
        fileUtility.mockContentsOfDirectoryAtURL = { _, _, _ in [failingURL, otherURL] }
        fileUtility.mockDeleteAtURL = { url in
            if url == failingURL {
                throw CocoaError(.fileWriteNoPermission)
            }
        }

        partialBackupFiles.removeLeftovers()

        #expect(deleteCalls == [failingURL, otherURL])
    }

    @Test("Deletes nothing if the documents directory cannot be listed")
    func deletesNothingIfListingFails() {
        fileUtility.mockContentsOfDirectoryAtURL = { _, _, _ in throw CocoaError(.fileReadNoPermission) }

        partialBackupFiles.removeLeftovers()

        #expect(deleteCalls.isEmpty)
    }

    // MARK: - Helpers

    private var deleteCalls: [URL] {
        fileUtility.calls.compactMap { call in
            guard case let .deleteAtURL(url) = call else {
                return nil
            }
            return url
        }
    }
}

private func fileURL(_ fileName: String) -> URL {
    URL.documentsDirectory.appending(path: fileName, directoryHint: .notDirectory)
}
