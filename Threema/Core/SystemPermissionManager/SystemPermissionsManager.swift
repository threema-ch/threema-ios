import AVFoundation
import CocoaLumberjackSwift

final class SystemPermissionsManager: SystemPermissionsManagerProtocol {
    func hasVideoCapturePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        var isAuthorized = status == .authorized

        if status == .notDetermined {
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        }

        return isAuthorized
    }
}
