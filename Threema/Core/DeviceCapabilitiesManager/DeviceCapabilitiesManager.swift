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

    // MARK: - Helpers

    private var availableMediaTypesForCamera: [String] {
        UIImagePickerController.availableMediaTypes(for: .camera) ?? []
    }
}
