import FileUtility
import Foundation
import RemoteSecretProtocolTestHelper
import Testing
@testable import Threema
@testable import ThreemaFramework

@Suite(.serialized)
struct AudioMediaManagerTests {

    init() {
        AppGroup.setGroupID("group.ch.threema")
        // Also sets `FileUtility.shared`
        RemoteSecretProvider.setRemoteSecretManager(RemoteSecretManagerMock(isRemoteSecretEnabled: false))
    }

    @Test("Recording URLs created within the same second are unique")
    func recordingURLsAreUnique() {
        let urls = (0..<100).map { _ in AudioMediaManager.newRecordingAudioURL() }

        #expect(Set(urls).count == urls.count)
    }

    @Test("Copying to the documents dir keeps the source and always creates a new file")
    func copyToDocumentsDirCreatesNewFile() async throws {
        let source = AudioMediaManager.newRecordingAudioURL()
        try VoiceMessageTestAudio.writeSilence(1, to: source)
        defer { FileUtility.shared.deleteIfExists(at: source) }

        let first = try AudioMediaManager.copyToDocumentsDir(from: source)
        defer { FileUtility.shared.deleteIfExists(at: first) }
        let second = try AudioMediaManager.copyToDocumentsDir(from: source)
        defer { FileUtility.shared.deleteIfExists(at: second) }

        #expect(first != second)
        #expect(FileManager.default.fileExists(atPath: source.path))
        #expect(await abs(VoiceMessageTestAudio.duration(of: first) - 1) < 0.1)
        #expect(await abs(VoiceMessageTestAudio.duration(of: second) - 1) < 0.1)
    }

    @Test("Concatenating writes both parts to the new file and removes the parts")
    func concatenateMergesParts() async throws {
        let parts = [AudioMediaManager.newRecordingAudioURL(), AudioMediaManager.newRecordingAudioURL()]
        try VoiceMessageTestAudio.writeSilence(2, to: parts[0])
        try VoiceMessageTestAudio.writeSilence(1, to: parts[1])
        let combined = AudioMediaManager.newRecordingAudioURL()
        defer {
            for url in parts + [combined] {
                FileUtility.shared.deleteIfExists(at: url)
            }
        }

        _ = try await AudioMediaManager.concatenateRecordingsAndSave(combine: parts, to: combined)

        #expect(await abs(VoiceMessageTestAudio.duration(of: combined) - 3) < 0.1)
        #expect(parts.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
    }
}
