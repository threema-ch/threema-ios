import Foundation
import SwiftUI

final class MultiDeviceWizardManager: NSObject {
    
    @objc static let shared = MultiDeviceWizardManager()
    
    private var wizardVM: MultiDeviceWizardViewModel
    private var wizardView: MultiDeviceWizardView
    private var hostingController: UIHostingController<MultiDeviceWizardView>

    @objc override private init() {
        self.wizardVM = MultiDeviceWizardViewModel()
        self.wizardView = MultiDeviceWizardView(wizardVM: wizardVM)
        self.hostingController = UIHostingController(rootView: wizardView)
        hostingController.isModalInPresentation = true
    }
    
    func showWizard(on navigationVC: UIViewController, additionalLinking: Bool = false) {
        // Reinitialize views to enforce starting wizard on terms view
        wizardVM = MultiDeviceWizardViewModel()
        wizardVM.isAdditionalLinking = additionalLinking
        wizardVM.wizardState = .terms
        wizardView = MultiDeviceWizardView(wizardVM: wizardVM)
        hostingController = UIHostingController(rootView: wizardView)
        hostingController.isModalInPresentation = true
        navigationVC.present(hostingController, animated: true)
    }

    @objc func wizardViewController() -> UIViewController {
        hostingController
    }
    
    @objc func continueWizard() {
        Task { @MainActor in
            wizardVM.advanceState(.identity)
        }
    }

    @objc func continueLinking() {
        wizardVM.startLinking()
    }
}
