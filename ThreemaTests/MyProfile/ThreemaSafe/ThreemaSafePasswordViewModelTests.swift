import Testing

@testable import Threema

@MainActor
struct ThreemaSafePasswordViewModelTests {

    @Test("Static Resources in the screen are correct")
    func resources() {
        let sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: .mock, mdmSetup: .mock
        )
        #expect(sut.screenTitle == "Threema Safe")
        #expect(sut.passwordSectionHeader == "Choose a password")
        #expect(sut.passwordPlaceholder == "Password")
        #expect(sut.confirmationPasswordPlaceholder == "Enter Password again")
        #expect(sut.serverSectionHeader == "SERVER NAME")
        #expect(sut.serverToggleLabel == "Use default server")
        #expect(sut.serverAuthenticationHeader == "AUTHENTICATION (OPTIONAL)")
        #expect(sut.serverAddressPlaceholder == "https://server.example.com")
        #expect(sut.serverUsernamePlaceholder == "Username")
        #expect(sut.serverPasswordPlaceholder == "Password")
        #expect(sut.cancelButtonTitle == "Cancel")
    }

    @Test("Cancel button visibility")
    func cancelButton() async throws {
        var sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: .mock,
            mdmSetup: .safeForced
        )

        sut.onAppear()

        #expect(sut.isCancelButtonVisible == false)

        sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock,
            myIdentityStore: .mock,
            safeConfigManager: .mock,
            safeManager: .mock,
            mdmSetup: .mock
        )

        sut.onAppear()

        #expect(sut.isCancelButtonVisible == true)
    }

    @Test("Right button title")
    func rightButtonTitle() async throws {
        var sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: .activated, mdmSetup: .mock
        )

        sut.onAppear()

        #expect(sut.rightButtonTitle == "Change")

        sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: .deactivated,
            mdmSetup: .mock
        )

        sut.onAppear()

        #expect(sut.rightButtonTitle == "Activate")
    }

    @Test(
        "Right button is disabled when passwords fields are empty and password is not preset by admin",
        arguments: [("", ""), ("aaaa1111", ""), ("", "aaaa1111")]
    )
    func rightButtonStateDisabledPasswordEmpty(value: (pass: String, confirmation: String)) async throws {
        let sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: .deactivated,
            mdmSetup: .mock
        )

        sut.onAppear()

        sut.passwordTextInput = value.pass
        sut.confirmationPasswordTextInput = value.confirmation

        #expect(sut.isRightButtonDisabled == true)
    }

    @Test("Right button is enabled when password is preset by admin")
    func rightButtonStateEnabledWhenPasswordPreset() async throws {
        let sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: .deactivated,
            mdmSetup: .safePasswordPreset
        )

        sut.onAppear()

        sut.passwordTextInput = ""
        sut.confirmationPasswordTextInput = ""

        #expect(sut.isRightButtonDisabled == false)
    }

    @Test("Right button is enabled when passwords fields are not empty")
    func rightButtonStateEnabled() async throws {
        let sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: .deactivated,
            mdmSetup: .mock
        )

        sut.onAppear()

        sut.passwordTextInput = "1"
        sut.confirmationPasswordTextInput = "2"

        #expect(sut.isRightButtonDisabled == false)
    }

    @Test("Message Section is visible when safe is deactivated, password and server are managed by admin")
    func messageSectionVisible() async throws {
        let sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: .deactivated,
            mdmSetup: .safePasswordAndServerPreset
        )

        sut.onAppear()

        #expect(sut.isMessageSectionVisible == true)
    }

    @Test("Message Section is not visible")
    func messageSectionNotVisible() async throws {
        let sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: .activated, mdmSetup: .mock
        )

        sut.onAppear()

        #expect(sut.isMessageSectionVisible == false)
    }

    @Test("Message Section Visible when Threema Safe is not forced")
    func messageSectionUnforced() async throws {
        let sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: .deactivated,
            mdmSetup: .safePasswordAndServerPreset
        )

        sut.onAppear()

        #expect(sut.isMessageSectionVisible == true)
        #expect(sut.messageSectionText == "New Managed Threema Safe Password and Server Set by Your Administrator")
    }

    @Test("Message Section Visible when Threema Safe is forced")
    func messageSectionForced() async throws {
        let sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: .deactivated,
            mdmSetup: .safeForcedWithPasswordAndServerPreset
        )

        sut.onAppear()

        #expect(sut.isMessageSectionVisible == true)
        #expect(sut.messageSectionText == "Your administrator enabled Threema Safe for your device.")
    }

    @Test("Password section is not visible")
    func passwordSectionNotVisible() async throws {
        for mdmSetup in [
            MockMDMSetup.safePasswordPreset,
            .safePasswordAndServerPreset,
            .safeForcedWithPasswordPreset,
            .safeForcedWithPasswordAndServerPreset,
        ] {
            let sut = ThreemaSafePasswordViewModel(
                appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: .deactivated,
                mdmSetup: mdmSetup
            )

            sut.onAppear()

            #expect(sut.isPasswordSectionVisible == false)
        }
    }

    @Test("Password section is visible")
    func passwordSectionVisible() async throws {
        for mdmSetup in [
            MockMDMSetup.mock,
            .safeForced,
            .safeForcedWithServerPreset,
        ] {
            let sut = ThreemaSafePasswordViewModel(
                appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: .deactivated,
                mdmSetup: mdmSetup
            )

            sut.onAppear()

            #expect(sut.isPasswordSectionVisible == true)
        }
    }

    @Test("Password section footer when changing password")
    func passwordSectionChangingPassword() async throws {
        let sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: .activated,
            mdmSetup: .mock
        )

        sut.onAppear()

        #expect(
            sut.passwordSectionFooter == """
                Please choose a password. You will need this password to restore your Threema Safe backup.
                """
        )
    }

    @Test("Password section footer when activating with no MDM presets")
    func passwordSectionActivatingNoPresets() async throws {
        let sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: .deactivated,
            mdmSetup: .mock
        )

        sut.onAppear()

        #expect(
            sut.passwordSectionFooter == """
                Please choose a password. You will need this password to restore your Threema Safe backup.
                """
        )
    }

    @Test("Password section footer when activating with no MDM password preset")
    func passwordSectionActivatingPasswordPresets() async throws {
        let sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: .deactivated,
            mdmSetup: .safePasswordPreset
        )

        sut.onAppear()

        #expect(
            sut.passwordSectionFooter == """
                New Managed Threema Safe Password Set by Your Administrator.
                Password managed by admin.
                """
        )
    }

    @Test("Password section footer when activating with no MDM forced safe")
    func passwordSectionActivatingForced() async throws {
        let sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: .deactivated,
            mdmSetup: .safeForced
        )

        sut.onAppear()

        #expect(
            sut.passwordSectionFooter == """
                Your administrator enabled Threema Safe for your device.

                Please choose a password. You will need this password to restore your Threema Safe backup.
                """
        )
    }

    @Test("Server section visible")
    func serverSection() async throws {
        let sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: .deactivated,
            mdmSetup: .mock
        )

        sut.onAppear()

        #expect(sut.isServerSectionVisible == true)
    }

    @Test("Server section not visible")
    func serverSectionNotVisible() async throws {
        let sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: .activated, mdmSetup: .mock
        )

        sut.onAppear()

        #expect(sut.isServerSectionVisible == false)

        for mdmSetup in [
            MockMDMSetup.safeServerPreset,
            .safePasswordAndServerPreset,
            .safeForcedWithServerPreset,
            .safeForcedWithPasswordAndServerPreset,
        ] {
            let sut = ThreemaSafePasswordViewModel(
                appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: .activated,
                mdmSetup: mdmSetup
            )

            sut.onAppear()

            #expect(sut.isServerSectionVisible == false)
        }
    }

    @Test("Custom server is visible if the default server switch is switched off")
    func customServer() async throws {
        let sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: .mock, mdmSetup: .mock
        )

        sut.onAppear()
        #expect(sut.isCustomServerInputVisible == false)

        sut.isDefaultServerSwitchedOn = false
        #expect(sut.isCustomServerInputVisible == true)
    }

    @Test("Server section footer")
    func serverSectionFooterNoPresets() async throws {
        var sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: .mock, mdmSetup: .mock
        )

        sut.onAppear()

        #expect(
            sut.serverSectionFooter == """
                You can use Threema’s server or specify a third-party backup server to use instead.
                """
        )

        sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: .mock,
            mdmSetup: .safeForcedWithPasswordPreset
        )

        sut.onAppear()

        #expect(
            sut.serverSectionFooter == """
                Your administrator enabled Threema Safe for your device.

                You can use Threema’s server or specify a third-party backup server to use instead.
                """
        )

        sut = ThreemaSafePasswordViewModel(
            appFlavor: .onPrem, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: .mock, mdmSetup: .mock
        )

        sut.onAppear()

        #expect(
            sut.serverSectionFooter == """
                Store your Threema Safe backup on your organization’s server, or specify a different backup server.
                """
        )

        sut = ThreemaSafePasswordViewModel(
            appFlavor: .onPrem, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: .mock,
            mdmSetup: .safeForcedWithPasswordPreset
        )

        sut.onAppear()

        #expect(
            sut.serverSectionFooter == """
                Your administrator enabled Threema Safe for your device.

                Store your Threema Safe backup on your organization’s server, or specify a different backup server.
                """
        )
    }

    @Test("When cancel button is tapped, the screen should dismiss")
    func onCancelTapped() async throws {
        let sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: .mock, mdmSetup: .mock
        )

        var closureCalledCount = 0
        sut.onCancel = { closureCalledCount += 1 }

        sut.onAppear()

        #expect(closureCalledCount == 0)

        sut.cancelButtonTapped()

        #expect(closureCalledCount == 1)
    }

    @Test("When right button is tapped, and custom server URL is not valid, it should show an alert")
    func invalidCustomServerURL() async throws {
        let safeManagerMock = MockSafeManager()

        struct TestServerError: Error, LocalizedError {
            var errorDescription: String? { "The server is invalid" }
        }

        safeManagerMock.mockTestServerReturn = .failure(TestServerError())

        let sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: safeManagerMock,
            mdmSetup: .mock
        )

        sut.onAppear()

        sut.passwordTextInput = "abcd1234"
        sut.isDefaultServerSwitchedOn = false
        sut.serverURLInput = "invalid-server"

        await sut.rightButtonTapped()

        let expectedAlert = ThreemaSafePasswordViewModel.AlertData(
            title: "Test server",
            message: "Please enter a valid HTTPS address.",
            dismissTitle: "OK"
        )

        #expect(sut.alert?.title == expectedAlert.title)
        #expect(sut.alert?.message == expectedAlert.message)
        #expect(sut.alert?.dismissTitle == expectedAlert.dismissTitle)
    }

    @Test("When right button is tapped, and custom server endpoint is not valid, it should show an alert")
    func invalidCustomServer() async throws {
        let safeManagerMock = MockSafeManager()

        struct TestServerError: Error, LocalizedError {
            var errorDescription: String? { "The server is invalid" }
        }

        // Simulate an error response when validating the server
        safeManagerMock.mockTestServerReturn = .failure(TestServerError())

        let sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: safeManagerMock,
            mdmSetup: .mock
        )

        sut.onAppear()

        sut.passwordTextInput = "abcd1234"
        sut.isDefaultServerSwitchedOn = false
        sut.serverURLInput = "https://invalid.threema.ch"
        sut.serverUsernameInput = "johnsmith"
        sut.serverPasswordInput = "q1w2e3r4!@"

        await sut.rightButtonTapped()

        let expectedAlert = ThreemaSafePasswordViewModel.AlertData(
            title: "Test server",
            message: "The server is invalid",
            dismissTitle: "OK"
        )

        #expect(sut.alert?.title == expectedAlert.title)
        #expect(sut.alert?.message == expectedAlert.message)
        #expect(sut.alert?.dismissTitle == expectedAlert.dismissTitle)
    }

    @Test("When right button is tapped, and password is invalid, it should show an error alert")
    func invalidPassword() async throws {
        let sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: .mock, mdmSetup: .mock
        )

        sut.onAppear()

        sut.passwordTextInput = "1111" // password too short
        sut.confirmationPasswordTextInput = "1111"

        await sut.rightButtonTapped()

        let expectedAlert = ThreemaSafePasswordViewModel.AlertData(
            title: "Password too short",
            message: "The password is too short. Please enter at least 8 characters.",
            dismissTitle: "OK"
        )

        #expect(sut.warning == nil)
        #expect(sut.alert?.title == expectedAlert.title)
        #expect(sut.alert?.message == expectedAlert.message)
        #expect(sut.alert?.dismissTitle == expectedAlert.dismissTitle)
    }

    @Test("When right button is tapped, and password is weak, it should show a confirmation dialog")
    func weakPassword() async throws {
        let sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: .mock, mdmSetup: .mock
        )

        sut.onAppear()

        sut.passwordTextInput = "11111111" // password weak, only numbers
        sut.confirmationPasswordTextInput = "11111111"

        await sut.rightButtonTapped()

        let expectedConfirmationDialog = ThreemaSafePasswordViewModel.ConfirmationDialogData(
            title: "Weak password",
            message: """
                The selected password for Threema Safe is not secure and can be easily guessed by attackers. \
                Please choose another one. Hint: Use a password composed of multiple individual words.
                """,
            actionTitle: "Continue Anyway",
            cancelTitle: "Try Again",
            action: { /* no-op */ },
            cancel: { /* no-op */ }
        )

        #expect(sut.alert == nil)
        #expect(sut.warning?.title == expectedConfirmationDialog.title)
        #expect(sut.warning?.message == expectedConfirmationDialog.message)
        #expect(sut.warning?.actionTitle == expectedConfirmationDialog.actionTitle)
        #expect(sut.warning?.cancelTitle == expectedConfirmationDialog.cancelTitle)

        // Simulate tap on cancel action in the confirmation dialog
        await sut.warning?.cancel()

        #expect(sut.warning == nil)
    }

    @Test("When right button is tapped, and password is weak, tap on cancel will dismiss the confirmation dialog")
    func weakPasswordCancel() async throws {
        let sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: .mock, mdmSetup: .mock
        )

        sut.onAppear()

        sut.passwordTextInput = "11111111" // password weak, only numbers
        sut.confirmationPasswordTextInput = "11111111"

        await sut.rightButtonTapped()
        #expect(sut.warning != nil)

        // Simulate tap on cancel action in the confirmation dialog
        await sut.warning?.cancel()

        #expect(sut.warning == nil)
    }

    @Test("When right button is tapped, the password is valid and server default, the activation succeeds")
    func activateWithValidPasswordAndDefault() async throws {
        let safeManagerMock = MockSafeManager.deactivated
        safeManagerMock.mockActivateReturn = .success(())

        let sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: safeManagerMock,
            mdmSetup: .mock
        )

        sut.onAppear()

        sut.passwordTextInput = "q1w2e3r4!@"
        sut.confirmationPasswordTextInput = "q1w2e3r4!@"
        sut.isDefaultServerSwitchedOn = true

        #expect(sut.isActivated == false)
        #expect(safeManagerMock.verifyActivateCalls.isEmpty)

        // Simulate Save
        await sut.rightButtonTapped()

        #expect(safeManagerMock.verifyActivateCalls.count == 1)
        #expect(safeManagerMock.verifyActivateCalls.first?.identity == "ECHOECHO")
        #expect(safeManagerMock.verifyActivateCalls.first?.safePassword == "q1w2e3r4!@")
        #expect(safeManagerMock.verifyActivateCalls.first?.customServer == nil)
        #expect(safeManagerMock.verifyActivateCalls.first?.serverUser == nil)
        #expect(safeManagerMock.verifyActivateCalls.first?.serverPassword == nil)
        #expect(safeManagerMock.verifyActivateCalls.first?.server == nil)
        #expect(safeManagerMock.verifyActivateCalls.first?.maxBackupBytes == nil)
        #expect(safeManagerMock.verifyActivateCalls.first?.retentionDays == nil)

        #expect(safeManagerMock.verifyStartBackupCalls.count == 1)
        #expect(safeManagerMock.verifyStartBackupCalls.first == true)

        #expect(sut.isActivated)
        #expect(sut.shouldDismiss)
    }

    @Test("When right button is tapped, the password is valid and server is MDM managed, the activation succeeds")
    func activateWithValidPasswordAndServerManagedByAdmin() async throws {
        let safeManagerMock = MockSafeManager.deactivated
        safeManagerMock.mockTestServerReturn = .success((1000, 3))

        let sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: safeManagerMock,
            mdmSetup: .safeServerPreset
        )

        sut.onAppear()

        sut.passwordTextInput = "q1w2e3r4!@"
        sut.confirmationPasswordTextInput = "q1w2e3r4!@"
        sut.isDefaultServerSwitchedOn = true

        #expect(sut.isActivated == false)
        #expect(safeManagerMock.verifyActivateCalls.isEmpty)

        // Simulate Save
        await sut.rightButtonTapped()

        #expect(safeManagerMock.verifyActivateCalls.count == 1)
        #expect(safeManagerMock.verifyActivateCalls.first?.identity == "ECHOECHO")
        #expect(safeManagerMock.verifyActivateCalls.first?.safePassword == "q1w2e3r4!@")
        #expect(safeManagerMock.verifyActivateCalls.first?.customServer == "https://any-server.com")
        #expect(safeManagerMock.verifyActivateCalls.first?.serverUser == nil)
        #expect(safeManagerMock.verifyActivateCalls.first?.serverPassword == nil)
        #expect(safeManagerMock.verifyActivateCalls.first?.server == "https://any-server.com")
        #expect(safeManagerMock.verifyActivateCalls.first?.maxBackupBytes == 1000)
        #expect(safeManagerMock.verifyActivateCalls.first?.retentionDays == 3)

        #expect(sut.isActivated)
        #expect(sut.shouldDismiss)
    }

    @Test("When right button is tapped, the password is weak and server is MDM managed, the activation succeeds")
    func activateWithWeakPasswordAndServerManagedByAdmin() async throws {
        let safeManagerMock = MockSafeManager.deactivated
        safeManagerMock.mockTestServerReturn = .success((1000, 3))

        let sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: safeManagerMock,
            mdmSetup: .safeServerPreset
        )

        sut.onAppear()

        sut.passwordTextInput = "11111111" // password weak, only numbers
        sut.confirmationPasswordTextInput = "11111111"
        sut.isDefaultServerSwitchedOn = true

        #expect(sut.isActivated == false)
        #expect(safeManagerMock.verifyActivateCalls.isEmpty)

        // Simulate Save
        await sut.rightButtonTapped()

        // Simulate Confirm warning weak password
        await sut.warning?.action()

        #expect(safeManagerMock.verifyActivateCalls.count == 1)
        #expect(safeManagerMock.verifyActivateCalls.first?.identity == "ECHOECHO")
        #expect(safeManagerMock.verifyActivateCalls.first?.safePassword == "11111111")
        #expect(safeManagerMock.verifyActivateCalls.first?.customServer == "https://any-server.com")
        #expect(safeManagerMock.verifyActivateCalls.first?.serverUser == nil)
        #expect(safeManagerMock.verifyActivateCalls.first?.serverPassword == nil)
        #expect(safeManagerMock.verifyActivateCalls.first?.server == "https://any-server.com")
        #expect(safeManagerMock.verifyActivateCalls.first?.maxBackupBytes == 1000)
        #expect(safeManagerMock.verifyActivateCalls.first?.retentionDays == 3)

        #expect(sut.isActivated)
        #expect(sut.shouldDismiss)
    }

    @Test("When right button is tapped, the password is MDM managed and server is custom, the activation succeeds")
    func activateWithMDMPasswordAndCustomServer() async throws {
        let safeManagerMock = MockSafeManager.deactivated

        let sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: safeManagerMock,
            mdmSetup: .safePasswordPreset
        )

        sut.onAppear()

        sut.isDefaultServerSwitchedOn = false
        sut.serverURLInput = "https://custom-9.threema.ch"
        sut.serverUsernameInput = "johnsmith"
        sut.serverPasswordInput = "q1w2e3r4!@"

        #expect(sut.isActivated == false)
        #expect(safeManagerMock.verifyActivateCalls.isEmpty)

        // Simulate Save
        await sut.rightButtonTapped()

        #expect(safeManagerMock.verifyActivateCalls.count == 1)
        #expect(safeManagerMock.verifyActivateCalls.first?.identity == "ECHOECHO")
        #expect(safeManagerMock.verifyActivateCalls.first?.safePassword == "q1w2e3r4!@#")
        #expect(safeManagerMock.verifyActivateCalls.first?.customServer == "https://custom-9.threema.ch")
        #expect(safeManagerMock.verifyActivateCalls.first?.serverUser == "johnsmith")
        #expect(safeManagerMock.verifyActivateCalls.first?.serverPassword == "q1w2e3r4!@")
        #expect(safeManagerMock.verifyActivateCalls.first?.server == "https://custom-9.threema.ch")
        #expect(safeManagerMock.verifyActivateCalls.first?.maxBackupBytes == 1000)
        #expect(safeManagerMock.verifyActivateCalls.first?.retentionDays == 3)
        #expect(safeManagerMock.verifyStartBackupCalls.count == 1)
        #expect(safeManagerMock.verifyStartBackupCalls.first == true)
        #expect(sut.isActivated)
        #expect(sut.shouldDismiss)
    }

    @Test("When right button is tapped, the activation fails, an alert is shown")
    func activateFails() async throws {
        let safeManagerMock = MockSafeManager.deactivated

        struct ActivationError: Error, LocalizedError {
            var errorDescription: String? { "The activation failed for some reason" }
        }

        safeManagerMock.mockActivateReturn = .failure(ActivationError())

        let sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: safeManagerMock,
            mdmSetup: .mock
        )

        sut.onAppear()

        sut.passwordTextInput = "q1w2e3r4!@"
        sut.confirmationPasswordTextInput = "q1w2e3r4!@"
        sut.isDefaultServerSwitchedOn = true

        #expect(sut.isActivated == false)
        #expect(safeManagerMock.verifyActivateCalls.isEmpty)

        // Simulate Save
        await sut.rightButtonTapped()

        #expect(safeManagerMock.verifyActivateCalls.count == 1)
        #expect(safeManagerMock.verifyStartBackupCalls.isEmpty)

        #expect(sut.isActivated == false)
        #expect(sut.shouldDismiss == false)

        let expectedAlert = ThreemaSafePasswordViewModel.AlertData(
            title: "Error preparing Threema Safe backup",
            message: "The activation failed for some reason",
            dismissTitle: "OK"
        )
        #expect(sut.alert?.title == expectedAlert.title)
        #expect(sut.alert?.message == expectedAlert.message)
        #expect(sut.alert?.dismissTitle == expectedAlert.dismissTitle)
    }

    @Test("Change password is successful")
    func changePassword() async throws {
        let safeManagerMock = MockSafeManager.activated // Changing password flow
        safeManagerMock.mockActivateReturn = .success(())
        safeManagerMock.mockStartBackupReturn = .success(())

        let sut = ThreemaSafePasswordViewModel(
            appFlavor: .mock, myIdentityStore: .mock, safeConfigManager: .mock, safeManager: safeManagerMock,
            mdmSetup: .mock
        )

        var closureCalledCount = 0
        sut.onFinish = { closureCalledCount += 1 }

        sut.onAppear()

        sut.passwordTextInput = "q1w2e3r4!@#-new-password"
        sut.confirmationPasswordTextInput = "q1w2e3r4!@#-new-password"

        #expect(sut.isActivated == true)

        await sut.rightButtonTapped()

        #expect(safeManagerMock.verifyDeactivateCalls == 1)
        #expect(safeManagerMock.verifyActivateCalls.count == 1)
        #expect(safeManagerMock.verifyActivateCalls.first?.identity == "ECHOECHO")
        #expect(safeManagerMock.verifyActivateCalls.first?.safePassword == "q1w2e3r4!@#-new-password")
        #expect(safeManagerMock.verifyActivateCalls.first?.customServer == nil)
        #expect(safeManagerMock.verifyActivateCalls.first?.serverUser == nil)
        #expect(safeManagerMock.verifyActivateCalls.first?.serverPassword == nil)
        #expect(safeManagerMock.verifyActivateCalls.first?.server == nil)
        #expect(safeManagerMock.verifyStartBackupCalls.count == 1)
        #expect(safeManagerMock.verifyStartBackupCalls.first == true)
        #expect(closureCalledCount == 1)
    }
}
