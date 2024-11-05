//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2024 Threema GmbH
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

import CocoaLumberjackSwift
import ThreemaFramework
import ThreemaMacros
import UIKit

class RestoreSafePasswordViewController: IDCreationPageViewController {
    
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var passwordField: SetupTextField!
    @IBOutlet var cancelButton: SetupButton!
    @IBOutlet var okButton: SetupButton!
    @IBOutlet var forgotPasswordTappableLabel: ZSWTappableLabel!
    
    var keyboardResize: KeyboardResizeCenterY?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        hideKeyboardWhenTappedAround()
        keyboardResize = KeyboardResizeCenterY(parent: view, resize: mainContentView)

        descriptionLabel.text = #localize("safe_enter_password")
        passwordField.delegate = self
        passwordField.placeholder = #localize("Password")
        passwordField.accessibilityIdentifier = "RestoreSafePasswordViewControllerPasswordTextfield"
        passwordField.becomeFirstResponder()
        cancelButton.setTitle(#localize("cancel"), for: .normal)
        okButton.setTitle(#localize("ok"), for: .normal)
        okButton.accessibilityIdentifier = "RestoreSafePasswordViewControllerOkButton"

        forgotPasswordTappableLabel.tapDelegate = self
        let linkAttributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.tappableRegion: true,
            NSAttributedString.Key.foregroundColor: Colors
                .textWizardLink,
            NSAttributedString.Key.underlineStyle: NSUnderlineStyle
                .single.rawValue,
            .font: UIFont.systemFont(ofSize: 16),
        ]
        
        let faqLabelText = NSAttributedString(
            string: #localize("restore_option_help_link_text"),
            attributes: linkAttributes
        )
        forgotPasswordTappableLabel.attributedText = faqLabelText
        
        refreshView()
    }

    private func refreshView() {
        if let password = passwordField.text,
           password.count >= 8 {
            
            okButton.deactivated = false
        }
        else {
            okButton.deactivated = true
        }
    }
}

// MARK: - SetupTextFieldDelegate

extension RestoreSafePasswordViewController: SetupTextFieldDelegate {
    func editingChangedTextField(_ sender: SetupTextField, forEvent event: UIEvent) {
        refreshView()
    }
    
    func primaryActionTriggered(_ sender: SetupTextField, forEvent event: UIEvent) {
        performSegue(withIdentifier: "okSafePassword", sender: sender)
    }
}

extension RestoreSafePasswordViewController {
    override func dismissKeyboard() {
        super.dismissKeyboard()
        
        passwordField.resignFirstResponder()
    }
}

// MARK: - ZSWTappableLabelTapDelegate

extension RestoreSafePasswordViewController: ZSWTappableLabelTapDelegate {
    func tappableLabel(
        _ tappableLabel: ZSWTappableLabel,
        tappedAt idx: Int,
        withAttributes attributes: [NSAttributedString.Key: Any] = [:]
    ) {
        let url = ThreemaURLProvider.resetSafePassword
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}
