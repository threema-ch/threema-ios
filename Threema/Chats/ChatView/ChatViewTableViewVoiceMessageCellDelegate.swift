//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

import CocoaLumberjackSwift
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
    
    func isMessageCurrentlyPlaying(_ message: BaseMessage?) -> Bool
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
    private var playTimer: Timer?
    
    private var progressDictionary = [NSManagedObjectID: CGFloat]()
    
    private var previousAudioSessionCategory: AVAudioSession.Category?
    
    // MARK: - Lifecycle
    
    init(chatViewController: ChatViewController) {
        self.chatViewController = chatViewController
        
        super.init()
        
        configure()
    }
    
    deinit {
        stopPlayingAndDoCleanup()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Private functions
    
    // MARK: - Configuration
    
    private func configure() {
        setupProximityMonitoringIfEnabled()
    }
    
    private func setupProximityMonitoringIfEnabled() {
        guard !UserSettings.shared().disableProximityMonitoring else {
            return
        }
        
        NotificationCenter.default.addObserver(
            forName: UIDevice.proximityStateDidChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.previousAudioSessionCategory = AudioSessionInputOutputAdapter.currentAudioSession()
            
            AudioSessionInputOutputAdapter.proximityStateChanged(for: strongSelf.audioPlayer) { error in
                strongSelf.showAlert(for: error)
            }
        }
    }
    
    private func showAlert(for error: NSError) {
        guard let chatViewController else {
            DDLogError(
                "Could not get chatViewController to display error message on. Error \(error.code) \(error.localizedDescription)"
            )
            return
        }

        UIAlertTemplate.showAlert(
            owner: chatViewController,
            title: error.localizedDescription,
            message: error.localizedFailureReason
        )
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
            
            playTimer?.invalidate()
            cleanupTemporaryFiles()
            finishedCallback?(true)
        }
    }
    
    private func createPlaybackProgressTimer() {
        guard let audioPlayer else {
            let msg = "AudioPlayer is unexpectedly nil"
            assertionFailure(msg)
            DDLogError(msg)
            return
        }
        
        guard let progressCallback else {
            let msg = "ProgressCallback is unexpectedly nil"
            assertionFailure(msg)
            DDLogError(msg)
            return
        }
        
        playTimer = Timer
            .scheduledTimer(withTimeInterval: config.progressCallbackInterval, repeats: true) { timer in
                if !audioPlayer.isPlaying {
                    timer.invalidate()
                }
                
                let progress = audioPlayer.currentTime / audioPlayer.duration
                progressCallback(audioPlayer.currentTime, progress)
            }
    }
    
    private func cleanupTemporaryFiles() {
        /// Clean up exported file for playback
        /// This can occur often if a user plays back the same voice messages lots of times
        /// If this fails, the temporary directory is cleaned up regularly by the app and on deinit of the
        /// ChatViewController
        FileUtility.delete(at: currentlyPlayingURL)
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
        
        guard let audioPlayer else {
            let msg = "Couldn't create audioPlayer from audio message"
            assertionFailure(msg)
            DDLogError(msg)
            return
        }

        self.finishedCallback = finishedCallback
        self.progressCallback = progressCallback
        self.pauseCallback = pauseCallback
        
        AudioSessionInputOutputAdapter.adaptToProximityState()
        
        // Start Playing
        currentlyPlaying = message
        currentlyPlayingURL = url
        
        audioPlayer.rate = Float(rate)
        
        if let progress = progressDictionary[message.objectID] {
            audioPlayer.currentTime = audioPlayer.duration * progress
        }
        
        if !UserSettings.shared().disableProximityMonitoring {
            UIDevice.current.isProximityMonitoringEnabled = true
        }
        audioPlayer.play()
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
            DDLogWarn(msg)
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
        playTimer?.invalidate()
        
        if let audioPlayer, let currentlyPlaying {
            let progress = CGFloat(audioPlayer.currentTime / audioPlayer.duration)
            progressDictionary[currentlyPlaying.objectID] = progress
        }
        
        UIDevice.current.isProximityMonitoringEnabled = false
        audioPlayer?.pause()
        
        pauseCallback?()
        
        AudioSessionInputOutputAdapter.resetAudioSession(to: previousAudioSessionCategory)
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

        playTimer?.invalidate()
        self.audioPlayer?.currentTime = audioPlayer.duration * progress
        if audioPlayer.isPlaying {
            createPlaybackProgressTimer()
        }
    }
    
    /// Check is message current playing. If the parameter is nil, it will check if there some audio message is playing
    /// - Parameter message: Message to check (optional)
    /// - Returns: Is the parameter message (or some message) currently playing
    func isMessageCurrentlyPlaying(_ message: BaseMessage?) -> Bool {
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
        playTimer?.invalidate()
        
        UIDevice.current.isProximityMonitoringEnabled = false
        audioPlayer?.stop()
        audioPlayer = nil
        
        AudioSessionInputOutputAdapter.resetAudioSession(to: previousAudioSessionCategory)
        
        cleanupTemporaryFiles()
    }
}

// MARK: - AVAudioPlayerDelegate

extension ChatViewTableViewVoiceMessageCellDelegate: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopPlayingAndDoCleanup()
    }
}
