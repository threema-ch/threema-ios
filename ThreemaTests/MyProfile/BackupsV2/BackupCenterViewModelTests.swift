import Testing
import ThreemaFramework

@testable import Threema

@Suite("Backup Center Tests")
@MainActor struct BackupCenterViewModelTests {

    @Test func `Screen resources are correctly set in the primary language`() throws {
        let manager = BackupCreateManagerMock()
        let sut = makeSUT(manager: manager)

        sut.onAppear()

        #expect(sut.screenTitle == "Backup Center")
        #expect(sut.onlineSectionHeader == "ONLINE")
        #expect(
            sut.onlineSubHeadline == "Securely store your Threema ID, contacts, and groups in the cloud for easy restore."
        )
        #expect(sut.offlineSectionHeader == "OFFLINE")
        #expect(sut.offlineTitle == "Local Data Backup")
        #expect(sut.offlineSubHeadline == "Save all your chats, messages, and media locally for a complete backup.")

        let expectedDateString = try DateFormatter.accessibilityRelativeDayTime(
            #require(manager.lastBackup?.date)
        )
        #expect(
            sut.offlineBackupStatus == "Last backup: \(expectedDateString)"
        )
        #expect(sut.learnMoreButtonTitle == "Learn more")
    }

    @Test func `The safeStatusLabel reflects whether safeManager is activated`() throws {
        let expectations: [(safeManager: any SafeManagerProtocol, expectedLabel: String)] = [
            (.activated, "On"),
            (.deactivated, "Off"),
        ]

        for expectation in expectations {
            let sut = makeSUT(safeManager: expectation.safeManager)

            sut.onAppear()

            #expect(sut.safeStatusLabel == expectation.expectedLabel)
        }
    }

    @Test func `The onlineTitle is flavored with the current app name`() throws {
        let expectations: [(appFlavor: any AppFlavorServiceProtocol, expectedTitle: String)] = [
            (.work, "Threema Work Safe"),
            (.onPrem, "Threema OnPrem Safe"),
            (.private, "Threema Safe"),
        ]

        for expectation in expectations {
            let sut = makeSUT(appFlavor: expectation.appFlavor)

            #expect(sut.onlineTitle == expectation.expectedTitle)
        }
    }

    @Test func `Tapping the Safe Learn More Button invokes its closure`() throws {
        let sut = makeSUT()
        var wasCalled = false
        sut.onSafeLearnMoreButtonTapped = { wasCalled = true }

        sut.safeLearnMoreButtonTapped()

        #expect(wasCalled)
    }

    @Test func `Tapping the Local Data Backup Learn More Button invokes its closure`() throws {
        let sut = makeSUT()
        var wasCalled = false
        sut.onLocalDataBackupLearnMoreButtonTapped = { wasCalled = true }

        sut.localDataBackupLearnMoreButtonTapped()

        #expect(wasCalled)
    }

    @Test func `Tapping the Safe Button invokes its closure`() throws {
        let sut = makeSUT()
        var wasCalled = false
        sut.onSafeButtonTapped = { wasCalled = true }

        sut.safeButtonTapped()

        #expect(wasCalled)
    }

    @Test func `Tapping the Local Data Backup Button invokes its closure`() throws {
        let sut = makeSUT()
        var wasCalled = false
        sut.onLocalDataBackupDataButtonTapped = { wasCalled = true }

        sut.localDataBackupDataButtonTapped()

        #expect(wasCalled)
    }

    // MARK: - Helpers

    private func makeSUT(
        appFlavor: any AppFlavorServiceProtocol = .mock,
        manager: any BackupCreateManagerProtocol = .mock,
        safeManager: any SafeManagerProtocol = .mock,
    ) -> BackupCenterViewModel {
        BackupCenterViewModel(
            appFlavor: appFlavor,
            manager: manager,
            safeManager: safeManager
        )
    }
}
