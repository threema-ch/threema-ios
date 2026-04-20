import Testing

@testable import Threema

@MainActor
struct ThreemaSafeIntroViewModelTests {

    @Test("Resources in the screen are correct")
    func resources() {
        let sut = ThreemaSafeIntroViewModel(appFlavor: .mock, userSettings: .mock)

        #expect(sut.title == "Introducing Threema Safe")
        #expect(sut.description == "Never lose your Threema ID, contacts, groups, and settings again!")
        #expect(
            sut.explain == """
                Threema Safe regularly creates an encrypted, anonymous backup of the most important data and stores it \
                on the Threema server or another server of your choice.
                """
        )
        #expect(sut.enableButtonTitle == "Enable now")
        #expect(sut.cancelButtonTitle == "Don’t show again")

        #expect(
            sut.threemaSafeIcon == ImageResource(
                name: "ThreemaSafeIntro",
                bundle: Bundle(for: ThreemaSafeIntroViewModel.self)
            )
        )
    }

    @Test("OnAppear will set userSettings safeIntroShown to true")
    func onAppear() async throws {
        let mock = UserSettingsMock()
        mock.safeIntroShown = false

        let sut = ThreemaSafeIntroViewModel(appFlavor: .mock, userSettings: mock)

        #expect(mock.safeIntroShown == false)
        sut.onAppear()

        #expect(mock.safeIntroShown == true)
    }

    @Test("When user taps cancel button screen is dismissed and onCancel is called")
    func cancelButtonTapped() async throws {
        let sut = ThreemaSafeIntroViewModel(appFlavor: .mock, userSettings: .mock)

        var onCancelWasCalled = false
        var onConfirmWasCalled = false

        sut.onCancel = { onCancelWasCalled = true }
        sut.onConfirm = { onConfirmWasCalled = true }

        #expect(sut.shouldDismiss == false)

        sut.cancelButtonTapped()

        #expect(sut.shouldDismiss == true)
        #expect(onCancelWasCalled == true)
        #expect(onConfirmWasCalled == false)
    }

    @Test("When user taps done button screen is dismissed and onConfirm is called")
    func doneButtonTapped() async throws {
        let sut = ThreemaSafeIntroViewModel(appFlavor: .mock, userSettings: .mock)

        var onCancelWasCalled = false
        var onConfirmWasCalled = false

        sut.onCancel = { onCancelWasCalled = true }
        sut.onConfirm = { onConfirmWasCalled = true }

        #expect(sut.shouldDismiss == false)

        sut.confirmationButtonTapped()

        #expect(sut.shouldDismiss == true)
        #expect(onCancelWasCalled == false)
        #expect(onConfirmWasCalled == true)
    }
}
