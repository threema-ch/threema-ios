import AudioSessionManager
import CocoaLumberjackSwift
import Foundation
import ThreemaFramework

/// For the text to speech function.
final class SpeechSynthesizerManager: NSObject {
    private lazy var synth = {
        let speechSynthesizer = AVSpeechSynthesizer()
        speechSynthesizer.delegate = self
        return speechSynthesizer
    }()

    private let audioSessionManager: any AudioSessionManagerProtocol

    /// Held while speaking.
    private var audioSessionClaim: AudioSessionClaim?

    private var currentUtterance: AVSpeechUtterance?

    // MARK: - Lifecycle

    init(audioSessionManager: any AudioSessionManagerProtocol = BusinessInjector.ui.audioSessionManager) {
        self.audioSessionManager = audioSessionManager
        super.init()
    }

    deinit {
        guard let claim = audioSessionClaim else {
            return
        }

        // Copied into a local: the `Task` outlives this object.
        let manager = audioSessionManager
        Task {
            await manager.release(claim)
        }
    }

    // MARK: - Public functions

    func speak(_ text: String) {
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
            currentUtterance = nil
        }

        let utterance = AVSpeechUtterance(string: text)
        currentUtterance = utterance

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            await acquireAudioSessionClaim()
            synth.speak(utterance)
        }
    }

    // MARK: - Audio session claim

    @MainActor
    private func acquireAudioSessionClaim() async {
        guard audioSessionClaim == nil else {
            return
        }

        do {
            audioSessionClaim = try await audioSessionManager.acquire(.speech)
        }
        catch {
            DDLogError("[SpeechSynthesizer] Could not acquire the audio session: \(error)")
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
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechSynthesizerManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if currentUtterance == utterance {
            currentUtterance = nil
            releaseAudioSessionClaim()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        if currentUtterance == utterance {
            currentUtterance = nil
            releaseAudioSessionClaim()
        }
    }
}
