import Testing

@testable import Threema

@MainActor
struct ThreemaSafeDashboardViewModelTests {

    @Test("Resources in the screen are correct")
    func resources() {
        let sut = ThreemaSafeDashboardViewModel(
            appFlavor: .mock,
            myIdentityStore: MockMyIdentityStore(),
            mdmSetup: .mock,
            notificationCenter: .mock,
            safeConfigManager: .mock,
            safeManager: .mock,
            safeStore: .mock
        )

        #expect(sut.aboutButtonTitle == "About Threema Safe")
        #expect(sut.activateButtonTitle == "Activate Threema Safe")
        #expect(sut.backupButtonTitle == "Create Backup")
        #expect(sut.maxBackupBytesLabel == "Max. backup size")
        #expect(sut.backupSectionHeader == "BACKUP")
        #expect(sut.backupSizeLabel == "Last Size")
        #expect(sut.backupStatusLabel == "Status")
        #expect(
            sut.confirmationMessage ==
                "If you deactivate Threema Safe, any existing backups will be deleted from the server."
        )
        #expect(sut.deactivateActionTitle == "Deactivate")
        #expect(sut.deactivateButtonTitle == "Deactivate Threema Safe")
        #expect(sut.deactivateSectionFooter == "Some features have been disabled by your administrator.")
        if #available(iOS 26.0, *) {
            #expect(sut.infoIcon == "info")
        }
        else {
            #expect(sut.infoIcon == "info.circle")
        }
        #expect(sut.backupDateLabel == "Last Backup")
        #expect(sut.learnMoreButtonTitle == "Learn more")
        #expect(sut.screenTitle == "Threema Safe")
        #expect(sut.serverNameLabel == "Server Name")
        #expect(sut.serverSectionHeader == "SERVER")
        #expect(sut.storageDurationLabel == "Storage Duration")
        #expect(
            sut.threemaSafeDescription ==
                "Enable Threema Safe to create automatic secure and anonymous backups of all your important data."
        )
        #expect(sut.threemaSafeIcon == ImageResource(
            name: "ThreemaSafeIntro",
            bundle: Bundle(for: ThreemaSafeDashboardViewModel.self)
        ))
        #expect(sut.turnOffActionTitle == "Turn Off Threema Safe")
    }

    @Test("When Admin has forced Threema Safe activation, the `Deactivate` button is disabled")
    func forceCannotDeactivate() async throws {
        let sut = ThreemaSafeDashboardViewModel(
            appFlavor: .mock,
            myIdentityStore: MockMyIdentityStore(),
            mdmSetup: .safeForced,
            notificationCenter: .mock,
            safeConfigManager: .mock,
            safeManager: .mock,
            safeStore: .mock
        )

        #expect(sut.isDeactivationDisabled == true)
    }

    @Test("""
        When Threema Safe password is not preset by Admin, the `Change Password` button is enabled and has the \
        correct title.
        """)
    func changeButtonEnabled() async throws {
        let sut = ThreemaSafeDashboardViewModel(
            appFlavor: .mock,
            myIdentityStore: .mock,
            mdmSetup: .mock,
            notificationCenter: .mock,
            safeConfigManager: .mock,
            safeManager: .mock,
            safeStore: .mock
        )

        #expect(sut.isChangePasswordDisabled == false)
        #expect(sut.changePasswordButtonTitle == "Change Password")
    }

    @Test("""
        When Admin has defined a Threema Safe password for the user and the backup key matches the password then the \
        `Change password` button is disabled.
        """)
    func changePasswordDisabled() async throws {
        let mockBackupKey = Array(repeating: UInt8(ascii: "A"), count: 64)

        let sut = ThreemaSafeDashboardViewModel(
            appFlavor: .mock,
            myIdentityStore: .mock,
            mdmSetup: .safePasswordPreset,
            notificationCenter: .mock,
            safeConfigManager: {
                let m = MockSafeConfigManager()
                m.mockGetKey = mockBackupKey
                return m
            }(),
            safeManager: .mock,
            safeStore: {
                let m = MockSafeStore()
                m.createdKey = mockBackupKey
                return m
            }()
        )

        #expect(sut.isChangePasswordDisabled == true)
        #expect(sut.changePasswordButtonTitle == "Password managed by admin")
    }

    @Test("""
        When Admin has defined Threema Safe password, and the backup key does not matches the password then the \
        `Change password` button is enabled.
        """)
    func changePasswordEnabledWhenNotMatchingKey() async throws {
        let mockBackupKey = Array(repeating: UInt8(ascii: "A"), count: 64)

        let sut = ThreemaSafeDashboardViewModel(
            appFlavor: .mock,
            myIdentityStore: .mock,
            mdmSetup: .safePasswordPreset,
            notificationCenter: .mock,
            safeConfigManager: {
                let m = MockSafeConfigManager()
                m.mockGetKey = mockBackupKey
                return m
            }(),
            safeManager: .mock,
            safeStore: {
                let m = MockSafeStore()
                m.createdKey = Array(repeating: UInt8(ascii: "B"), count: 64)
                return m
            }()
        )

        #expect(sut.isChangePasswordDisabled == false)
        #expect(sut.changePasswordButtonTitle == "Change Password")
    }

    @Test("When screen appears, the system will observe specific notifications")
    func observeNotifications() async throws {
        // ARRANGE

        let mock = MockNotificationCenter()
        
        let sut = ThreemaSafeDashboardViewModel(
            appFlavor: .mock,
            myIdentityStore: .mock,
            mdmSetup: .mock,
            notificationCenter: mock,
            safeConfigManager: .mock,
            safeManager: .mock,
            safeStore: .mock
        )

        sut.onAppear()
        sut.onAppear() // second time will not register again

        #expect(mock.observers.count == 2)
        #expect(mock.observers.first?.name == Notification.Name(kSafeBackupUIRefresh))
        #expect(mock.observers.dropFirst().first?.name?.rawValue == Notification.Name.backupInProgressStatus.rawValue)
    }

    @Test("When screen disappears, the system will cancel observing notifications")
    func cancelObserving() async throws {
        // ARRANGE
        let mock = MockNotificationCenter()

        let sut = ThreemaSafeDashboardViewModel(
            appFlavor: .mock,
            myIdentityStore: .mock,
            mdmSetup: .mock,
            notificationCenter: mock,
            safeConfigManager: .mock,
            safeManager: .mock,
            safeStore: .mock
        )

        sut.onAppear()
        #expect(mock.observers.count == 2)

        // ACT
        sut.onDisappear()

        // ASSERT
        #expect(mock.observers.isEmpty)
    }

    @Test("When system broadcasts a `refresh` notification, the screen will trigger a refresh")
    func refreshFromNotifications() async {
        let notificationCenterMock = MockNotificationCenter()
        let safeManagerMock = MockSafeManager()

        let sut = ThreemaSafeDashboardViewModel(
            appFlavor: .mock,
            myIdentityStore: .mock,
            mdmSetup: .mock,
            notificationCenter: notificationCenterMock,
            safeConfigManager: .mock,
            safeManager: safeManagerMock,
            safeStore: .mock
        )

        safeManagerMock.mockIsActivated = false
        sut.onAppear()

        #expect(sut.isActivated == false)

        // simulate safe is activated
        safeManagerMock.mockIsActivated = true

        // trigger a refresh
        notificationCenterMock.post(name: Notification.Name(kSafeBackupUIRefresh), object: nil)

        // Wait for the MainActor task to start
        await Task.yield()
        await Task.yield()

        #expect(sut.isActivated == true)
    }

    @Test("When system broadcasts a `backup progress` notification, the screen will update loading state")
    func backupProgressNotification() async {
        let mock = MockNotificationCenter()

        let sut = ThreemaSafeDashboardViewModel(
            appFlavor: .mock,
            myIdentityStore: .mock,
            mdmSetup: .mock,
            notificationCenter: mock,
            safeConfigManager: .mock,
            safeManager: .mock,
            safeStore: .mock
        )

        sut.onAppear()
        #expect(sut.isLoading == false)

        // trigger a backup in progress started
        let name = Notification.Name.backupInProgressStatus
        mock.post(name: name, object: nil, userInfo: [name.rawValue: true])

        // Wait for the MainActor task to start
        await Task.yield()
        await Task.yield()
        #expect(sut.isLoading == true)

        // trigger a backup in progress stopped
        mock.post(name: name, object: nil, userInfo: [name.rawValue: false])

        // Wait for the MainActor task to start
        await Task.yield()
        await Task.yield()
        #expect(sut.isLoading == false)

        // Edge case: userInfo has different type for payload
        mock.post(name: name, object: nil, userInfo: [name.rawValue: "wrong type of payload"])
        #expect(sut.isLoading == false)
    }

    @Test("When learn more button is tapped, the correct next screen destination is set")
    func learnMore() async throws {
        let sut = ThreemaSafeDashboardViewModel(
            appFlavor: .mock,
            myIdentityStore: .mock,
            mdmSetup: .mock,
            notificationCenter: .mock,
            safeConfigManager: .mock,
            safeManager: .activated,
            safeStore: .mock
        )

        sut.onAppear()

        #expect(sut.destination == nil)

        sut.learnMoreButtonTapped()

        guard case .learnMore = sut.destination else {
            Issue.record("Expected destination to be .learnMore, got \(sut.destination.debugDescription) instead.")
            return
        }
    }

    @Test("""
        When `Activate Threema Safe` button is tapped, the correct next screen destination for Setup Password is set.
        Finish password setup will dismiss screen and will trigger a refresh.
        """)
    func activateAction() async throws {
        let mock = MockSafeManager()
        mock.mockIsActivated = false

        let sut = ThreemaSafeDashboardViewModel(
            appFlavor: .mock,
            myIdentityStore: .mock,
            mdmSetup: .mock,
            notificationCenter: .mock,
            safeConfigManager: .mock,
            safeManager: mock,
            safeStore: .mock
        )

        sut.onAppear()

        #expect(sut.destination == nil)

        sut.activateButtonTapped()

        guard case let .updatePassword(model) = sut.destination else {
            Issue.record("Expected destination to be .updatePassword, got \(sut.destination.debugDescription) instead.")
            return
        }

        #expect(sut.isActivated == false)

        // simulate setup password success leading to an activation
        mock.mockIsActivated = true

        // simulate finishing the setup password screen
        model.onFinish?()

        // A refresh is expected
        #expect(sut.isActivated == true)
    }

    @Test("""
        When `Change Password` button is tapped, the correct next screen destination for Setup Password is set.
        Finish password setup will dismiss screen and will trigger a refresh.
        """)
    func changeAction() throws {
        let mock = MockSafeManager()
        mock.mockIsActivated = false

        let sut = ThreemaSafeDashboardViewModel(
            appFlavor: .mock,
            myIdentityStore: .mock,
            mdmSetup: .mock,
            notificationCenter: .mock,
            safeConfigManager: .mock,
            safeManager: mock,
            safeStore: .mock
        )

        sut.onAppear()

        #expect(sut.destination == nil)

        sut.changePasswordButtonTapped()

        guard case let .updatePassword(model) = sut.destination else {
            Issue.record("Expected destination to be .updatePassword, got \(sut.destination.debugDescription) instead.")
            return
        }

        #expect(sut.isActivated == false)

        // simulate setup password success leading to an activation
        mock.mockIsActivated = true

        // simulate finishing the setup password screen
        model.onFinish?()

        // A refresh is expected
        #expect(sut.isActivated == true)
    }

    @Test("When `Deactivate Threema Safe button is tapped, the confirmation dialog is shown`")
    func deactivateConfirmationDialog() async throws {
        // ARANGE
        let sut = ThreemaSafeDashboardViewModel(
            appFlavor: .mock,
            myIdentityStore: .mock,
            mdmSetup: .mock,
            notificationCenter: .mock,
            safeConfigManager: .mock,
            safeManager: .activated,
            safeStore: .mock
        )

        sut.onAppear()

        #expect(sut.isActivated == true)
        #expect(sut.showsConfirmationDialog == false)

        // ACT
        sut.deactivateButtonTapped()

        // ASSERT
        #expect(sut.isActivated == true)
        #expect(sut.showsConfirmationDialog == true)
    }

    @Test("When `Deactivate` action is confirmed in the confirmation dialog, Threema Safe is deactivated")
    func confirmationDeactivation() async throws {
        let sut = ThreemaSafeDashboardViewModel(
            appFlavor: .mock,
            myIdentityStore: .mock,
            mdmSetup: .mock,
            notificationCenter: .mock,
            safeConfigManager: .mock,
            safeManager: .activated,
            safeStore: .mock
        )

        sut.onAppear()
        sut.deactivateButtonTapped()

        #expect(sut.isActivated == true)

        sut.deactivateActionConfirmed()

        #expect(sut.isActivated == false)
    }

    @Test("When `Create backup` button is tapped, a notification `Backup Trigger` is posted")
    func backupAction() async throws {
        // ARRANGE
        let mock = MockNotificationCenter()

        let sut = ThreemaSafeDashboardViewModel(
            appFlavor: .mock,
            myIdentityStore: .mock,
            mdmSetup: .mock,
            notificationCenter: mock,
            safeConfigManager: .mock,
            safeManager: .activated,
            safeStore: .mock
        )

        sut.onAppear()

        // ACT
        sut.createBackupButtonTapped()

        // ASSERT
        let expectedNotificationBroadcasted = Notification(
            name: Notification.Name(kSafeBackupTrigger),
            object: 0
        )

        #expect(mock.posted == [expectedNotificationBroadcasted])
    }

    @Test("When Backup Status Row is tapped when Backup Status has failed, an alert is shown with status error message")
    func failedBackupMessage() async throws {
        // ARRANGE

        let mock = MockSafeConfigManager.backupFailed
        mock.mockGetLastResult = "Failure reason for backup."

        let sut = ThreemaSafeDashboardViewModel(
            appFlavor: .mock,
            myIdentityStore: .mock,
            mdmSetup: .mock,
            notificationCenter: .mock,
            safeConfigManager: mock,
            safeManager: .activated,
            safeStore: .mock
        )

        sut.onAppear()

        // ACT

        #expect(sut.alert == nil)
        sut.backupStatusRowTapped()

        // ASSERT

        #expect(sut.alert?.title == "Backup Error")
        #expect(sut.alert?.message == "Failure reason for backup.")
        #expect(sut.alert?.dismissTitle == "OK")
    }

    @Test("Backup information is updated on screen")
    func backupInformation() async throws {
        let sut = ThreemaSafeDashboardViewModel(
            appFlavor: .mock,
            myIdentityStore: .mock,
            mdmSetup: .mock,
            notificationCenter: .mock,
            safeConfigManager: .mock,
            safeManager: .activated,
            safeStore: .mock
        )

        sut.onAppear()

        // Server section
        #expect(sut.serverSectionHeader == "SERVER")
        #expect(sut.serverNameLabel == "Server Name")
        #expect(sut.serverNameValue == "Default Server")
        #expect(sut.maxBackupBytesLabel == "Max. backup size")
        #expect(sut.maxBackupBytesValue == "1 MB")
        #expect(sut.storageDurationLabel == "Storage Duration")
        #expect(sut.storageDurationValue == "10 days")

        // Backup section
        #expect(sut.backupStatusLabel == "Status")
        if case .succeeded = sut.backupStatusValue {
            // no-op
        }
        else {
            Issue.record("Expected backup status to be .succeeded got \(sut.backupStatusValue) instead.")
        }
        #expect(sut.backupDateLabel == "Last Backup")
        
        #expect(sut.backupDateValue == "14 Feb 2009 at 00:31" || sut.backupDateValue == "14 Feb 2009 at 01:31")
        #expect(sut.backupSizeLabel == "Last Size")
        #expect(sut.backupSizeValue == "5 KB")
    }
}
