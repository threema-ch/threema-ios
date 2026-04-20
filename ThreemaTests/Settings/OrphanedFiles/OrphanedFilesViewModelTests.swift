import Testing
import ThreemaFramework

@testable import Threema

@Suite("OrphanedFilesViewModelTests")
@MainActor
struct OrphanedFilesViewModelTests {

    @Test("ViewModel uses the correct strings from the catalogue")
    func usingTheCorrectStrings() async throws {
        typealias sut = OrphanedFilesViewModel.Strings

        #expect(sut.DeleteOrphanedFiles.header == "Delete Orphaned Files")
        #expect(
            sut.DeleteOrphanedFiles.description == """
                When deleting data in the Storage Management in previous Threema versions, \
                it could happen in rare cases that (media) files were not deleted correctly but \
                removed in Threema. Create an iTunes backup first; data loss may occur!
                """
        )

        #expect(sut.OrphanedFiles.header == "ORPHANED FILES")
        #expect(sut.OrphanedFiles.moveButton == "Move to Trash Bin")
        #expect(sut.OrphanedFiles.noFilesfooter == "There are no orphaned files.")

        #expect(sut.TrashBin.header == "TRASH BIN")
        #expect(sut.TrashBin.restoreButton == "Restore Contents of Trash Bin")
        #expect(sut.TrashBin.deleteButton == "Delete Contents of Trash Bin")
        #expect(sut.TrashBin.noFilesFooter == "The trash bin is empty.")

        #expect(sut.LogFiles.header == "LOG FILES")
        #expect(sut.LogFiles.logButton == "Log Files into Debug Log")

        #expect(
            sut.Confirmation
                .title == "Would you like to permanently delete the orphaned files? This action cannot be undone."
        )
        #expect(sut.Confirmation.deleteButton == "Delete Contents of Trash Bin")
        #expect(sut.Confirmation.cancelButton == "Cancel")
    }

    @Test("Loading operation with zero orphaned files and zero trash files will deactivate the sections")
    func disabledSections() async throws {
        let a = LoggingFilesManagerMock()
        let b = OrphanedFilesManagerMock(orphaned: [], totalCount: 0)
        let c = TrashBinManagerMock(files: [], size: 0)

        let sut = OrphanedFilesViewModel(
            loggingFilesManager: a,
            orphanedFilesManager: b,
            trashBinManager: c,
            validationLoggingEnabled: false
        )

        await sut.loadInitialData()

        #expect(sut.orphanedFilesSectionEnabled == false)
        #expect(sut.orphanedFilesSectionFooter == "There are no orphaned files.")

        #expect(sut.trashBinSectionEnabled == false)
        #expect(sut.trashBinSectionFooter == "The trash bin is empty.")
        #expect(sut.validationLoggingEnabled == false)
    }

    @Test("Loading operation with existing orphaned files and existing trash files will activate the sections")
    func enabledSections() async throws {
        let a = LoggingFilesManagerMock()
        let b = OrphanedFilesManagerMock(orphaned: ["a", "b", "c"], totalCount: 10)
        let c = TrashBinManagerMock(files: ["c", "d", "e"], size: 1_000_000)
        let sut = OrphanedFilesViewModel(
            loggingFilesManager: a,
            orphanedFilesManager: b,
            trashBinManager: c,
            validationLoggingEnabled: true
        )

        await sut.loadInitialData()

        #expect(sut.orphanedFilesSectionEnabled == true)
        #expect(sut.orphanedFilesSectionFooter == """
            3 of 13 files are orphaned. \
            Move the orphaned files to the trash bin, and ensure that no (media) files are missing in Threema.
            """)

        #expect(sut.trashBinSectionEnabled == true)
        #expect(sut.trashBinSectionFooter == """
            There are 3 files (1 MB) in the trash bin. \
            If there are no (media) files missing in Threema, empty the trash bin to permanently delete the orphaned files.
            """)

        #expect(sut.validationLoggingEnabled == true)
    }

    @Test("Moving orphaned files to trash operation")
    func moving() async throws {
        let a = LoggingFilesManagerMock()
        let b = OrphanedFilesManagerMock(orphaned: ["a", "b", "c"], totalCount: 10)
        let c = TrashBinManagerMock(files: [], size: 0)
        let sut = OrphanedFilesViewModel(
            loggingFilesManager: a,
            orphanedFilesManager: b,
            trashBinManager: c,
            validationLoggingEnabled: true
        )

        await sut.loadInitialData()
        await sut.moveOrphanedFilesToBin()

        #expect(c.moveToTrashBinCalledValues == [["a", "b", "c"]])
    }

    @Test("Restore files from trash bin")
    func restoring() async throws {
        let a = LoggingFilesManagerMock()
        let b = OrphanedFilesManagerMock(orphaned: [], totalCount: 0)
        let c = TrashBinManagerMock(files: ["a", "b", "c"], size: 1000)
        let sut = OrphanedFilesViewModel(
            loggingFilesManager: a,
            orphanedFilesManager: b,
            trashBinManager: c,
            validationLoggingEnabled: true
        )

        await sut.loadInitialData()
        await sut.restoreTrashBin()
        await sut.restoreTrashBin()

        #expect(c.restoreTrashBinCallCount == 2)
    }

    @Test("Emptying files from trash bin")
    func emptying() async throws {
        let a = LoggingFilesManagerMock()
        let b = OrphanedFilesManagerMock(orphaned: [], totalCount: 0)
        let c = TrashBinManagerMock(files: ["a", "b", "c"], size: 1000)
        let sut = OrphanedFilesViewModel(
            loggingFilesManager: a,
            orphanedFilesManager: b,
            trashBinManager: c,
            validationLoggingEnabled: true
        )

        await sut.loadInitialData()
        await sut.emptyTrashBinConfirmed()
        await sut.emptyTrashBinConfirmed()

        #expect(c.emptyTrashBinCallCount == 2)
    }

    @Test("Logging files operation")
    func loggingFiles() async throws {
        let a = LoggingFilesManagerMock()
        let b = OrphanedFilesManagerMock(orphaned: [], totalCount: 0)
        let c = TrashBinManagerMock(files: [], size: 0)
        let sut = OrphanedFilesViewModel(
            loggingFilesManager: a,
            orphanedFilesManager: b,
            trashBinManager: c,
            validationLoggingEnabled: true
        )

        await sut.loadInitialData()
        await sut.logAppFiles()
        await sut.logAppFiles()

        #expect(a.logDirectoriesAndFilesCalledCount == 2)
    }

    @Test("Empty trash operation will show a confirmation dialog")
    func confirmationDialog() async throws {
        let a = LoggingFilesManagerMock()
        let b = OrphanedFilesManagerMock(orphaned: [], totalCount: 0)
        let c = TrashBinManagerMock(files: ["a", "b", "c"], size: 1000)
        let sut = OrphanedFilesViewModel(
            loggingFilesManager: a,
            orphanedFilesManager: b,
            trashBinManager: c,
            validationLoggingEnabled: true
        )

        await sut.loadInitialData()
        #expect(sut.isShowingBinConfirmationDialog == false)

        sut.emptyTrashBin()

        #expect(sut.isShowingBinConfirmationDialog == true)
    }
}

struct OrphanedFilesManagerMock: OrphanedFilesManagerProtocol {
    let orphaned: [String]
    let totalCount: Int

    func getOrphanedFilesData() -> (orphaned: [String], totalCount: Int) { (orphaned, totalCount) }
}

final class TrashBinManagerMock: TrashBinManagerProtocol {
    let files: [String]
    let size: Int64

    init(files: [String], size: Int64) {
        self.files = files
        self.size = size
    }

    var moveToTrashBinCalledValues: [[String]] = []
    var restoreTrashBinCallCount = 0
    var emptyTrashBinCallCount = 0

    func getTrashBinFilesData() -> (files: [String], size: Int64) { (files, size) }

    func moveToTrashBin(_ files: [String]) {
        moveToTrashBinCalledValues.append(files)
    }

    func restoreTrashBin() {
        restoreTrashBinCallCount += 1
    }

    func emptyTrashBin() {
        emptyTrashBinCallCount += 1
    }
}

class LoggingFilesManagerMock: LoggingFilesManagerProtocol {
    var logDirectoriesAndFilesCalledCount = 0

    func logDirectoriesAndFiles() {
        logDirectoriesAndFilesCalledCount += 1
    }
}
