import Combine
import Testing

@testable import Threema

@MainActor
struct BackupsViewModelTests {

    @Test("When Safe is enabled and Activated, the menu item is enabled and status on")
    func threemaSafeEnabledAndActivated() async throws {
        let sut = BackupsViewModel(appFlavor: .mock, mdmSetup: .mock, safeManager: .activated)

        sut.onAppear()

        #expect(sut.screenTitle == "Backups")
        #expect(sut.safeButtonTitle == "Threema Safe")
        #expect(sut.safeActivationStatusLabel == "On")
        #expect(sut.idExportButtonTitle == "ID Export")

        #expect(sut.safeIsDisabled == false)
        #expect(sut.isIDExportDisabled == false)
        #expect(
            sut.safeSectionFooter == "Automatically saves your ID and important settings (chats not included)."
        )
        #expect(sut.idExportSectionFooter == "Restore only your ID.")
    }

    @Test("When Safe is enabled and Deactivated, the menu item is enabled and status off")
    func threemaSafeEnabledAndDeactivated() async throws {
        let sut = BackupsViewModel(appFlavor: .mock, mdmSetup: .mock, safeManager: .deactivated)

        sut.onAppear()

        #expect(sut.screenTitle == "Backups")
        #expect(sut.safeButtonTitle == "Threema Safe")
        #expect(sut.safeActivationStatusLabel == "Off")
        #expect(sut.idExportButtonTitle == "ID Export")

        #expect(sut.safeIsDisabled == false)
        #expect(sut.isIDExportDisabled == false)
        #expect(
            sut.safeSectionFooter == "Automatically saves your ID and important settings (chats not included)."
        )
        #expect(sut.idExportSectionFooter == "Restore only your ID.")
    }

    @Test("When Safe is disabled the menu item is disabled and the footer text is updated")
    func threemaSafeDisabled() async throws {
        let sut = BackupsViewModel(appFlavor: .mock, mdmSetup: .safeBackupDisabled, safeManager: .deactivated)

        sut.onAppear()

        #expect(sut.safeIsDisabled == true)
        #expect(sut.safeSectionFooter == "Some features have been disabled by your administrator.")
    }

    @Test("When ID Export is disabled the menu item is disabled and the footer text is updated")
    func idExportDisabled() async throws {
        let sut = BackupsViewModel(appFlavor: .mock, mdmSetup: .idExportDisabled, safeManager: .activated)

        sut.onAppear()

        #expect(sut.isIDExportDisabled == true)
        #expect(sut.idExportSectionFooter == "Some features have been disabled by your administrator.")
    }

    @Test("When screen appears, the activation status is updated")
    func onAppearUpdates() async throws {
        let mock = MockSafeManager()
        mock.mockIsActivated = false

        let sut = BackupsViewModel(appFlavor: .mock, mdmSetup: .idExportDisabled, safeManager: mock)

        sut.onAppear()

        #expect(sut.safeActivationStatusLabel == "Off")

        mock.mockIsActivated = true
        sut.onAppear()

        #expect(sut.safeActivationStatusLabel == "On")
    }

    @Test("Route change will emit the chance in the route publisher")
    func routeChange() async throws {
        var cancellables = Set<AnyCancellable>()
        let sut = BackupsViewModel(appFlavor: .mock, mdmSetup: .mock, safeManager: .activated)

        sut.onAppear()

        await confirmation { confirm in
            sut.routePublisher
                .sink { value in
                    #expect(value == .threemaSafe)
                    confirm()
                }
                .store(in: &cancellables)

            sut.safeButtonTapped()
        }

        cancellables.removeAll()

        await confirmation { confirm in
            sut.routePublisher
                .sink { value in
                    #expect(value == .idExport)
                    confirm()
                }
                .store(in: &cancellables)

            sut.idExportButtonTapped()
        }
    }
}
