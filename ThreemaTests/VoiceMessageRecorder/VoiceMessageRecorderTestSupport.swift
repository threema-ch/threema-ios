import AVFoundation
import Foundation
@testable import Threema

// MARK: - VoiceMessageTestAudio

/// Real AAC files, so the production merge, export and duration checks run unchanged
enum VoiceMessageTestAudio {
    private static let sampleRate = 16000.0

    /// Writes `seconds` of silence to `url`, replacing an existing file. 0 seconds gives a file without audio.
    static func writeSilence(_ seconds: TimeInterval, to url: URL) throws {
        try? FileManager.default.removeItem(at: url)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
        ]
        // Closed when it goes out of scope
        let file = try AVAudioFile(forWriting: url, settings: settings)

        let frameCount = AVAudioFrameCount(seconds * file.processingFormat.sampleRate)
        guard
            frameCount > 0,
            let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount),
            let channels = buffer.floatChannelData
        else {
            return
        }
        buffer.frameLength = frameCount
        for channel in 0..<Int(file.processingFormat.channelCount) {
            channels[channel].update(repeating: 0, count: Int(frameCount))
        }
        try file.write(from: buffer)
    }

    /// Duration of the audio at `url`, 0 if it has none or does not exist
    static func duration(of url: URL) async -> TimeInterval {
        await (try? AVURLAsset(url: url).load(.duration).seconds) ?? 0
    }
}

// MARK: - VoiceMessageTestEnvironment

/// What a recorder sees of the world: time and whether the microphone can be used. Main thread only.
final class VoiceMessageTestEnvironment {
    /// Seconds, drives `deviceCurrentTime` and the recorded duration
    var now: TimeInterval = 1000
    /// Another app holds the microphone
    var isMicrophoneBusy = false
    /// Every recorder created, oldest first
    private(set) var recorders: [VoiceMessageAudioRecorderMock] = []

    func record(_ seconds: TimeInterval) {
        now += seconds
    }

    func makeRecorder(url: URL) -> VoiceMessageAudioRecorderMock {
        let recorder = VoiceMessageAudioRecorderMock(url: url, environment: self)
        recorders.append(recorder)
        return recorder
    }
}

// MARK: - VoiceMessageAudioRecorderMock

/// Behaves like `AVAudioRecorder` as far as the file is concerned: the first `record()` creates (or truncates) the
/// file, `pause()` and `stop()` leave what was recorded so far in it, and `record()` fails while the microphone is
/// busy.
final class VoiceMessageAudioRecorderMock: VoiceMessageAudioRecorder {
    let url: URL
    weak var delegate: (any AVAudioRecorderDelegate)?
    var isMeteringEnabled = false

    private let environment: VoiceMessageTestEnvironment
    private var recorded: TimeInterval = 0
    private var startedAt: TimeInterval?
    private var isPrepared = false

    init(url: URL, environment: VoiceMessageTestEnvironment) {
        self.url = url
        self.environment = environment
    }

    var deviceCurrentTime: TimeInterval {
        environment.now
    }

    func record() -> Bool {
        if !isPrepared {
            try? VoiceMessageTestAudio.writeSilence(0, to: url)
            isPrepared = true
        }
        guard !environment.isMicrophoneBusy else {
            return false
        }
        startedAt = environment.now
        return true
    }

    func pause() {
        flush()
    }

    func stop() {
        flush()
    }

    func updateMeters() {
        // no-op
    }

    func averagePower(forChannel channelNumber: Int) -> Float {
        -20
    }

    private func flush() {
        if let startedAt {
            recorded += environment.now - startedAt
            self.startedAt = nil
        }
        if isPrepared {
            try? VoiceMessageTestAudio.writeSilence(recorded, to: url)
        }
    }
}
