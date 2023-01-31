//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2023 Threema GmbH
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

        descriptionLabel.text = BundleUtil.localizedString(forKey: "safe_enter_password")
        passwordField.delegate = self
        passwordField.placeholder = BundleUtil.localizedString(forKey: "Password")
        passwordField.accessibilityIdentifier = "RestoreSafePasswordViewControllerPasswordTextfield"
        passwordField.becomeFirstResponder()
        cancelButton.setTitle(BundleUtil.localizedString(forKey: "cancel"), for: .normal)
        okButton.setTitle(BundleUtil.localizedString(forKey: "ok"), for: .normal)
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
            string: BundleUtil.localizedString(forKey: "forgot_password_link_text"),
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
        let urlString = "https://threema.ch/faq/safepw"
        guard let url = URL(string: urlString) else {
            DDLogError("Could not create url from string \(urlString)")
            return
        }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}
