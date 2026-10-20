import AudioSessionManager
import CocoaLumberjackSwift
import FileUtility
import Foundation
import ThreemaFramework

/// Delegate to handle playback in VoiceMessageCells
protocol ChatViewTableViewVoiceMessageCellDelegateProtocol: NSObject {
    func startPlaying(
        message: VoiceMessage,
        url: URL,
        rate: CGFloat,
        progressCallback: @escaping (TimeInterval, CGFloat) -> Void,
        pauseCallback: @escaping () -> Void,
        finishedCallback: @escaping (Bool) -> Void
    )
    func pausePlaying()
    
    func updatePlaybackSpeed(_ playbackSpeed: CGFloat)
    func updateProgress(for voiceMessage: VoiceMessage, to progress: CGFloat)
    
    func getProgress(for voiceMessage: VoiceMessage) -> CGFloat
    
    func isMessageCurrentlyPlaying(_ message: BaseMessageEntity?) -> Bool
    func reregisterCallbacks(
        message: VoiceMessage,
        progressCallback: @escaping (TimeInterval, CGFloat) -> Void,
        pauseCallback: @escaping () -> Void,
        finishedCallback: @escaping (Bool) -> Void
    )
    
    func currentTimeForward(for voiceMessage: VoiceMessage)
    func currentTimeRewind(for voiceMessage: VoiceMessage)
}

/// Handles the interaction between voice message cells and the AVAudioPlayer handling the playback
/// Cells which are reloaded should call `startPlaying` upon being reloaded in order to receive playback progress and
/// finished callbacks
final class ChatViewTableViewVoiceMessageCellDelegate: NSObject, ChatViewTableViewVoiceMessageCellDelegateProtocol {
    typealias config = ChatViewConfiguration.VoiceMessage

    // MARK: - State Properties
    
    var didDisappear = false
    
    // MARK: - Private Properties

    private weak var chatViewController: ChatViewController?
    
    private var currentlyPlaying: VoiceMessage?
    private var currentlyPlayingURL: URL?
    private var audioPlayer: AVAudioPlayer?
    private var finishedCallback: ((Bool) -> Void)?
    private var progressCallback: ((TimeInterval, CGFloat) -> Void)?
    private var pauseCallback: (() -> Void)?
    private var playTimer: DispatchSourceTimer?
    
    private var progressDictionary = [NSManagedObjectID: CGFloat]()

    private let audioSessionManager: any AudioSessionManagerProtocol

    /// Held for as long as a message is playing, and released on pause or stop.
    private var audioSessionClaim: AudioSessionClaim?

    private var proximityObserver: (any NSObjectProtocol)?

    // MARK: - Lifecycle

    init(
        chatViewController: ChatViewController,
        audioSessionManager: any AudioSessionManagerProtocol = BusinessInjector.ui.audioSessionManager
    ) {
        self.chatViewController = chatViewController
        self.audioSessionManager = audioSessionManager

        super.init()

        configure()
    }

    deinit {
        stopPlayingAndDoCleanup()

        if let proximityObserver {
            NotificationCenter.default.removeObserver(proximityObserver)
        }
        
        NotificationCenter.default.removeObserver(self)
    }

    private func configure() {
        setupProximityMonitoring()
    }

    // MARK: - Private functions

    private func setupProximityMonitoring() {
        proximityObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.proximityStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else {
                return
            }

            Task { @MainActor in
                await self.updateAudioSessionOutput()
            }
        }
    }

    // MARK: - Audio session claim

    @MainActor
    private func acquireAudioSessionClaim() async {
        guard audioSessionClaim == nil else {
            await updateAudioSessionOutput()
            return
        }

        do {
            // The route is named at acquire time, so a message started with the phone already at the ear
            // configures the session once rather than applying `.playback` and then promoting it.
            let output = await ProximityAudioRouting.currentOutput(audioSessionManager)
            audioSessionClaim = try await audioSessionManager.acquire(.playback, output: output)
        }
        catch {
            NotificationPresenterWrapper.shared.present(type: .playbackFailed)
            DDLogError("Could not acquire the audio session for voice message playback: \(error)")
        }
    }
    
    private func releaseAudioSessionClaim() {
        guard let claim = audioSessionClaim else {
            return
        }
        audioSessionClaim = nil

        let manager = audioSessionManager
        Task {
            await manager.release(claim)
        }
    }

    /// Follow the proximity sensor, which is what moves playback to the earpiece.
    @MainActor
    private func updateAudioSessionOutput() async {
        guard let audioSessionClaim else {
            return
        }

        let output = await ProximityAudioRouting.currentOutput(audioSessionManager)
        await audioSessionManager.update(audioSessionClaim, output: output)
    }

    // MARK: - Playback Handling

    private func initializeAudioPlayerIfNeeded(url: URL) {
        if audioPlayer == nil {
            audioPlayer = try? AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.enableRate = true
            audioPlayer?.prepareToPlay()
        }
    }
    
    private func handleSimultaneousPlayIfNecessary(for newMessage: VoiceMessage, with exportedDataAtURL: URL) {
        if let currentlyPlaying, currentlyPlaying.objectID != newMessage.objectID {
            audioPlayer?.stop()
            audioPlayer = nil
            
            playTimer?.cancel()
            cleanupTemporaryFiles()
            finishedCallback?(true)
        }
    }
    
    private func createPlaybackProgressTimer() {
        guard let audioPlayer else {
            let msg = "AudioPlayer is unexpectedly nil"
            assertionFailure(msg)
            DDLogError("\(msg)")
            return
        }
        
        guard let progressCallback else {
            let msg = "ProgressCallback is unexpectedly nil"
            assertionFailure(msg)
            DDLogError("\(msg)")
            return
        }
        
        // DispatchSourceTimer on a background queue instead of Timer on the main run loop:
        // AVAudioPlayer.currentTime makes a synchronous XPC call to the audio server, which can
        // block for seconds and hang the app if called from the main thread. The progress callback
        // is dispatched back to main for UI updates.
        let interval = Double(config.progressCallbackInterval)
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler {
            guard audioPlayer.isPlaying else {
                return
            }
            let currentTime = audioPlayer.currentTime
            let duration = audioPlayer.duration
            guard duration > 0 else {
                return
            }
            let progress = currentTime / duration
            DispatchQueue.main.async {
                progressCallback(currentTime, progress)
            }
        }
        timer.resume()
        playTimer = timer
    }
    
    private func cleanupTemporaryFiles() {
        /// Clean up exported file for playback
        /// This can occur often if a user plays back the same voice messages lots of times
        /// If this fails, the temporary directory is cleaned up regularly by the app and on deinit of the
        /// ChatViewController
        FileUtility.shared.deleteIfExists(at: currentlyPlayingURL)
    }
    
    // MARK: - ChatViewTableViewVoiceMessageCellDelegateProtocol Implementation
    
    func startPlaying(
        message: VoiceMessage,
        url: URL,
        rate: CGFloat,
        progressCallback: @escaping (TimeInterval, CGFloat) -> Void,
        pauseCallback: @escaping () -> Void,
        finishedCallback: @escaping (Bool) -> Void
    ) {
        guard !didDisappear else {
            DDLogError("Cannot start playing because we did disappear")
            return
        }
        
        // Stop already running playback and remove temporary files
        handleSimultaneousPlayIfNecessary(for: message, with: url)
        
        // Start playback with new URL or continue to use the existing audio player
        initializeAudioPlayerIfNeeded(url: url)
        
        guard audioPlayer != nil else {
            DDLogError("Couldn't create audioPlayer from audio message")
            FileUtility.shared.deleteIfExists(at: url)
            NotificationPresenterWrapper.shared.present(type: .recordingPlayingFailed)
            DispatchQueue.main.async {
                finishedCallback(true)
            }
            return
        }

        self.finishedCallback = finishedCallback
        self.progressCallback = progressCallback
        self.pauseCallback = pauseCallback

        currentlyPlaying = message
        currentlyPlayingURL = url

        // Before the claim, so the first route decision can already see the phone at the ear. Reading
        // `proximityState` with monitoring off always answers "far".
        UIDevice.current.isProximityMonitoringEnabled = true

        // Playback starts after the claim, not alongside it: the claim decides the category the player
        // runs in, and acquiring suspends.
        Task { @MainActor in
            await acquireAudioSessionClaim()
            beginPlayback(of: message, rate: rate)
        }
    }

    @MainActor
    private func beginPlayback(of message: VoiceMessage, rate: CGFloat) {
        guard let audioPlayer else {
            return
        }

        audioPlayer.rate = Float(rate)

        if let progress = progressDictionary[message.objectID] {
            audioPlayer.currentTime = audioPlayer.duration * progress
        }

        audioPlayer.play()
        // Again after `play()`, which resets it.
        audioPlayer.rate = Float(rate)

        createPlaybackProgressTimer()
    }
    
    func reregisterCallbacks(
        message: VoiceMessage,
        progressCallback: @escaping (TimeInterval, CGFloat) -> Void,
        pauseCallback: @escaping () -> Void,
        finishedCallback: @escaping (Bool) -> Void
    ) {
        guard let currentlyPlaying, currentlyPlaying.objectID == message.objectID else {
            let msg =
                "Currently playing message and message passed in for reregistering are different. This may happen if you're very unlucky with timing and we have just switched to the next message"
            DDLogError("\(msg)")
            return
        }
            
        self.finishedCallback = finishedCallback
        self.progressCallback = progressCallback
        self.pauseCallback = pauseCallback
    }
    
    func currentTimeForward(for voiceMessage: VoiceMessage) {
        if let audioPlayer, let currentlyPlaying, voiceMessage == currentlyPlaying {
            audioPlayer.currentTime += 10
        }
    }
    
    func currentTimeRewind(for voiceMessage: VoiceMessage) {
        if let audioPlayer, let currentlyPlaying, voiceMessage == currentlyPlaying {
            audioPlayer.currentTime -= 10
        }
    }
    
    func pausePlaying() {
        playTimer?.cancel()
        
        if let audioPlayer, let currentlyPlaying {
            let progress = CGFloat(audioPlayer.currentTime / audioPlayer.duration)
            progressDictionary[currentlyPlaying.objectID] = progress
        }
        
        UIDevice.current.isProximityMonitoringEnabled = false
        audioPlayer?.pause()
        
        pauseCallback?()

        // No call guard any more: a playback claim taken during a call was subordinate and never
        // configured anything, so releasing it cannot disturb the call.
        releaseAudioSessionClaim()
    }
    
    func getProgress(for voiceMessage: VoiceMessage) -> CGFloat {
        if let audioPlayer, let currentlyPlaying, voiceMessage == currentlyPlaying {
            return CGFloat(audioPlayer.currentTime / audioPlayer.duration)
        }
        
        if let progress = progressDictionary[voiceMessage.objectID] {
            return progress
        }
        
        return 0
    }
    
    func updatePlaybackSpeed(_ playbackSpeed: CGFloat) {
        audioPlayer?.rate = Float(playbackSpeed)
    }
    
    func updateProgress(for voiceMessage: VoiceMessage, to progress: CGFloat) {
        
        progressDictionary[voiceMessage.objectID] = progress

        guard let audioPlayer else {
            return
        }
        
        guard voiceMessage.objectID == currentlyPlaying?.objectID else {
            return
        }

        playTimer?.cancel()
        self.audioPlayer?.currentTime = audioPlayer.duration * progress
        if audioPlayer.isPlaying {
            createPlaybackProgressTimer()
        }
    }
    
    /// Check is message current playing. If the parameter is nil, it will check if there some audio message is playing
    /// - Parameter message: Message to check (optional)
    /// - Returns: Is the parameter message (or some message) currently playing
    func isMessageCurrentlyPlaying(_ message: BaseMessageEntity?) -> Bool {
        guard let currentlyPlaying else {
            return false
        }
        
        guard let audioPlayer, audioPlayer.isPlaying else {
            return false
        }
        
        guard let message else {
            return true
        }
        
        return currentlyPlaying.objectID == message.objectID
    }
    
    // MARK: - Update functions
    
    /// Stops playback and removes all created temporary files
    /// - Parameter cancel: Whether we should continue playing with the next continuous voice message if it exists
    /// or cancel playback.
    func stopPlayingAndDoCleanup(cancel: Bool = false) {
        if let audioPlayer {
            let progress = CGFloat(audioPlayer.currentTime / audioPlayer.duration)
            if let currentlyPlaying {
                if progress < 0.98 {
                    progressDictionary[currentlyPlaying.objectID] = progress
                }
                else {
                    progressDictionary.removeValue(forKey: currentlyPlaying.objectID)
                }
            }
        }
        
        finishedCallback?(cancel)
        playTimer?.cancel()
        
        UIDevice.current.isProximityMonitoringEnabled = false
        audioPlayer?.stop()
        audioPlayer = nil
        
        releaseAudioSessionClaim()

        cleanupTemporaryFiles()
    }
}

// MARK: - AVAudioPlayerDelegate

extension ChatViewTableViewVoiceMessageCellDelegate: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopPlayingAndDoCleanup()
    }
}
