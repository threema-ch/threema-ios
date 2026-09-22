import DataBackup
import FileUtilityTestHelper
import Testing

@testable import Threema

@Suite("Local Backup Confirm Settings Tests")
@MainActor
struct LocalBackupSettingsViewModelTests {

    @Test func `Screen resources are correctly set in the primary language`() {
        let sut = makeSUT()

        #expect(sut.cancelButtonTitle == "Cancel")
        #expect(sut.excludeMediaButtonTitle == "Exclude media")
        #expect(sut.freeUpSpaceButtonTitle == "Free up space")
        #expect(sut.includedMessagesSubtitle == "Text, captions, reactions & metadata")
        #expect(sut.includedMessagesTitle == "Messages")
        #expect(sut.includedSectionFooter == "These are always backup up.")
        #expect(sut.includedSectionHeader == "ALWAYS INCLUDED")
        #expect(sut.includeMediaSubtitle == "Photos, videos & audio")
        #expect(sut.includeMediaTitle == "Include media")
        #expect(sut.headerTitle == "Backup Settings")
        #expect(sut.headerDescription == "Choose what to include in your encrypted backup.")

        #expect(sut.mediaItems.count == 4)
        #expect(sut.mediaItems[0].iconName == "photo")
        #expect(sut.mediaItems[0].subtitle == "All photos sent & received")
        #expect(sut.mediaItems[0].title == "Photos")
        #expect(sut.mediaItems[1].iconName == "video.fill")
        #expect(sut.mediaItems[1].subtitle == "All videos shared in chats")
        #expect(sut.mediaItems[1].title == "Videos")
        #expect(sut.mediaItems[2].iconName == "document.fill")
        #expect(sut.mediaItems[2].subtitle == "PDFs, attachments & shared files")
        #expect(sut.mediaItems[2].title == "Documents and files")
        #expect(sut.mediaItems[3].iconName == "waveform.circle.fill")
        #expect(sut.mediaItems[3].subtitle == "Audio recordings from chats")
        #expect(sut.mediaItems[3].title == "Voice messages")

        #expect(
            sut.mediaSectionFooter == "Including media increases backup size but preserves the full chat experience."
        )
        #expect(sut.mediaSectionHeader == "MEDIA")
        #expect(sut.notEnoughStorageTitle == "Not enough storage")
        #expect(sut.recoveryKeyLabel == "Recovery Key")
        #expect(sut.recoveryKeySectionHeader == "ENCRYPTING WITH…")
        #expect(sut.startButtonTitle == "Start Backup")
        #expect(sut.stepLabel == "STEP 2 OF 3")
        #expect(sut.symbolName == "gearshape.fill")
        #expect(sut.whatsIncludedLabel == "WHAT’S INCLUDED")
    }

    // MARK: - Helpers

    private func makeSUT() -> LocalBackupSettingsViewModel {
        LocalBackupSettingsViewModel(manager: .mock)
    }
}
