protocol DeviceCapabilitiesManagerProtocol: Sendable {
    var hasCamera: Bool { get }

    var hasClassicVibration: Bool { get }

    var hasHapticFeedback: Bool { get }

    var supportsCaptureImage: Bool { get }

    var supportsRecordingVideo: Bool { get }
}
