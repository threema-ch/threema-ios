import AVFoundation
import CocoaLumberjackSwift
import DSWaveformImage
import SwiftUI
import ThreemaFramework

// MARK: - VoiceMessageRecorderViewModel

@MainActor
final class VoiceMessageRecorderViewModel: NSObject, ObservableObject {
    typealias MediaManager = AudioMediaManager
    
    // MARK: - Published properties
    
    @Published var recordingState: RecordingState = .ready
    @Published var samples: [Float] = []
    @Published var duration: TimeInterval = .zero
    
    // MARK: - Properties

    let waveFormConfiguration: Waveform.Configuration = .init(style: .striped(.init(
        color: .gray,
        width: 2,
        spacing: 3
    )))
    
    private let recordSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: 44100.0,
        AVNumberOfChannelsKey: 1,
        AVEncoderBitRateKey: 32000,
        AVLinearPCMBitDepthKey: 16,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
    ]
    
    private let conversation: ConversationEntity
    
    let recordingMaxDuration = 30 * 60.0

    var assetDuration: Double {
        get async {
            await (try? combinedRecordings?.asset.load(.duration).seconds) ?? 0.0
        }
    }

    var totalRecordingDuration: Double {
        get async {
            if let currentRecorder, let recorderStartTimeInterval {
                currentRecorder.deviceCurrentTime - recorderStartTimeInterval + recordedDuration
            }
            else {
                await assetDuration
            }
        }
    }

    // Contains the created asset by previous recordings and the URL where the asset is stored at. Is used for sending
    // and playback but never for recording.
    private var combinedRecordings: (asset: AVAsset, url: URL)?
    // URL containing the current audio file the recorder is using
    private var recordingURL: URL = MediaManager.newRecordingAudioURL()

    // Helpers to calculate recording time
    private var recorderStartTimeInterval: TimeInterval?
    private var recordedDuration = 0.0
    
    private var recordTimer: Timer?
    private var playTimer: Timer?

    // Info: Due to file access limitations, we cannot have a recorder and a player accessing the same url at the same time.
    // Both must call stop before the other accesses file at the url (i.e. is initialized).
    private var currentRecorder: AVAudioRecorder?
    private var currentPlayer: AVAudioPlayer?
    private lazy var audioSessionManager = AudioSessionManager()
    
    private var sendingInProgress = false
    
    // MARK: - Lifecycle

    @MainActor
    init(conversation: ConversationEntity, draftAudioURL: URL? = nil) throws {
        
        self.conversation = conversation
        
        super.init()
        
        startObservers()
        if !UIAccessibility.isVoiceOverRunning {
            UIDevice.current.isProximityMonitoringEnabled = true
        }
        UIApplication.shared.isIdleTimerDisabled = true

        Task { @MainActor in
            do {
                if let draftAudioURL {
                    try await configureDraft(draftAudioURL: draftAudioURL)
                }
                else {
                    try await startRecording()
                }
            }
            catch {
                throw VoiceMessageError.recordingStartFailed
            }
        }
    }
    
    deinit {
        Task { @MainActor in
            UIDevice.current.isProximityMonitoringEnabled = false
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    @MainActor
    private func configureDraft(draftAudioURL: URL) async throws {
        // We copy the draft into temp dir for processingt
        let copyURl = MediaManager.newRecordingAudioURL()
        do {
            try MediaManager.copy(source: draftAudioURL, destination: copyURl)
        }
        catch {
            DDLogError("[Voice Recorder] Failed to load draft audio file: \(error). Removing draft.")
            MessageDraftStore.shared.deleteDraft(for: conversation)
            throw VoiceMessageError.loadDraftFailed
        }
        
        let asset = AVAsset(url: copyURl)
        combinedRecordings = (asset, copyURl)
        recordingState = .stopped
        duration = await assetDuration
        recordedDuration = await assetDuration
    }
    
    // MARK: - Observation

    private func startObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(proximityStateDidChange),
            name: UIKit.UIDevice.proximityStateDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(interruptionNotification(notification:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    @objc private func proximityStateDidChange() {
        audioSessionManager.adaptToProximityState()
    }
    
    @objc private func interruptionNotification(notification: Notification) {
        guard let info = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: info) else {
            return
        }
        
        switch type {
        case .began:
            Task { @MainActor in
                await interruptionBegan()
            }

        case .ended:
            DDLogInfo("Audio session interruption ended, reactivating...")
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            }
            catch {
                DDLogError("Failed to reactivate audio session: \(error)")
            }

        @unknown default:
            break
        }
    }

    @MainActor
    private func interruptionBegan() async {
        switch recordingState {
        case .ready, .stopped, .paused:
            break
        case .recording:
            await stopRecording()
        case .playing:
            pause()
        }
    }
    
    // MARK: - Recording

    @MainActor
    private func createRecorder() throws -> AVAudioRecorder {
        // We create a new recorder with a new URL
        let url = MediaManager.newRecordingAudioURL()
        let recorder = try AVAudioRecorder(url: url, settings: recordSettings)
        recordingURL = url
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        return recorder
    }
    
    /// Terminates the current recorder, merges existing recordings and stores them in `combinedRecordings` for playback
    /// or sending
    /// - Parameter completion: Called when merged recordings are available after export
    private func terminateRecorder(completion: (() -> Void)?) {
        guard let recorder = currentRecorder else {
            // This means we already have the needed assets, so we can directly call completion
            completion?()
            return
        }
        recorder.stop()
        stopRecordTimer()
        
        // After stopping we combine the created recording with the existing recording if it exists, otherwise we
        // assign it to be the new existing recording directly. The updated or new existing recording is then used in
        // the player
        // or for sending.
        if let existingRecording = combinedRecordings {
            Task {
                defer {
                    currentRecorder = nil
                }
                do {
                    let combinedURL = MediaManager.newRecordingAudioURL()
                    let urls = [existingRecording.url, recordingURL]
                    let asset = try await MediaManager.concatenateRecordingsAndSave(combine: urls, to: combinedURL)
                    combinedRecordings = (asset, combinedURL)
                    recordingURL = MediaManager.newRecordingAudioURL()
                    completion?()
                }
                catch {
                    DDLogError("[Voice Recorder] Failed to combine recordings: \(error).")
                    NotificationPresenterWrapper.shared.present(type: .recordingFailed)
                }
            }
        }
        else {
            combinedRecordings = (AVURLAsset(url: recordingURL), recordingURL)
            currentRecorder = nil
            completion?()
        }
    }

    private func startRecording() async throws {
        // We disallow recording when in a call
        guard !NavigationBarPromptHandler.isCallActiveInBackground, !NavigationBarPromptHandler.isGroupCallActive else {
            NotificationPresenterWrapper.shared.present(type: .recordingCallRunning)

            recordingState = .stopped
            return
        }
        
        guard await totalRecordingDuration <= recordingMaxDuration else {
            NotificationPresenterWrapper.shared.present(type: .recordingTooLong)
            return
        }
        
        // Reset the player to have sole control of the file
        if currentPlayer != nil {
            terminatePlayer()
        }
        
        // We check if we need to create a new recorder (not needed when only pausing but not playing).
        let recorder: AVAudioRecorder
        if let currentRecorder {
            recorder = currentRecorder
        }
        else {
            recorder = try createRecorder()
            currentRecorder = recorder
        }
        
        try audioSessionManager.setupForRecording()
        recordingState = .recording
        recorder.record()
        recorderStartTimeInterval = recorder.deviceCurrentTime
        startRecordTimer()
    }

    @MainActor
    func continueRecording() async {
        do {
            try await startRecording()
        }
        catch {
            DDLogError("[Voice Recorder] Failed to continue recording: \(error).")
            NotificationPresenterWrapper.shared.present(type: .recordingFailed)
        }
    }

    @MainActor
    func stopRecording() async {
        guard let recorder = currentRecorder else {
            assertionFailure("[Voice Recorder] Cannot stop if there is no recorder.")
            return
        }
        recorder.pause()

        recordedDuration = await totalRecordingDuration
        stopRecordTimer()
        recordingState = .paused
    }
   
    func sendRecording(success: @escaping () -> Void) {
        recordingState = .ready
        
        // If we are not recording, the needed asset was already generated when we stopped, so we can call send
        // directly.
        if currentRecorder != nil {
            terminateRecorder {
                self.terminatePlayer()
                self.send(success: success)
            }
        }
        else {
            terminatePlayer()
            send(success: success)
        }
    }
    
    private func send(success: @escaping () -> Void) {
        guard !sendingInProgress else {
            DDLogWarn("[Voice Recorder] Attempting to send while sending in progress.")
            return
        }
        sendingInProgress = true
        
        guard let senderItem = URLSenderItem(
            url: recordingURL,
            type: UTType.audio.identifier,
            renderType: 1,
            sendAsFile: true
        ) else {
            sendingFailed()
            return
        }
        
        Task {
            do {
                try await BusinessInjector.ui.messageSender.sendBlobMessage(
                    for: senderItem,
                    in: conversation.objectID,
                    correlationID: nil,
                    webRequestID: nil
                )
                self.sendingCompleted()
            }
            catch let error as BlobManagerError {
                guard error != .noteGroupNeedsNoSync else {
                    self.sendingCompleted()
                    success()
                    return
                }
                sendingFailed()
            }
            catch {
                sendingFailed()
            }
            // If we encounter issues in blob manager, we rely on the chatview handling them.
            success()
        }
    }
    
    private func sendingCompleted() {
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.prepare()
        feedbackGenerator.notificationOccurred(.success)
        sendingInProgress = false
    }
    
    private func sendingFailed() {
        NotificationPresenterWrapper.shared.present(type: .sendingError)
        recordingState = .stopped
        sendingInProgress = false
    }
        
    // MARK: - Player

    func createPlayer() throws -> AVAudioPlayer {
        guard let combinedRecordings else {
            DDLogError("[Voice Recorder] Combined assets missing for creating player.")
            throw VoiceMessageError.assetNotFound
        }
        
        try audioSessionManager.setupForPlayback()
        
        let player = try AVAudioPlayer(contentsOf: combinedRecordings.url)
        player.delegate = self
        currentPlayer = player
        return player
    }
    
    private func terminatePlayer() {
        currentPlayer?.stop()
        stopPlayTimer()
        currentPlayer = nil
    }
    
    func seek(to progress: Double) {
        guard let player = currentPlayer else {
            return
        }
        Task { @MainActor in
            let timeStamp = await progress * assetDuration
            player.currentTime = timeStamp
            updatePlayProgress()
        }
    }
        
    func play() {
        // We possibly need to combine the files first, and then call play.
        terminateRecorder { [weak self] in
            Task { @MainActor in
                self?.startPlaying()
            }
        }
    }

    private func startPlaying() {
        // We disallow play when in a call
        guard !NavigationBarPromptHandler.isCallActiveInBackground, !NavigationBarPromptHandler.isGroupCallActive else {
            NotificationPresenterWrapper.shared.present(type: .recordingCallRunning)
            return
        }
        
        // We check if we need to create a new player (not needed when only pausing but not recording since last play).
        let player: AVAudioPlayer
        if let currentPlayer {
            player = currentPlayer
        }
        else {
            do {
                player = try createPlayer()
            }
            catch {
                DDLogError("[Voice Recorder] Failed to start playing: \(error).")
                NotificationPresenterWrapper.shared.present(type: .recordingPlayingFailed)
                return
            }
        }
        
        player.play()
        recordingState = .playing
        startPlayTimer()
    }
    
    func pause() {
        guard let player = currentPlayer else {
            return
        }
        
        player.pause()
        stopPlayTimer()
        recordingState = .paused
    }
        
    func loadSamples(count: Int) {
        guard let url = combinedRecordings?.url else {
            samples = []
            return
        }
        Task {
            do {
                let newSamples = try await WaveformAnalyzer().samples(
                    fromAudioAt: url,
                    count: count
                )
                await MainActor.run {
                    self.samples = newSamples
                }
            }
            catch {
                DDLogError("[Voice Recorder] Failed to load samples: \(error).")
                return
            }
        }
    }
    
    // MARK: - Timer

    private func startRecordTimer() {
        let timer = Timer.scheduledTimer(
            timeInterval: 0.01,
            target: self,
            selector: #selector(updateRecordProgress),
            userInfo: nil,
            repeats: true
        )
        recordTimer = timer
        RunLoop.current.add(timer, forMode: .common)
    }
    
    private func stopRecordTimer() {
        recordTimer?.invalidate()
        recordTimer = nil
        recorderStartTimeInterval = nil
    }
    
    @objc private func updateRecordProgress() {
        guard let recorder = currentRecorder else {
            stopRecordTimer()
            return
        }
        recorder.updateMeters()
        let lastAveragePower = recorder.averagePower(forChannel: 0)
        let linear = 1 - pow(10, lastAveragePower / 30)
        let value = max(0.5, min(1, linear))
        samples.append(value)

        Task { @MainActor in
            let total = await totalRecordingDuration
            duration = total
            if total >= recordingMaxDuration {
                await stopRecording()
                NotificationPresenterWrapper.shared.present(type: .recordingTooLong)
            }
        }
    }
    
    private func startPlayTimer() {
        let timer = Timer.scheduledTimer(
            timeInterval: 0.1,
            target: self,
            selector: #selector(updatePlayProgress),
            userInfo: nil,
            repeats: true
        )
        playTimer = timer
        RunLoop.current.add(timer, forMode: .common)
    }
    
    private func stopPlayTimer() {
        playTimer?.invalidate()
        playTimer = nil
    }
    
    @objc private func updatePlayProgress() {
        guard let player = currentPlayer, let combinedRecordings else {
            stopPlayTimer()
            return
        }

        let currentPlayTime = player.currentTime / player.duration
        let progress = fmax(0, fmin(1, currentPlayTime))

        Task { @MainActor in
            duration = await (try? progress * combinedRecordings.asset.load(.duration).seconds) ?? 0
        }
    }

    // MARK: - UI
    
    func handleMagicTap() async {
        switch recordingState {
        case .ready:
            break
        case .recording:
            await stopRecording()
        case .stopped:
            await continueRecording()
        case .playing:
            pause()
        case .paused:
            play()
        }
    }
    
    func willDismissView() {
        stopRecordTimer()
        terminatePlayer()
        cleanupFiles()
    }
    
    func saveVoiceMessageRecordingAsDraft() {
        terminateRecorder {
            // Moves recording file from tmp to documents folder for draft or the recording file will be deleted
            guard !AppLaunchManager.isRemoteSecretEnabled, let combinedRecordings = self.combinedRecordings else {
                self.cleanupFiles()
                return
            }
            do {
                let documentsURL = try MediaManager.moveToDocumentsDir(from: combinedRecordings.url)
                MessageDraftStore.shared.saveDraft(.audio(documentsURL), for: self.conversation)
            }
            catch {
                DDLogError("[Voice Recorder] Failed to save  draft: \(error).")
            }
        }
    }

    func cleanupFiles() {
        if let combinedRecordings {
            MediaManager.cleanupFile(combinedRecordings.url)
        }
        MediaManager.cleanupFile(recordingURL)
    }
}

// MARK: - AVAudioPlayerDelegate

extension VoiceMessageRecorderViewModel: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            stopPlayTimer()
            recordingState = .paused
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension VoiceMessageRecorderViewModel: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            stopRecordTimer()
        }
    }
}
