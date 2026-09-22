import Testing

@testable import Threema

@Suite("Local Backup Learn More Tests")
@MainActor
struct LocalBackupLearnMoreViewModelTests {

    @Test func `Screen resources are correctly set in the primary language`() {
        let sut = LocalBackupLearnMoreViewModel()

        #expect(sut.iconImageName == "local.backup.learn.more.icon")
        #expect(sut.title == "Local Data Backup")

        let expectedContent = """
            Manually save your chats, messages, and media on your device for full control and privacy.
            Keep your data safe and restore it when switching devices or recovering from a reset.
            
            Backups are stored only on your device and cannot be restored if the device is lost or damaged.
            """
        #expect(sut.content == expectedContent)
    }
}
