import AudioSessionManager
import SwiftUI

struct QRCodeCameraView: UIViewControllerRepresentable {
    private let audioSessionManager: (any AudioSessionManagerProtocol)?
    private let systemFeedbackManager: any SystemFeedbackManagerProtocol
    private let systemPermissionsManager: any SystemPermissionsManagerProtocol

    @Binding
    var shouldResume: Bool

    var onCompletion: ((String?) -> Void)?

    init(
        audioSessionManager: (any AudioSessionManagerProtocol)?,
        systemFeedbackManager: any SystemFeedbackManagerProtocol,
        systemPermissionsManager: any SystemPermissionsManagerProtocol,
        shouldResume: Binding<Bool>,
        onCompletion: ((String?) -> Void)? = nil
    ) {
        self.audioSessionManager = audioSessionManager
        self.systemFeedbackManager = systemFeedbackManager
        self.systemPermissionsManager = systemPermissionsManager
        self._shouldResume = shouldResume
        self.onCompletion = onCompletion
    }

    func makeUIViewController(context: Context) -> QRCodeCameraViewController {
        let controller = QRCodeCameraViewController(
            audioSessionManager: audioSessionManager,
            systemFeedbackManager: systemFeedbackManager,
            systemPermissionsManager: systemPermissionsManager
        )
        controller.onCompletion = onCompletion
        return controller
    }

    func updateUIViewController(_ uiViewController: QRCodeCameraViewController, context: Context) {
        if shouldResume {
            uiViewController.resumeRunning()
            DispatchQueue.main.async {
                shouldResume = false
            }
        }
    }
}
