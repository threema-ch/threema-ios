import AVFoundation
import CoreHaptics
import UIKit

final class DeviceCapabilitiesManager: DeviceCapabilitiesManagerProtocol {
    var hasCamera: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var hasClassicVibration: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    var hasHapticFeedback: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    var supportsCaptureImage: Bool {
        hasCamera && availableMediaTypesForCamera.contains(UTType.image.identifier)
    }

    var supportsRecordingVideo: Bool {
        hasCamera && availableMediaTypesForCamera.contains(UTType.movie.identifier)
    }

    /// Whether a video capture device is available.
    ///
    /// Unlike `hasCamera` (`UIImagePickerController`, `false` on the Simulator), this checks for an `AVCaptureDevice`.
    /// It reflects hardware presence only, regardless of authorization status.
    var hasVideoCaptureDevice: Bool {
        AVCaptureDevice.default(for: .video) != nil
    }

    // MARK: - Helpers

    private var availableMediaTypesForCamera: [String] {
        UIImagePickerController.availableMediaTypes(for: .camera) ?? []
    }
}
