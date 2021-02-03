//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2021 Threema GmbH
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

class RestoreSafeForgotIdViewController: IDCreationPageViewController {
    
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var mobileNumberField: SetupTextField!
    @IBOutlet weak var emailAddressField: SetupTextField!
    @IBOutlet weak var cancelButton: SetupButton!
    @IBOutlet weak var okButton: SetupButton!
    
    var keyboardResize: KeyboardResizeCenterY?
    
    var locatedIdentities: [String]?
    var selectedIdentity: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.hideKeyboardWhenTappedAround()
        self.keyboardResize = KeyboardResizeCenterY(parent: self.view, resize: self.mainContentView)

        self.descriptionLabel.text = NSLocalizedString("safe_search_id_title", comment: "")
        self.mobileNumberField.delegate = self
        self.mobileNumberField.placeholder = NSLocalizedString("safe_linked_mobile", comment: "")
        self.emailAddressField.delegate = self
        self.emailAddressField.placeholder = NSLocalizedString("safe_linked_email", comment: "")
        self.cancelButton.setTitle(NSLocalizedString("cancel", comment: ""), for: .normal)
        self.okButton.setTitle(NSLocalizedString("ok", comment: ""), for: .normal)
        self.okButton.deactivated = true
    }

    // MARK: - Navigation
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        guard identifier == "okSafeForgotId" else {
            return true
        }
     
        return self.selectedIdentity != nil
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let forgotIdChooseViewController = segue.destination as? RestoreSafeForgotIdChooseViewController {
            self.mainContentView.isHidden = true
            forgotIdChooseViewController.ids = self.locatedIdentities
        }
    }
    
    // MARK: - Private methods
    
    private func searchIdentity() {
        if let email = self.emailAddressField.text,
            let mobileNo = self.mobileNumberField.text,
            email.count > 0 || mobileNo.count > 0 {
            
            let queue = DispatchQueue.global()
            let semaphore = DispatchSemaphore(value: 0)
            
            queue.async {
                ContactStore.shared()?.linkedIdentities(email, mobileNo: mobileNo, onCompletion: { (result) in
                    if let result: Array = result {
                        self.locatedIdentities = result.map({ (item) -> String in
                            var itemName: String = ""
                            if let itemDic = item as? Dictionary<String, String> {
                                let identity = itemDic["identity"]!
                                if itemDic.keys.contains("emailHash") {
                                    itemName = "\(identity) (\(email))"
                                } else if itemDic.keys.contains("mobileNoHash") {
                                    itemName = "\(identity) (\(mobileNo))"
                                }
                            }
                            return itemName
                        })
                        
                        semaphore.signal()
                    }
                })
            }
        
            semaphore.wait()

            if let identities = self.locatedIdentities {
                if identities.count > 1 {
                    self.performSegue(withIdentifier: "SafeForgotIdChoose", sender: self)
                } else if identities.count == 1 {
                    let id: String = identities[0]
                    self.selectedIdentity = String(id[id.startIndex..<id.index(id.startIndex, offsetBy: 8)])
                    self.performSegue(withIdentifier: "okSafeForgotId", sender: self)
                } else {
                    let alert = IntroQuestionViewHelper(parent: self, onAnswer: nil)
                    alert.showAlert(BundleUtil.localizedString(forKey: "safe_no_id_found"))
                }
            }
        }
    }
}

extension RestoreSafeForgotIdViewController: SetupTextFieldDelegate {
    func editingChangedTextField(_ sender: SetupTextField, forEvent event: UIEvent) {
        if let mobile = self.mobileNumberField.text, mobile.count > 0 {
            self.okButton.deactivated = false
        } else if let email = self.emailAddressField.text, email.count > 0 {
            self.okButton.deactivated = false
        } else {
            self.okButton.deactivated = true
        }
    }
    
    func primaryActionTriggered(_ sender: SetupTextField, forEvent event: UIEvent) {
        if sender == self.mobileNumberField {
            self.emailAddressField.becomeFirstResponder()
        } else if sender == self.emailAddressField {
            self.searchIdentity()
        }
    }
}

extension RestoreSafeForgotIdViewController {
    @IBAction func touchDownButton(_ sender: UIButton, forEvent event: UIEvent) {
        guard sender == okButton else {
            return
        }

        self.searchIdentity()
    }

    @IBAction func cancelSafeForgotIdChoose(_ segue: UIStoryboardSegue) {
        self.mainContentView.isHidden = false
    }

    @IBAction func choosenSafeForgotIdChoose(_ segue: UIStoryboardSegue) {
        self.mainContentView.isHidden = false
        
        if let forgotIdChooseViewController = segue.source as? RestoreSafeForgotIdChooseViewController {
            self.selectedIdentity = forgotIdChooseViewController.choosenId
            self.performSegue(withIdentifier: "okSafeForgotId", sender: self)
        }
    }
}

extension RestoreSafeForgotIdViewController {
    override func dismissKeyboard() {
        super.dismissKeyboard()
        
        mobileNumberField.resignFirstResponder()
        emailAddressField.resignFirstResponder()
    }
}
