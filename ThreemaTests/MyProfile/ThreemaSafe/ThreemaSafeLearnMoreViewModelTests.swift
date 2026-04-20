import Testing

@testable import Threema

@MainActor
struct ThreemaSafeLearnMoreViewModelTests {

    @Test("Resources in the screen are correct")
    func resources() {
        let sut = ThreemaSafeLearnMoreViewModel(appFlavor: .mock)

        #expect(sut.headline == "About Threema Safe")
        #expect(sut.body == """
            All you need to chat is stored only on your device. You don’t have an account with us, and we cannot help \
            you out if you lose your phone or accidentally delete your data.

            Threema Safe regularly creates automatic backups of all the important data, including your keys, your \
            contact list, and your group memberships, anonymously on a secure server of your choice.
            """)
        #expect(sut.doneButtonTitle == "Done")
    }
}
