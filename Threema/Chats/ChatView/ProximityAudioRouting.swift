import AudioSessionManager
import AVFoundation
import UIKit

/// Where a voice message should play, given the proximity sensor.
@MainActor
enum ProximityAudioRouting {

    /// Ports where holding the phone to your ear is a meaningful signal.
    private static let builtInOutputs: Set<AVAudioSession.Port> = [.builtInSpeaker, .builtInReceiver]

    /// The route to ask for right now.
    ///
    /// - Parameter audioSessionManager: asked for the current ports, so this does not have to read
    ///   `AVAudioSession` itself.
    static func currentOutput(
        _ audioSessionManager: any AudioSessionManagerProtocol
    ) async -> AudioSessionOutput {
        guard UIDevice.current.proximityState else {
            return .system
        }

        // Headphones and Bluetooth outrank the ear
        guard await audioSessionManager.currentRoute().outputs.contains(where: builtInOutputs.contains) else {
            return .system
        }

        return .receiver
    }
}
