//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import AsyncAlgorithms
import AVFoundation
import CocoaLumberjackSwift
import Combine
import Foundation
import ThreemaFramework

// MARK: - PassthroughSubject + Sendable

extension PassthroughSubject: @unchecked Sendable where Output: Sendable { }

// MARK: - Notification + Sendable

extension Notification: @unchecked Sendable { }

actor VoiceMessageRecorderActor: VoiceMessageManagerProtocolBase {
    typealias DraftStore = MessageDraftStore
    typealias MediaManager = AudioMediaManager<FileUtility>
        
    // MARK: - Properties
    
    private(set) var tmpRecorderFile: URL
    private(set) var audioSessionManager: AudioSessionManagerProtocol
    
    private var runningInBackground = false
    private var recordingSessions: [URL] = []
    
    private var eventContinuation: AsyncStream<Event>.Continuation?
    private var eventStream: AsyncStream<Event>?

    @MainActor private var currentRecordingTime = 0.0
    @MainActor private var displayLink: CADisplayLink?
    
    private nonisolated(unsafe) var player: AVAudioPlayer?
    private nonisolated(unsafe) var recorder: AVAudioRecorder?
    private nonisolated(unsafe) var messageSender: MessageSenderProtocol
    
    private lazy var adapter: DelegateAdapter = createDelegationAdapter()
    private lazy var recordedAudioURL = MediaManager.tmpAudioURL(with: Configuration.recordFileName)
    
    nonisolated let recordingStateSubject: PassthroughSubject<RecordingState, Never> = .init()
    nonisolated var recordingStates: AnyPublisher<RecordingState, Never> {
        recordingStateSubject.receive(on: RunLoop.main).eraseToAnyPublisher()
    }
    
    nonisolated(unsafe) weak var delegate: VoiceMessageAudioRecorderDelegate?
    
    var interrupted = false
    var isPlaying: Bool { player?.isPlaying ?? false }
    var isRecording: Bool { recorder?.isRecording ?? false }
    var canRecord: Bool { audioSessionManager.isInputAvailable && recordedLength < Configuration.recordDuration.max }
    var lastAveragePower: Float { recorder?.averagePower(forChannel: 0) ?? 0.0 }
    var isContinuingRecording: Bool { tmpAudioDuration.isZero && recorder == nil }
    var sufficientLength: Bool { recordedLength > Configuration.recordDuration.min }
    var recordedLength: TimeInterval { (recorder?.currentTime ?? 0.0) + tmpAudioDuration }
    var tmpAudioDuration: TimeInterval { recordingSessions.reduce(0) { $0 + AVURLAsset(url: $1).duration.seconds } }
 
    init(
        delegate: VoiceMessageAudioRecorderDelegate?,
        audioSessionManager: AudioSessionManagerProtocol,
        messageSender: MessageSenderProtocol = BusinessInjector().messageSender
    ) {
        self.audioSessionManager = audioSessionManager
        self.messageSender = messageSender
        self.tmpRecorderFile = MediaManager.tmpAudioURL(with: Configuration.recordTmpFileName)
        self.delegate = delegate

        Task { await registerEvents() }
    }
    
    init() {
        self.init(
            delegate: nil,
            audioSessionManager: AudioSessionManager()
        )
    }
    
    deinit {
        VoiceMessageRecorderActor.resetIdleAndProximity()
        recorder?.stop()
        player?.stop()
        recorder = nil
        player = nil
        delegate = nil
        MediaManager.cleanupFiles(recordingSessions + [tmpRecorderFile, recordedAudioURL])
    }
    
    // MARK: - Public Functions
    
    func sendFile(for conversation: Conversation) async {
        recordingStateSubject.send(.none)
        player?.stop()
        await stop()
        do {
            try MediaManager.copy(source: tmpRecorderFile, destination: recordedAudioURL)
            DDLogVerbose("Sending VoiceMessage")
            try await sendItem(for: conversation, with: recordedAudioURL)
            await MainActor.run {
                DraftStore.shared.deleteDraft(for: conversation)
            }

            eventContinuation?.finish()
        }
        catch {
            delegate?.handleError(error)
        }
    }
}

// MARK: - VoiceMessageRecorderActor + AudioRecorderProtocol

extension VoiceMessageRecorderActor {
    func record() {
        recordingStateSubject.send(.recordingStarting)
        VoiceMessageRecorderActor.idleTimer.disable()

        if isContinuingRecording {
            audioSessionManager.setupAudioSession(isEarpiece: false)
        }
        
        do {
            try addRecording()
        }
        catch {
            delegate?.handleError(error)
        }
    }
    
    func stop() async {
        guard isRecording else {
            DDLogInfo("Can't stop recording while not recording")
            return
        }
        
        recordingStateSubject.send(.recordingStopping)

        if recordedLength >= Configuration.recordDuration.max {
            NotificationPresenterWrapper.shared.present(type: .recordingTooLong)
        }
        
        do {
            try await MainActor.run {
                recorder?.stop()
                recorder = nil
                try AVAudioSession.sharedInstance().setActive(false)
            }
            
            try await MediaManager.concatenateRecordingsAndSave(
                combine: recordingSessions,
                to: tmpRecorderFile
            )
            
            audioSessionManager.setupAudioSessionForPlayback()
            await stopTimer()
        }
        catch {
            delegate?.handleError(error)
        }
        recordingStateSubject.send(.stopped)
        VoiceMessageRecorderActor.resetIdleAndProximity()
        audioSessionManager.adaptToProximityState(isPlaying: isPlaying)
    }
    
    func willDismissView() async {
        eventContinuation?.finish()
        await stopTimer()
    }
}

// MARK: - AudioPlayerProtocol

extension VoiceMessageRecorderActor: AudioPlayerProtocol {
    /// Starts playing the recorded audio file.
    func play() async {
        recordingStateSubject.send(.playing)
        try? prepareAudioPlayBack()
        await start(isRecording: false)
        player?.play()
        VoiceMessageRecorderActor.idleTimer.disable()
        VoiceMessageRecorderActor.proximityMonitoring.activate()
    }
    
    /// Stops playing the recorded audio file.
    func pause() {
        recordingStateSubject.send(.paused)
        player?.pause()
        VoiceMessageRecorderActor.resetIdleAndProximity()
    }
    
    func playbackDidSeekTo(progress: Double) {
        recordingStateSubject.send(.paused)
        let timestamp = progress * tmpAudioDuration
        
        defer {
            VoiceMessageRecorderActor.idleTimer.enable()
            Task { await playbackStatusDidUpdate() }
        }
        
        guard let player else {
            try? prepareAudioPlayBack()
            self.player?.prepareToPlay()
            self.player?.currentTime = timestamp
            return
        }
        
        if isPlaying {
            player.pause()
        }
        
        self.player?.currentTime = timestamp
    }
}

// MARK: - AudioRecorderSessionManager

extension VoiceMessageRecorderActor: AudioRecorderSessionManager {
    func load(_ audioFile: URL? = nil) async {
        guard let audioFile else {
            return record()
        }
        
        // TODO: IOS-4503:  in order to load the audio file properly, we need to create the same state when we stop a recording
        // the `recordingSessions` are used to combine the parts into `tmpRecorderFile` and are used for the duration
        // computation among other things
        recordingSessions.append(audioFile)
        // this makes sure the `tmpRecorderFile` is set with the `recordingSessions` contents
        try? await MediaManager.concatenateRecordingsAndSave(
            combine: recordingSessions,
            to: tmpRecorderFile
        )

        continueLoadedSession()
        await delegate?.didUpdatePlayProgress(duration: tmpAudioDuration)
    }
        
    func savedSession(_ shouldMove: Bool = true) async throws -> SessionState {
        // only save session if we left the chat not the app
        guard !runningInBackground else {
            return .background
        }
        
        await stop()
        return try .closed(
            audioFile: shouldMove ? MediaManager.moveToPersistentDir(from: tmpRecorderFile) : tmpRecorderFile
        )
    }
}

// MARK: - VoiceMessageRecorderActor + Timer

extension VoiceMessageRecorderActor {
    @MainActor func stopTimer() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @MainActor private func start(isRecording: Bool) {
        let block = isRecording ? recordingStatusDidUpdate : playbackStatusDidUpdate
        stopTimer()
        
        displayLink = .init {
            block()
        }
        displayLink?.preferredFrameRateRange = .init(minimum: 60, maximum: 120, preferred: 120)
        displayLink?.add(to: .current, forMode: .default)
    }
    
    @MainActor private func recordingStatusDidUpdate() {
        guard let recorder, recorder.isRecording else {
            return
        }
        // we need to run this background task inside a `@MainActor` func so we avoid stutters of the waveform
        // calling from nonisolated into background or any other combination results in tiny stutters of the waveform.
        Task(priority: .background) {
            let progress = await fmax(0, fmin(1, recordedLength / Configuration.recordDuration.max))
            await delegate?.didUpdateRecordProgress(lastAveragePower: 1 - pow(10, lastAveragePower / 30), progress)
            recorder.updateMeters()
            
            if progress >= 1.0 {
                await stop()
            }
        }
    }
    
    @MainActor private func playbackStatusDidUpdate() {
        guard let player, let delegate else {
            return
        }

        Task(priority: .background) {
            let currentPlayTime = player.currentTime / player.duration
            let progress = fmax(0, fmin(1, currentPlayTime))
            await delegate.didUpdatePlayProgress(duration: tmpAudioDuration * progress)
        }
    }
}

// MARK: - Internal Helpers

extension VoiceMessageRecorderActor {
    private func addRecording() throws {
        guard !isRecording else {
            throw VoiceMessageError.recordingCancelled
        }
        
        switch audioSessionManager.setupForRecording() {
        case .success:
            VoiceMessageRecorderActor.proximityMonitoring.activate()
            player?.stop()
            player = nil
            recorder = try AVAudioRecorder(
                url: createNewRecordingSession(),
                settings: Configuration.recordSettings
            ).then {
                $0.isMeteringEnabled = true
                $0.delegate = adapter
                $0.record()
                recordingStateSubject.send(.recording)
            }
            
            Task { await start(isRecording: true) }
            audioSessionManager.adaptToProximityState(isPlaying: isPlaying)
        case let .failure(error):
            throw error
        }
    }
    
    /// Create new player instance with the current recording file.
    private func prepareAudioPlayBack() throws {
        guard !isRecording, player == nil else {
            DDLogInfo("Can't start playback while recording")
            return
        }
        
        switch audioSessionManager.setupAudioSessionForPlayback() {
        case .success:
            player = try AVAudioPlayer(contentsOf: tmpRecorderFile)
            player?.delegate = adapter
        case let .failure(error):
            throw error
        }
    }
    
    private nonisolated func sendItem(for conversation: Conversation, with url: URL) async throws {
        guard let item = URLSenderItem(
            url: url,
            type: UTType.audio.identifier,
            renderType: 1,
            sendAsFile: true
        ) else {
            DDLogError("Error creating SenderItem for conversation: \(conversation.description)")
            throw VoiceMessageError.fileOperationFailed
        }
        
        try await messageSender.sendBlobMessage(
            for: item,
            in: conversation.objectID,
            correlationID: nil,
            webRequestID: nil
        )
    }
    
    private func continueLoadedSession() {
        recordingStateSubject.send(.stopped)
        try? prepareAudioPlayBack()
        VoiceMessageRecorderActor.idleTimer.enable()
        VoiceMessageRecorderActor.proximityMonitoring.activate()
    }

    private func createDelegationAdapter() -> DelegateAdapter {
        .init { [weak self] in
            guard let self else {
                return
            }
            await didFinishPlayback()
        } didFinishRecording: { [weak self] in
            guard let self else {
                return
            }
            await didFinishRecording()
        }
    }
    
    private func createNewRecordingSession() -> URL {
        let url = MediaManager
            .tmpAudioURL(with: "\(Configuration.recordTmpFileName)_\(recordingSessions.count + 1)")
        recordingSessions.append(url)
        DDLogInfo("New recording session with URL: \(url)")
        return url
    }
}

// MARK: - VoiceMessageRecorderActor + Notifications

extension VoiceMessageRecorderActor {
    enum Event {
        case interruption(AVAudioSession.InterruptionType?)
        case didEnterBackground
        case willEnterForeground
        case proximityStateDidChange
    }

    private func registerEvents() async {
        eventStream = AsyncStream<Event> { continuation in
            self.eventContinuation = continuation
            let interruption = NotificationCenter.default
                .notifications(named: AVAudioSession.interruptionNotification)
                .compactMap { ($0.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) }
                .map { Event.interruption(AVAudioSession.InterruptionType(rawValue: $0)) }
            Task {
                let foreground = await NotificationCenter.default
                    .notifications(named: UIApplication.willEnterForegroundNotification)
                    .map { _ in Event.willEnterForeground }
                let background = await NotificationCenter.default
                    .notifications(named: UIApplication.didEnterBackgroundNotification)
                    .map { _ in Event.didEnterBackground }
                let proximityChange = await NotificationCenter.default
                    .notifications(named: UIKit.UIDevice.proximityStateDidChangeNotification)
                    .map { _ in Event.proximityStateDidChange }
                for await event in merge(interruption, foreground, merge(background, proximityChange)) {
                    continuation.yield(event)
                }
            }
        }

        guard let eventStream else {
            return
        }
        
        for await event in eventStream {
            switch event {
            case let .interruption(type):
                switch type {
                case .began:
                    await stop()
                case .ended:
                    record()
                case .none:
                    break
                @unknown default:
                    break
                }
            case .didEnterBackground:
                runningInBackground = true
            case .willEnterForeground:
                if interrupted {
                    interrupted = false
                    record()
                }

                runningInBackground = false
            case .proximityStateDidChange:
                guard let output = audioSessionManager.currentRoute.outputs.first,
                      isPlaying, [.builtInSpeaker, .builtInReceiver].contains(output.portType) else {
                    return
                }

                audioSessionManager.adaptToProximityState(isPlaying: isPlaying)
            }
        }
    }
}
