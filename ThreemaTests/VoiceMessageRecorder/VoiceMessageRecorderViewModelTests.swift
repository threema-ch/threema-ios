import AudioSessionManagerTestHelper
import Foundation
import RemoteSecretProtocolTestHelper
import Testing
@testable import Threema
@testable import ThreemaFramework

/// Records with `VoiceMessageAudioRecorderMock` (real AAC files) and runs the production merge, export and draft
/// store. Serialized because the draft store and the temp dir are shared.
@MainActor
@Suite(.serialized)
struct VoiceMessageRecorderViewModelTests {

    private let testDatabase: TestDatabase
    private let conversation: ConversationEntity
    private let environment = VoiceMessageTestEnvironment()

    init() {
        AppGroup.setGroupID("group.ch.threema")
        // Also sets `FileUtility.shared`
        RemoteSecretProvider.setRemoteSecretManager(RemoteSecretManagerMock(isRemoteSecretEnabled: false))

        let testDatabase = TestDatabase()
        let conversation = testDatabase.preparer.save {
            let contact = testDatabase.preparer.createContact(
                publicKey: Data([1]),
                identity: "VOICEREC"
            )
            return testDatabase.preparer.createConversation { conversation in
                conversation.contact = contact
            }
        }
        self.testDatabase = testDatabase
        self.conversation = conversation
        MessageDraftStore.shared.deleteDraft(for: conversation)
    }

    // MARK: - Sending

    @Test("A single recording is sent completely")
    func singleRecordingIsSent() async throws {
        let fixture = try await makeFixture()
        defer { fixture.tearDown() }

        environment.record(2)
        try await fixture.send()

        try fixture.expectSent(seconds: 2)
    }

    @Test("Recording again after playing sends both parts")
    func recordingAgainAfterPlayingSendsBothParts() async throws {
        let fixture = try await makeFixture()
        defer { fixture.tearDown() }

        environment.record(2)
        try await fixture.stop()
        try await fixture.play()
        try await fixture.continueRecording()
        environment.record(1)
        try await fixture.send()

        try fixture.expectSent(seconds: 3)
    }

    @Test("A recording that never started is not sent as an empty message")
    func recordingThatNeverStartedIsNotSent() async throws {
        environment.isMicrophoneBusy = true
        let fixture = try await makeFixture(expectRecording: false)
        defer { fixture.tearDown() }

        environment.record(2)
        try await fixture.send()

        #expect(fixture.sent.isEmpty)
    }

    // MARK: - Drafts

    @Test("A draft saved while recording loads again and is sent completely")
    func draftSavedWhileRecordingIsSent() async throws {
        var fixture: Fixture? = try await makeFixture()
        environment.record(2)
        fixture?.model.saveVoiceMessageRecordingAsDraft()
        let draftURL = try await waitForDraft()
        fixture = nil

        let reopened = try await makeFixture(draft: draftURL, expectRecording: false)
        defer { reopened.tearDown() }
        try await reopened.send()

        try reopened.expectSent(seconds: 2)
    }

    @Test("Recording more on a loaded draft sends both parts")
    func recordingMoreOnLoadedDraftSendsBothParts() async throws {
        var fixture: Fixture? = try await makeFixture()
        environment.record(2)
        fixture?.model.saveVoiceMessageRecordingAsDraft()
        let draftURL = try await waitForDraft()
        fixture = nil

        let reopened = try await makeFixture(draft: draftURL, expectRecording: false)
        defer { reopened.tearDown() }
        try await reopened.continueRecording()
        environment.record(1)
        try await reopened.send()

        try reopened.expectSent(seconds: 3)
    }

    @Test("A recorder that stays open after its draft was saved still sends the recording")
    func recorderStaysUsableAfterDraftWasSaved() async throws {
        // What rotation did before (split view collapse/expand), and what opening the profile still does
        let fixture = try await makeFixture()
        defer { fixture.tearDown() }

        environment.record(2)
        fixture.model.saveVoiceMessageRecordingAsDraft()
        _ = try await waitForDraft()

        #expect(fixture.model.recordingState == .stopped)

        try await fixture.send()
        try fixture.expectSent(seconds: 2)
    }

    @Test("A recording made of several parts survives saving its draft")
    func multiPartRecordingSurvivesSavingDraft() async throws {
        let fixture = try await makeFixture()
        defer { fixture.tearDown() }

        environment.record(2)
        try await fixture.stop()
        try await fixture.play()
        try await fixture.continueRecording()
        environment.record(1)
        fixture.model.saveVoiceMessageRecordingAsDraft()
        _ = try await waitForDraft()

        try await fixture.send()
        try fixture.expectSent(seconds: 3)
    }

    @Test("Saving the same draft twice keeps it")
    func savingSameDraftTwiceKeepsIt() async throws {
        let fixture = try await makeFixture()
        defer { fixture.tearDown() }

        environment.record(2)
        fixture.model.saveVoiceMessageRecordingAsDraft()
        let firstDraftURL = try await waitForDraft()
        fixture.model.saveVoiceMessageRecordingAsDraft()
        let secondDraftURL = try await waitForDraft(otherThan: firstDraftURL)

        // `MessageDraftStore` deletes the file of the replaced draft on a background queue
        try await Task.sleep(for: .milliseconds(500))

        #expect(FileManager.default.fileExists(atPath: secondDraftURL.path))
        #expect(await abs(VoiceMessageTestAudio.duration(of: secondDraftURL) - 2) < Self.tolerance)
    }

    @Test("The temp files are removed when the chat is left while recording")
    func tempFilesAreRemovedWhenChatIsLeft() async throws {
        var fixture: Fixture? = try await makeFixture()
        environment.record(2)
        fixture?.model.saveVoiceMessageRecordingAsDraft()
        let draftURL = try await waitForDraft()
        fixture = nil

        let recorderURLs = environment.recorders.map(\.url)
        try await waitUntil { recorderURLs.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) } }
        #expect(FileManager.default.fileExists(atPath: draftURL.path))

        MessageDraftStore.shared.deleteDraft(for: conversation)
    }

    // MARK: - Microphone

    @Test("A busy microphone at start shows an error and closes the recorder")
    func busyMicrophoneAtStartShowsError() async throws {
        environment.isMicrophoneBusy = true
        var startFailed = false
        let fixture = try await makeFixture(expectRecording: false, onStartFailed: { startFailed = true })
        defer { fixture.tearDown() }

        try await waitUntil { fixture.presented.contains(NotificationPresenterType.recordingFailed.notificationText) }
        #expect(fixture.model.recordingState != .recording)
        #expect(startFailed)
    }

    @Test("A busy microphone when continuing shows an error and keeps the first part")
    func busyMicrophoneWhenContinuingKeepsFirstPart() async throws {
        let fixture = try await makeFixture()
        defer { fixture.tearDown() }

        environment.record(2)
        try await fixture.stop()
        environment.isMicrophoneBusy = true
        await fixture.model.continueRecording()

        #expect(fixture.presented.contains(NotificationPresenterType.recordingFailed.notificationText))
        #expect(fixture.model.recordingState != .recording)

        environment.record(1)
        environment.isMicrophoneBusy = false
        try await fixture.send()
        try fixture.expectSent(seconds: 2)
    }

    // MARK: - Helpers

    /// AAC encoder priming and frame alignment
    fileprivate static let tolerance: TimeInterval = 0.1

    private func makeFixture(
        draft: URL? = nil,
        expectRecording: Bool = true,
        onStartFailed: (() -> Void)? = nil
    ) async throws -> Fixture {
        let fixture = Fixture(conversation: conversation)
        var dependencies = VoiceMessageRecorderDependencies()
        dependencies.makeRecorder = { [environment] url, _ in
            environment.makeRecorder(url: url)
        }
        dependencies.sendBlobMessage = { [weak fixture] item, _ in
            // Like `MessageSender`: a missing file is an error, an existing one is sent as it is
            guard item.getData() != nil else {
                throw MessageSenderError.noData
            }
            let duration = await VoiceMessageTestAudio.duration(of: item.url)
            fixture?.sent.append(duration)
        }
        dependencies.presentNotification = { [weak fixture] type in
            fixture?.presented.append(type.notificationText)
        }

        fixture.model = try VoiceMessageRecorderViewModel(
            conversation: conversation,
            draftAudioURL: draft,
            onStartFailed: onStartFailed,
            audioSessionManager: MockAudioSessionManager(),
            dependencies: dependencies
        )

        if expectRecording {
            try await waitUntil { fixture.model.recordingState == .recording }
        }
        else if draft != nil {
            try await waitUntil { fixture.model.recordingState == .stopped }
        }
        else {
            try await waitUntil { !fixture.presented.isEmpty }
        }
        return fixture
    }

    private func waitForDraft(otherThan previous: URL? = nil) async throws -> URL {
        var draftURL: URL?
        try await waitUntil {
            guard case let .audio(url) = MessageDraftStore.shared.loadDraft(for: conversation), url != previous else {
                return false
            }
            draftURL = url
            return true
        }
        return try #require(draftURL)
    }
}

// MARK: - Fixture

@MainActor
private final class Fixture {
    let conversation: ConversationEntity
    var model: VoiceMessageRecorderViewModel!
    /// Duration of every sent voice message
    var sent: [TimeInterval] = []
    var presented: [String] = []

    init(conversation: ConversationEntity) {
        self.conversation = conversation
    }

    func stop() async throws {
        await model.stopRecording()
    }

    func play() async throws {
        model.play()
        // Playing merges the parts first. Whether the simulator can play does not matter.
        try await waitUntil {
            self.model.recordingState == .playing
                || self.presented.contains(NotificationPresenterType.recordingPlayingFailed.notificationText)
        }
    }

    func continueRecording() async throws {
        await model.continueRecording()
        try await waitUntil { self.model.recordingState == .recording }
    }

    func send() async throws {
        var done = false
        let sendingError = NotificationPresenterType.sendingError.notificationText
        model.sendRecording { done = true }
        try await waitUntil { done || self.presented.contains(sendingError) }
    }

    func expectSent(seconds: TimeInterval, sourceLocation: SourceLocation = #_sourceLocation) throws {
        #expect(
            !presented.contains(NotificationPresenterType.sendingError.notificationText),
            sourceLocation: sourceLocation
        )
        let duration = try #require(sent.only, "sent: \(sent)", sourceLocation: sourceLocation)
        #expect(
            abs(duration - seconds) < VoiceMessageRecorderViewModelTests.tolerance,
            "sent \(duration) s, expected \(seconds) s",
            sourceLocation: sourceLocation
        )
    }

    func tearDown() {
        model.willDismissView()
        MessageDraftStore.shared.deleteDraft(for: conversation)
    }
}

// MARK: - Waiting

@MainActor
private func waitUntil(
    timeout: Duration = .seconds(10),
    sourceLocation: SourceLocation = #_sourceLocation,
    _ condition: () -> Bool
) async throws {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
        guard ContinuousClock.now < deadline else {
            Issue.record("Timed out waiting for condition", sourceLocation: sourceLocation)
            return
        }
        try await Task.sleep(for: .milliseconds(20))
    }
}

extension Array {
    fileprivate var only: Element? {
        count == 1 ? first : nil
    }
}
