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

import AVFoundation
import CocoaLumberjackSwift
import Combine
import Foundation
import ThreemaFramework

final class VoiceMessageAudioRecorder: NSObject, VoiceMessageAudioRecorderProtocol, @unchecked Sendable {
    typealias DraftStore = MessageDraftStore
    typealias MediaManager = AudioMediaManager<FileUtility>
        
    // MARK: - Properties
    
    weak var delegate: VoiceMessageAudioRecorderDelegate?
    
    var interrupted = false
    
    private(set) var audioSessionManager: AudioSessionManagerProtocol
    
    private var runningInBackground = false
    
    private var timer: Timer?
    private var currentRecordingTime = 0.0
    
    // keep track of all the parts of one recording
    private var recordingSessions: [URL] = []
    
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    
    private var cancellables = Set<AnyCancellable>()
    
    // Finished recording URL
    private lazy var recordedAudioURL = MediaManager.tmpAudioURL(with: Configuration.recordFileName)
    // Temp URL for the composition of audio recording sessions
    private(set) var tmpRecorderFile: URL
    
    private let dispatchQueue = DispatchQueue(label: "ch.threema.voiceMessageManager", qos: .userInitiated)
    
    private let recordingStateSubject: PassthroughSubject<RecordingState, Never> = .init()
    var recordingStates: AnyPublisher<RecordingState, Never> {
        recordingStateSubject
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Computed Properties
    
    var canRecord: Bool { audioSessionManager.isInputAvailable }
    var isRecording: Bool { recorder?.isRecording ?? false }
    var isPlaying: Bool { player?.isPlaying ?? false }
    var lastAveragePower: Float { recorder?.averagePower(forChannel: 0) ?? 0.0 }
    var tmpAudioDuration: TimeInterval { recordingSessions.reduce(0) { $0 + AVURLAsset(url: $1).duration.seconds } }
    var sufficientLength: Bool { recordedLength > Configuration.recordDuration.min }
    var recordedLength: TimeInterval { (recorder?.currentTime ?? 0.0) + tmpAudioDuration }
    var isContinuingRecording: Bool { tmpAudioDuration.isZero && recorder == nil }
    
    private var newRecordingSessionURL: URL {
        let url = MediaManager
            .tmpAudioURL(with: "\(Configuration.recordTmpFileName)_\(recordingSessions.count + 1)")
        recordingSessions.append(url)
        DDLogInfo("New recording session with URL: \(url)")
        return url
    }
    
    override convenience init() {
        self.init(
            delegate: nil,
            audioSessionManager: AudioSessionManager()
        )
    }

    // MARK: - Init
    
    /// Manage recording, playback and sending of audio files.
    /// - Parameters:
    ///   - delegate: The delegate for the voice message recorder.
    ///   - audioMediaManager: File management of the audio files.
    init(
        delegate: VoiceMessageAudioRecorderDelegate?,
        audioSessionManager: AudioSessionManagerProtocol
    ) {
        self.audioSessionManager = audioSessionManager
        self.tmpRecorderFile = MediaManager.tmpAudioURL(with: Configuration.recordTmpFileName)
        super.init()
        self.delegate = delegate
        registerNotificationObservers()
        proximityMonitoring.activate()
    }

    deinit {
        detachAudioRecorder()
        MediaManager.cleanupFiles(recordingSessions + [tmpRecorderFile])
    }
    
    // MARK: - Public Functions
    
    /// Sends the recorded audio file to a specified conversation.
    /// - Parameter conversation: The conversation where the audio file will be sent.
    @Sendable
    func sendFile(for conversation: Conversation) async {
        recordingStateSubject.send(.none)
        
        await stop()
        
        switch MediaManager.copy(
            source: tmpRecorderFile,
            destination: recordedAudioURL
        ) {
        case .success():
            DDLogVerbose("Sending AudioFile")
            guard let item = URLSenderItem(
                url: recordedAudioURL,
                type: UTType.audio.identifier,
                renderType: 1,
                sendAsFile: true
            ) else {
                DDLogError("Error creating SenderItem for conversation: \(conversation.description)")
                return
            }
            do {
                try await BusinessInjector().messageSender.sendBlobMessage(
                    for: item,
                    in: conversation.objectID,
                    correlationID: nil,
                    webRequestID: nil
                )
            }
            catch let error as LocalizedError {
                delegate?.handleError(error)
            }
            catch {
                DDLogError("\(error.localizedDescription)")
            }
            
            await MainActor.run {
                DraftStore.shared.deleteDraft(for: conversation)
            }
        case let .failure(error):
            delegate?.handleError(error)
        }
    }
    
    // MARK: - Playback
    
    /// Starts playing the recorded audio file.
    func play() {
        recordingStateSubject.send(.playing)
        try? prepareAudioPlayBack()
        prepareTimer(false)
        player?.play()
        idleTimer.disable()
        proximityMonitoring.activate()
    }
    
    /// Stops playing the recorded audio file.
    func pause() {
        recordingStateSubject.send(.paused)
        player?.pause()
        idleTimer.enable()
        proximityMonitoring.deactivate()
    }
    
    /// Stops playing the recorded audio file and sets the current time based on the given progress.
    func playbackDidSeekTo(progress: Double) {
        recordingStateSubject.send(.paused)
        let timestamp = progress * tmpAudioDuration
        
        defer {
            idleTimer.enable()
            playbackStatusDidUpdate()
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
    
    // MARK: - Recording
    
    /// Starts recording audio, will automatically append new recordings to the current one.
    func record() async {
        recordingStateSubject.send(.recordingStarting)
        idleTimer.disable()
        await withCheckedContinuation { continuation in
            if isContinuingRecording {
                audioSessionManager.setupAudioSession(isEarpiece: false)
            }
            
            self.recordingStateSubject.send(.recording)
            addRecording { [weak self] result in
                if case let .failure(error) = result, let self {
                    delegate?.handleError(error)
                }
                continuation.resume()
            }
        }
    }
    
    /// Stops recording audio and saves the recorded file.
    func stop() async {
        recordingStateSubject.send(.recordingStopping)
        idleTimer.enable()
        guard isRecording else {
            DDLogInfo("Can't stop recording while not recording")
            return
        }
        
        do {
            // We do this to avoid a crash caused by starting a recording in another App, using the audioSessionManager
            // Instance does not work here
            recorder?.stop()
            try AVAudioSession.sharedInstance().setActive(false)
            
            switch await MediaManager.concatenateRecordingsAndSave(
                combine: recordingSessions,
                to: tmpRecorderFile
            ) {
            case .success:
                adaptToProximityState()
                resetIdleAndProximity()
                
                audioSessionManager.setupAudioSessionForPlayback()
                await MainActor.run {
                    stopTimer()
                }
                recordingStateSubject.send(.stopped)
                
            case let .failure(error):
                delegate?.handleError(error)
                recordingStateSubject.send(.stopped)
            }
        }
        catch let error as LocalizedError {
            delegate?.handleError(error)
        }
        catch {
            DDLogError("\(error.localizedDescription)")
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
    }
    
    func load(_ audioFile: URL? = nil) async {
        guard let audioFile else {
            return await record()
        }
        
        // TODO: IOS-4503:  in order to load the audio file properly, we need to create the same state when we stop a recording
        // the `recordingSessions` are used to combine the parts into `tmpRecorderFile` and are used for the duration
        // computation among other things
        recordingSessions.append(audioFile)
        // this makes sure the `tmpRecorderFile` is set with the `recordingSessions` contents
        _ = await MediaManager.concatenateRecordingsAndSave(
            combine: recordingSessions,
            to: tmpRecorderFile
        )

        await MainActor.run {
            continueLoadedSession()
            delegate?.didUpdatePlayProgress(with: self, 1.0)
        }
    }
    
    func savedSession(_ shouldMove: Bool = true) async throws -> SessionState {
        // only save session if we left the chat not the app
        guard !runningInBackground else {
            return .background
        }
        
        await stop()
        return try .closed(
            audioFile: shouldMove ? MediaManager.moveToPersistentDir(from: tmpRecorderFile)
                .get() : tmpRecorderFile
        )
    }
}

extension VoiceMessageAudioRecorder {
    // MARK: - Private Functions
    
    private func continueLoadedSession() {
        recordingStateSubject.send(.stopped)
        try? prepareAudioPlayBack()
        idleTimer.enable()
    }
    
    private func detachAudioRecorder() {
        resetIdleAndProximity()
        removeObservers()
        
        recorder?.stop()
        player?.stop()
        recorder = nil
        player = nil
        delegate = nil
    }
    
    private func resetIdleAndProximity() {
        if !NavigationBarPromptHandler.isWebActive {
            idleTimer.enable()
        }
        proximityMonitoring.deactivate()
    }
    
    // MARK: - Timer
    
    private func prepareTimer(_ isRecording: Bool) {
        stopTimer()
        timer = .scheduledTimer(withTimeInterval: 0.01, repeats: true, block: { [weak self] _ in
            if isRecording {
                self?.recordingStatusDidUpdate()
            }
            else {
                self?.playbackStatusDidUpdate()
            }
        })
        // Unfreeze while interacting with other views
        timer.map {
            RunLoop.current.add($0, forMode: .common)
        }
    }
    
    private func recordingStatusDidUpdate() {
        guard let recorder else {
            return
        }
        
        currentRecordingTime = recorder.currentTime + tmpAudioDuration
        let progress = fmax(0, fmin(1, currentRecordingTime / Configuration.recordDuration.max))
        recorder.updateMeters()
        
        if let delegate {
            delegate.didUpdateRecordProgress(with: self, progress)
        }
        
        if progress >= 1.0 {
            Task { await stop() }
        }
    }
    
    private func playbackStatusDidUpdate() {
        guard let player, let delegate else {
            return
        }
        let currentPlayTime = player.currentTime / player.duration
        let progress = fmax(0, fmin(1, currentPlayTime))
        delegate.didUpdatePlayProgress(with: self, progress)
    }
    
    // MARK: - Recorder
    
    /// Initializes the recorder with a new session URL and starts the actual recording.
    private func addRecording(_ completion: @escaping (Result<Void, VoiceMessageError>) -> Void) {
        dispatchQueue.async { [weak self] in
            guard let self, !isRecording else {
                completion(.failure(.recordingCancelled))
                return
            }
            
            switch audioSessionManager.setupForRecording() {
            case .success:
                do {
                    player?.stop()
                    player = nil
           
                    recorder = try AVAudioRecorder(
                        url: newRecordingSessionURL,
                        settings: Configuration.recordSettings
                    )
                    recorder?.isMeteringEnabled = true
                    recorder?.delegate = self
                    recorder?.record()
                        
                    adaptToProximityState()
                    
                    DispatchQueue.main.async {
                        self.prepareTimer(true)
                        self.proximityMonitoring.activate()
                    }
                        
                    completion(.success(()))
                }
                catch let error as NSError {
                    completion(.failure(.error(error)))
                }
            case let .failure(error):
                DDLogError("\(error.localizedDescription)")
                completion(.failure(.audioSessionFailure))
            }
        }
    }
    
    // MARK: - Player
    
    /// Create new player instance with the current recording file.
    private func prepareAudioPlayBack() throws {
        guard !isRecording, player == nil else {
            DDLogInfo("Can't start playback while recording")
            return
        }
        
        switch audioSessionManager.setupAudioSessionForPlayback() {
        case .success:
            player = try AVAudioPlayer(contentsOf: tmpRecorderFile)
            player?.delegate = self
        case let .failure(error):
            DDLogError("\(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Proximity
    
    private func adaptToProximityState() {
        dispatchQueue.async(qos: .userInitiated) { [weak self] in
            guard let self else {
                return
            }
            
            if let output = audioSessionManager.currentRoute.outputs.first,
               isPlaying, [.builtInSpeaker, .builtInReceiver].contains(output.portType) {
                audioSessionManager.setupAudioSession(isEarpiece: UIDevice.current.proximityState)
            }
            else {
                audioSessionManager.setupAudioSession(isEarpiece: false)
            }
        }
    }
}

// MARK: - Notifications

extension VoiceMessageAudioRecorder {
    private func removeObservers() {
        cancellables.removeAll()
    }
    
    private func registerNotificationObservers() {
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                guard let self else {
                    return
                }
                handleSessionInterruption(notification)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] notification in
                guard let self else {
                    return
                }
                applicationWillEnterForeground(notification)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIKit.UIDevice.proximityStateDidChangeNotification)
            .sink { [weak self] notification in
                guard let self else {
                    return
                }
                proximityStateChanged(notification)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                guard let self else {
                    return
                }
                runningInBackground = true
            }
            .store(in: &cancellables)
    }
    
    private func handleSessionInterruption(_ notification: Notification) {
        guard let interruptionType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: interruptionType) else {
            return
        }
        Task {
            switch type {
            case .began:
                await stop()
            case .ended:
                await record()
            @unknown default:
                break
            }
        }
    }
    
    private func applicationWillEnterForeground(_ notification: Notification) {
        if interrupted {
            interrupted = false
            Task { await record() }
        }
        
        runningInBackground = false
    }
    
    private func proximityStateChanged(_ notification: Notification) {
        guard let output = audioSessionManager.currentRoute.outputs.first,
              isPlaying, [.builtInSpeaker, .builtInReceiver].contains(output.portType) else {
            return
        }
        
        adaptToProximityState()
    }
}
