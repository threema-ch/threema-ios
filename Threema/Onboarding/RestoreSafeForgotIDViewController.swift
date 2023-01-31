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

import UIKit

class RestoreSafeForgotIDViewController: IDCreationPageViewController {
    
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var mobileNumberField: SetupTextField!
    @IBOutlet var emailAddressField: SetupTextField!
    @IBOutlet var cancelButton: SetupButton!
    @IBOutlet var okButton: SetupButton!
    
    var keyboardResize: KeyboardResizeCenterY?
    
    var locatedIdentities: [String]?
    var selectedIdentity: String?
    
    /// True while we are waiting for the callback from the server
    private var isSearchingIdentity = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        hideKeyboardWhenTappedAround()
        keyboardResize = KeyboardResizeCenterY(parent: view, resize: mainContentView)
        
        descriptionLabel.text = BundleUtil.localizedString(forKey: "safe_search_id_title")
        mobileNumberField.delegate = self
        mobileNumberField.placeholder = BundleUtil.localizedString(forKey: "safe_linked_mobile")
        mobileNumberField.mobile = true
        emailAddressField.delegate = self
        emailAddressField.placeholder = BundleUtil.localizedString(forKey: "safe_linked_email")
        emailAddressField.capitalization = 0
        cancelButton.setTitle(BundleUtil.localizedString(forKey: "cancel"), for: .normal)
        okButton.setTitle(BundleUtil.localizedString(forKey: "ok"), for: .normal)
        okButton.deactivated = true
    }
    
    // MARK: - Navigation
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        guard identifier == "okSafeForgotID" else {
            return true
        }
        
        return selectedIdentity != nil
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let forgotIDChooseViewController = segue.destination as? RestoreSafeForgotIDChooseViewController {
            mainContentView.isHidden = true
            forgotIDChooseViewController.ids = locatedIdentities
        }
    }
    
    // MARK: - Private methods
    
    private func searchIdentity() {
        guard !isSearchingIdentity else {
            return
        }
        
        isSearchingIdentity = true
        
        if let email = emailAddressField.text,
           let mobileNo = mobileNumberField.text,
           !email.isEmpty || !mobileNo.isEmpty {
            
            ContactStore.shared().linkedIdentities(for: email, and: mobileNo, onCompletion: { [weak self] result in
                defer { self?.isSearchingIdentity = false }
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.getIdentities(result: result, email: email, mobileNo: mobileNo)
                
                if let identities = strongSelf.locatedIdentities {
                    if identities.count > 1 {
                        strongSelf.performSegue(withIdentifier: "SafeForgotIDChoose", sender: strongSelf)
                    }
                    else if identities.count == 1 {
                        let id: String = identities[0]
                        strongSelf.selectedIdentity = String(id[id.startIndex..<id.index(id.startIndex, offsetBy: 8)])
                        strongSelf.performSegue(withIdentifier: "okSafeForgotID", sender: strongSelf)
                    }
                    else {
                        let alert = IntroQuestionViewHelper(parent: strongSelf, onAnswer: nil)
                        alert.showAlert(BundleUtil.localizedString(forKey: "safe_no_id_found"))
                    }
                }
            })
        }
    }
    
    private func getIdentities(result: [Any], email: String, mobileNo: String) {
        locatedIdentities = result.map { item -> String in
            var itemName = ""
            if let itemDic = item as? [String: String] {
                let identity = itemDic["identity"]!
                if itemDic.keys.contains("emailHash") {
                    itemName = "\(identity) (\(email))"
                }
                else if itemDic.keys.contains("mobileNoHash") {
                    itemName = "\(identity) (\(mobileNo))"
                }
            }
            return itemName
        }
    }
}

// MARK: - SetupTextFieldDelegate

extension RestoreSafeForgotIDViewController: SetupTextFieldDelegate {
    func editingChangedTextField(_ sender: SetupTextField, forEvent event: UIEvent) {
        if let mobile = mobileNumberField.text, !mobile.isEmpty {
            okButton.deactivated = false
        }
        else if let email = emailAddressField.text, !email.isEmpty {
            okButton.deactivated = false
        }
        else {
            okButton.deactivated = true
        }
    }
    
    func primaryActionTriggered(_ sender: SetupTextField, forEvent event: UIEvent) {
        if sender == mobileNumberField {
            emailAddressField.becomeFirstResponder()
        }
        else if sender == emailAddressField {
            sender.resignFirstResponder()
            searchIdentity()
        }
    }
}

extension RestoreSafeForgotIDViewController {
    @IBAction func touchDownButton(_ sender: UIButton, forEvent event: UIEvent) {
        guard sender == okButton else {
            return
        }
        
        searchIdentity()
    }
    
    @IBAction func cancelSafeForgotIDChoose(_ segue: UIStoryboardSegue) {
        mainContentView.isHidden = false
    }
    
    @IBAction func choosenSafeForgotIDChoose(_ segue: UIStoryboardSegue) {
        mainContentView.isHidden = false
        
        if let forgotIDChooseViewController = segue.source as? RestoreSafeForgotIDChooseViewController {
            selectedIdentity = forgotIDChooseViewController.choosenID
            performSegue(withIdentifier: "okSafeForgotID", sender: self)
        }
    }
}

extension RestoreSafeForgotIDViewController {
    override func dismissKeyboard() {
        super.dismissKeyboard()
        
        mobileNumberField.resignFirstResponder()
        emailAddressField.resignFirstResponder()
    }
}
