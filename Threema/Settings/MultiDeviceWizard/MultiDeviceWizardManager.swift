//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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
    
    let wizardView: MultiDeviceWizardView
    let hostingController: UIHostingController<MultiDeviceWizardView>
    let wizardVM = MultiDeviceWizardViewModel()
    
    @objc override init() {
        self.wizardView = MultiDeviceWizardView(wizardVM: wizardVM)
        self.hostingController = UIHostingController(rootView: wizardView)
        hostingController.isModalInPresentation = true
    }
    
    @objc func showWizard(on navigationVC: UIViewController) {
        wizardVM.isAdditionalLinking = false
        wizardVM.wizardState = .terms
        navigationVC.present(hostingController, animated: true)
    }

    func showWizard(on navigationVC: UIViewController, additionalLinking: Bool) {
        wizardVM.isAdditionalLinking = additionalLinking
        wizardVM.wizardState = .preparation
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
