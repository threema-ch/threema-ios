import AudioToolbox
import CocoaLumberjackSwift
import UIKit

final class SystemFeedbackManager: SystemFeedbackManagerProtocol {
    private let deviceCapabilitiesManager: DeviceCapabilitiesManagerProtocol
    private let settingsStore: SettingsStoreProtocol

    init(deviceCapabilitiesManager: DeviceCapabilitiesManagerProtocol, settingsStore: SettingsStoreProtocol) {
        self.deviceCapabilitiesManager = deviceCapabilitiesManager
        self.settingsStore = settingsStore
    }

    func playSuccessSound() {
        if let path = pathForSound(.success) {
            playSound(with: path)
        }
    }

    func vibrate() {
        if deviceCapabilitiesManager.hasClassicVibration, settingsStore.inAppVibrate {
            AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
        }
    }

    // MARK: - Helpers

    private enum Sound {
        case success

        var filename: String {
            switch self {
            case .success:
                "scan_success"
            }
        }

        var fileExtension: String {
            "caf"
        }
    }

    private func playSound(with soundPath: String) {
        guard settingsStore.inAppSounds else {
            return
        }

        let soundURL = URL(fileURLWithPath: soundPath) as CFURL
        var soundID: SystemSoundID = 0

        let status = AudioServicesCreateSystemSoundID(soundURL as CFURL, &soundID)
        guard status == kAudioServicesNoError else {
            DDLogError("Failed to create system sound ID: \(status)")
            return
        }

        AudioServicesAddSystemSoundCompletion(
            soundID,
            nil,
            nil,
            { id, _ in
                AudioServicesRemoveSystemSoundCompletion(id)
                AudioServicesDisposeSystemSoundID(id)
            },
            nil
        )

        AudioServicesPlaySystemSound(soundID)
    }

    private func pathForSound(_ sound: Sound) -> String? {
        let path = BundleUtil.path(forResource: sound.filename, ofType: sound.fileExtension)
        if path == nil {
            DDLogError("Could not load sound file `\(sound.filename).\(sound.fileExtension).")
        }
        return path
    }
}
