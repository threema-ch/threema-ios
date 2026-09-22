import AVFoundation

/// What a client needs the audio session for, and therefore how the session is configured for it.
public enum AudioSessionClientKind: Int, Sendable, Comparable {
    /// Audio that must never interrupt anything else: the QR scanner's shutter mute
    case ambient = 0

    /// Voice message playback, which follows the proximity sensor to the earpiece
    case playback = 1

    /// Video: a tapped video message, the photo browser, the pre-send preview
    case mediaPlayback = 2

    /// Text to speech
    case speech = 3

    /// Voice message recording
    case recording = 4

    /// 1:1 calls, whose session CallKit activates
    case call = 5

    /// Group calls, which have no CallKit and so must activate their own session
    case groupCall = 6

    // MARK: - Properties
    
    /// Default options every call path uses today
    private static let callOptions: AVAudioSession.CategoryOptions = [
        .duckOthers,
        .allowBluetooth,
        .allowBluetoothA2DP,
        .allowAirPlay,
    ]
    
    var isCall: Bool {
        self == .call || self == .groupCall
    }

    private static func options(
        _ base: AVAudioSession.CategoryOptions,
        for output: AudioSessionOutput
    ) -> AVAudioSession.CategoryOptions {
        output == .speaker ? base.union(.defaultToSpeaker) : base
    }

    /// Who wins, as distinct from how the session is configured.
    private var priority: Int {
        switch self {
        case .ambient:
            0
        
        // The three playback kinds share a rank: but they differ in mode
        case .playback, .mediaPlayback, .speech:
            1
            
        case .recording:
            2
            
        case .call, .groupCall:
            3
        }
    }

    // MARK: - Functions
    
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.priority < rhs.priority
    }

    /// The profile this kind needs in order to play out of `output`.
    ///
    /// Taking the output here, rather than letting a caller set it on a finished profile, is what keeps
    /// **one** place aware that a route can imply a category.
    package func profile(for output: AudioSessionOutput) -> AudioSessionProfile {
        switch self {
        case .ambient:
            AudioSessionProfile(category: .ambient, mode: .default, output: output)

        case .playback:
            if output == .receiver {
                AudioSessionProfile(
                    category: .playAndRecord,
                    mode: .spokenAudio,
                    options: Self.options([.allowBluetooth, .allowBluetoothA2DP], for: output),
                    output: output
                )
            }
            else {
                AudioSessionProfile(category: .playback, mode: .spokenAudio, output: output)
            }

        case .mediaPlayback:
            AudioSessionProfile(category: .playback, mode: .moviePlayback, output: output)

        case .speech:
            AudioSessionProfile(category: .playback, mode: .voicePrompt, output: output)

        case .recording:
            AudioSessionProfile(
                category: .playAndRecord,
                mode: .spokenAudio,
                options: Self.options([.allowBluetooth, .allowBluetoothA2DP], for: output),
                output: output,
                prefersNoInterruptionsFromSystemAlerts: true
            )

        case .call:
            AudioSessionProfile(
                category: .playAndRecord,
                mode: .voiceChat,
                options: Self.options(Self.callOptions, for: output),
                output: output,
                prefersNoInterruptionsFromSystemAlerts: true,
                activation: .external
            )

        case .groupCall:
            AudioSessionProfile(
                category: .playAndRecord,
                mode: .voiceChat,
                options: Self.options(Self.callOptions, for: output),
                output: output,
                prefersNoInterruptionsFromSystemAlerts: true,
                activation: .driverOwned
            )
        }
    }
}
