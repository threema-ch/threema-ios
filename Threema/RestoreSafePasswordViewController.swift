//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2020 Threema GmbH
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

import UIKit

class RestoreSafePasswordViewController: IDCreationPageViewController {
    
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var passwordField: SetupTextField!
    @IBOutlet weak var cancelButton: SetupButton!
    @IBOutlet weak var okButton: SetupButton!
    
    var keyboardResize: KeyboardResizeCenterY?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.hideKeyboardWhenTappedAround()
        self.keyboardResize = KeyboardResizeCenterY(parent: self.view, resize: self.mainContentView)

        self.descriptionLabel.text = NSLocalizedString("safe_enter_password", comment: "")
        self.passwordField.delegate = self
        self.passwordField.placeholder = NSLocalizedString("Password", comment: "")
        self.passwordField.becomeFirstResponder()
        self.cancelButton.setTitle(NSLocalizedString("cancel", comment: ""), for: .normal)
        self.okButton.setTitle(NSLocalizedString("ok", comment: ""), for: .normal)
        
        refreshView()
    }

    private func refreshView() {
        if let password = self.passwordField.text,
            password.count >= 8 {
            
            self.okButton.deactivated = false
        } else {
            self.okButton.deactivated = true
        }
    }
}

extension RestoreSafePasswordViewController: SetupTextFieldDelegate {
    func editingChangedTextField(_ sender: SetupTextField, forEvent event: UIEvent) {
        refreshView()
    }
    
    func primaryActionTriggered(_ sender: SetupTextField, forEvent event: UIEvent) {
        self.performSegue(withIdentifier: "okSafePassword", sender: sender)
    }
}
