import SwiftUI
import ThreemaMacros

extension RestoreIdentityViewController {
    private var topViewController: UIViewController {
        AppDelegate.shared().currentTopViewController() ?? .init()
    }

    private var systemFeedbackManager: SystemFeedbackManagerProtocol {
        SystemFeedbackManager(
            deviceCapabilitiesManager: DeviceCapabilitiesManager(),
            settingsStore: BusinessInjector.ui.settingsStore
        )
    }

    @MainActor @objc func showScannerViewController() {
        let model = QRCodeScannerViewModel(
            mode: .identityBackup,
            audioSessionManager: .null, // BusinessInjector is not available
            systemFeedbackManager: .null, // BusinessInjector is not available
            systemPermissionsManager: SystemPermissionsManager()
        )
        model.onCompletion = { [weak self] result in
            guard let self, case let .plainText(text) = result else {
                return
            }
            topViewController.dismiss(animated: true) { [weak self] in
                self?.backupLabel.isHidden = true
                self?.backupTextView.text = text
            }
        }
        model.onCancel = { [weak self] in
            self?.topViewController.dismiss(animated: true)
        }
        let rootView = QRCodeScannerView(model: model)
        let viewController = UIHostingController(rootView: rootView)
        let nav = PortraitNavigationController(rootViewController: viewController)
        topViewController.present(nav, animated: true)
    }
}
