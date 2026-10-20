import Testing
import ThreemaFramework

@testable import Threema

@Suite("Backup Center Tests")
@MainActor struct BackupCenterViewModelTests {

    @Test func `Screen resources are correctly set in the primary language`() throws {
        let backupManager = BackupCreateManagerMock()
        let sut = makeSUT(backupManager: backupManager)

        sut.onAppear()

        #expect(sut.screenTitle == "Backup Center")
        #expect(sut.onlineSectionHeader == "Online")
        #expect(
            sut.onlineSubHeadline == "Securely store your Threema ID, contacts, and groups in the cloud for easy restore."
        )
        #expect(sut.offlineSectionHeader == "Offline")
        #expect(sut.offlineTitle == "Local Data Backup")
        #expect(sut.offlineSubHeadline == "Save all your chats, messages, and media locally for a complete backup.")

        let expectedDateString = try DateFormatter.accessibilityRelativeDayTime(
            #require(backupManager.lastBackup?.date)
        )
        #expect(
            sut.localBackupStatus == "Last backup: \(expectedDateString)"
        )
        #expect(sut.learnMoreButtonTitle == "Learn more")
        #expect(sut.noBackupStatus == "No backup available")
        #expect(sut.statusIconName == "circle.fill")
    }

    @Test func `The status labels are empty until the screen appears`() throws {
        let sut = makeSUT()

        #expect(sut.safeStatusLabel.isEmpty)
        #expect(sut.localBackupStatus.isEmpty)
        #expect(sut.hasSafeBackup == false)
        #expect(sut.hasLocalBackup == false)
    }

    @Test func `The localBackupStatus reflects the last local backup`() throws {
        let backupDate = Date(timeIntervalSince1970: 1_234_567_890)
        let expectedDateString = DateFormatter.accessibilityRelativeDayTime(backupDate)

        let expectations: [(lastBackup: BackupMetadata?, expectedLabel: String, expectedHasBackup: Bool)] = [
            (BackupMetadata(date: backupDate), "Last backup: \(expectedDateString)", true),
            (nil, "No backup available", false),
        ]

        for expectation in expectations {
            let backupManager = BackupCreateManagerMock()
            backupManager.lastBackup = expectation.lastBackup
            let sut = makeSUT(backupManager: backupManager)

            sut.onAppear()

            #expect(sut.localBackupStatus == expectation.expectedLabel)
            #expect(sut.hasLocalBackup == expectation.expectedHasBackup)
        }
    }

    @Test func `Appearing again picks up backups made in the meantime`() throws {
        let backupDate = Date(timeIntervalSince1970: 1_234_567_890)
        let expectedDateString = DateFormatter.accessibilityRelativeDayTime(backupDate)

        let backupManager = BackupCreateManagerMock()
        backupManager.lastBackup = nil
        let safeConfigManager = MockSafeConfigManager()
        safeConfigManager.mockGetLastBackup = nil
        let sut = makeSUT(backupManager: backupManager, safeConfigManager: safeConfigManager)

        sut.onAppear()

        #expect(sut.hasLocalBackup == false)
        #expect(sut.hasSafeBackup == false)

        backupManager.lastBackup = BackupMetadata(date: backupDate)
        safeConfigManager.mockGetLastBackup = backupDate

        sut.onAppear()

        #expect(sut.hasLocalBackup)
        #expect(sut.localBackupStatus == "Last backup: \(expectedDateString)")
        #expect(sut.hasSafeBackup)
        #expect(sut.safeStatusLabel == "Last backup: \(expectedDateString)")
    }

    @Test func `The safeStatusLabel reflects the last Safe backup`() throws {
        let backupDate = Date(timeIntervalSince1970: 1_234_567_890)
        let expectedDateString = DateFormatter.accessibilityRelativeDayTime(backupDate)

        let expectations: [(lastBackup: Date?, expectedLabel: String, expectedHasBackup: Bool)] = [
            (backupDate, "Last backup: \(expectedDateString)", true),
            (nil, "No backup available", false),
        ]

        for expectation in expectations {
            let safeConfigManager = MockSafeConfigManager()
            safeConfigManager.mockGetLastBackup = expectation.lastBackup
            let sut = makeSUT(safeConfigManager: safeConfigManager)

            sut.onAppear()

            #expect(sut.safeStatusLabel == expectation.expectedLabel)
            #expect(sut.hasSafeBackup == expectation.expectedHasBackup)
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

    @Test func `Tapping a button does not invoke the other closures`() throws {
        let sut = makeSUT()
        var calls: [String] = []
        sut.onSafeLearnMoreButtonTapped = { calls.append("safeLearnMore") }
        sut.onLocalDataBackupLearnMoreButtonTapped = { calls.append("localLearnMore") }
        sut.onSafeButtonTapped = { calls.append("safe") }
        sut.onLocalDataBackupDataButtonTapped = { calls.append("local") }

        sut.safeLearnMoreButtonTapped()
        sut.localDataBackupLearnMoreButtonTapped()
        sut.safeButtonTapped()
        sut.localDataBackupDataButtonTapped()

        #expect(calls == ["safeLearnMore", "localLearnMore", "safe", "local"])
    }

    // MARK: - Helpers

    private func makeSUT(
        appFlavor: any AppFlavorServiceProtocol = .mock,
        backupManager: any BackupCreateManagerProtocol = .mock,
        safeManager: any SafeManagerProtocol = .mock,
        safeConfigManager: any SafeConfigManagerProtocol = .mock
    ) -> BackupCenterViewModel {
        BackupCenterViewModel(
            appFlavor: appFlavor,
            backupManager: backupManager,
            safeManager: safeManager,
            safeConfigManager: safeConfigManager
        )
    }
}
