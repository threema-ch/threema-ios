//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import Foundation
import SwiftUI

class MultiDeviceWizardManager: NSObject {
    
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
