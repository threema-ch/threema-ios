import DataBackup
import Testing
import ThreemaFramework

@testable import Threema

@Suite("Local Backup Details Tests")
@MainActor
struct LocalBackupDetailsViewModelTests {

    @Test func `Screen resources are correctly set in the primary language`() {
        let sut = makeSUT()

        #expect(sut.screenTitle == "Data Backup")
        #expect(sut.shareActionTitle == "Share Backup")
        #expect(sut.shareActionIconName == "square.and.arrow.up")
        #expect(sut.keyActionTitle == "Recovery Key")
        #expect(sut.buttonTitle == "Create New Backup")

        #expect(sut.detailItems.count == 5)

        #expect(sut.detailItems[0].label == "Last Backup")
        #expect(sut.detailItems[0].isValueHighlighted == false)

        #expect(sut.detailItems[1].label == "Backup size")
        #expect(sut.detailItems[1].isValueHighlighted == false)

        #expect(sut.detailItems[2].label == "Messages")
        #expect(sut.detailItems[2].isValueHighlighted == true)

        #expect(sut.detailItems[3].label == "Media")
        #expect(sut.detailItems[3].isValueHighlighted == true)

        #expect(sut.detailItems[4].label == "Backup location")
        #expect(sut.detailItems[4].isValueHighlighted == false)
    }

    @Test func `The backup written by the manager is the file offered for sharing`() {
        let manager = BackupCreateManagerMock()
        let sut = makeSUT(manager: manager)

        #expect(sut.shareURL == manager.backupURL)
    }

    // MARK: - Detail rows

    @Test func `The rows describe the most recent backup`() {
        let lastBackup = BackupMetadata(
            date: Date(timeIntervalSince1970: 1_772_000_000),
            // A round number of bytes, so the expected string does not depend on how the formatter rounds.
            size: 1_500_000_000,
            includesMessages: true,
            includesMedia: true
        )
        let sut = makeSUT(lastBackup: lastBackup)

        #expect(sut.detailItems.map(\.label) == [
            "Last Backup", "Backup size", "Messages", "Media", "Backup location",
        ])

        // Not a literal: `DateFormatter` formats in the current time zone, so an expected string would depend on where
        // the tests run. This still pins which of the many formats the screen uses.
        #expect(sut.detailItems[0].value == DateFormatter.accessibilityRelativeDayTime(lastBackup.date))
        #expect(sut.detailItems[1].value == "1.5 GB")
        #expect(sut.detailItems[2].value == "Included")
        #expect(sut.detailItems[3].value == "Included")
        #expect(sut.detailItems[4].value == "Documents/Backup.dat")

        #expect(sut.detailItems.map(\.isValueHighlighted) == [false, false, true, true, false])
    }

    @Test func `A backup made today is dated relative to today`() {
        let sut = makeSUT(lastBackup: BackupMetadata(date: Date(), size: 0))

        #expect(sut.detailItems[0].value.hasPrefix("Today at"))
    }

    @Test func `Categories the backup left out are not highlighted`() {
        let sut = makeSUT(
            lastBackup: BackupMetadata(
                date: Date(),
                size: 42,
                includesMessages: false,
                includesMedia: false
            )
        )

        #expect(sut.detailItems[2].value == "Not included")
        #expect(sut.detailItems[3].value == "Not included")
        #expect(sut.detailItems.map(\.isValueHighlighted) == [false, false, false, false, false])
    }

    @Test func `There are no rows while no backup was ever made`() {
        let sut = makeSUT(lastBackup: nil)

        #expect(sut.detailItems.isEmpty)
    }

    // MARK: - Private methods

    private func makeSUT(
        manager: any BackupCreateManagerProtocol = BackupCreateManagerMock()
    ) -> LocalBackupDetailsViewModel {
        LocalBackupDetailsViewModel(manager: manager)
    }

    private func makeSUT(lastBackup: BackupMetadata?) -> LocalBackupDetailsViewModel {
        let manager = BackupCreateManagerMock()
        manager.lastBackup = lastBackup

        return makeSUT(manager: manager)
    }
}
