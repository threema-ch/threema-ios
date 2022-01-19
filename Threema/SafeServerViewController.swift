//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2022 Threema GmbH
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
import ThreemaFramework

class SafeServerViewController: IDCreationPageViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var serverSwitchLabel: UILabel!
    @IBOutlet weak var serverSwitch: UISwitch!
    @IBOutlet weak var serverStackView: UIStackView!
    @IBOutlet weak var serverField: SetupTextField!
    @IBOutlet weak var serverLabel: UILabel!
    @IBOutlet weak var serverUsernameField: SetupTextField!
    @IBOutlet weak var serverPasswordField: SetupTextField!
    @IBOutlet weak var cancelButton: SetupButton!
    @IBOutlet weak var okButton: SetupButton!

    var keyboardResize: KeyboardResizeCenterY?
    
    var isServerForRestore: Bool = false
    private var cancelSegueID : String?
    private var okSegueID: String?
    
    var customServer: String?
    var server: String?
    var serverUsername: String?
    var serverPassword: String?
    var maxBackupBytes: Int?
    var retentionDays: Int?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.cancelSegueID = self.isServerForRestore ? "CancelRestoreSafeServer" : "CancelSafeServer"
        self.okSegueID = self.isServerForRestore ? "OkRestoreSafeServer" : "OkSafeServer"

        self.hideKeyboardWhenTappedAround()
        self.keyboardResize = KeyboardResizeCenterY(parent: self.view, resize: self.mainContentView)
        
        if self.isServerForRestore {
            self.titleLabel.isHidden = true
            self.descriptionLabel.text = NSLocalizedString("safe_configure_choose_server", comment: "")
        } else {
            self.titleLabel.text = NSLocalizedString("safe_configure_choose_server", comment: "")
            self.descriptionLabel.text = NSLocalizedString("safe_configure_server_explain", comment: "")
        }

        self.serverSwitchLabel.text = NSLocalizedString("safe_use_default_server", comment: "")
        self.serverField.delegate = self
        self.serverField.placeholder = "https://server.example.com"
        self.serverLabel.text = BundleUtil.localizedString(forKey: "safe_server_authentication")
        self.serverUsernameField.delegate = self
        self.serverUsernameField.placeholder = BundleUtil.localizedString(forKey: "username")
        self.serverPasswordField.delegate = self
        self.serverPasswordField.placeholder = BundleUtil.localizedString(forKey: "Password")
        self.cancelButton.setTitle(NSLocalizedString("cancel", comment: ""), for: .normal)
        self.okButton.setTitle(NSLocalizedString("ok", comment: ""), for: .normal)

        let isDefault = self.server == nil
        self.serverSwitch.isOn = isDefault
        self.serverStackView.isHidden = isDefault
        self.serverField.text = self.customServer
        self.serverUsernameField.text = self.serverUsername
        self.serverPasswordField.text = self.serverPassword
        
        self.serverSwitch.onTintColor = Colors.mainThemeDark()
    }
    
    //MARK: - Controlling the Keyboard
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {

        return true
    }
    
    func validateServer() -> Bool {
        if serverSwitch.isOn {
            self.customServer = nil
            self.server = nil
            self.serverUsername = nil
            self.serverPassword = nil
            self.maxBackupBytes = nil
            self.retentionDays = nil
        } else {
            let safeConfigManager = SafeConfigManager()
            let safeStore = SafeStore(safeConfigManager: safeConfigManager, serverApiConnector: ServerAPIConnector())
            
            if let customServer = self.serverField.text,
                let customServerUrl = safeStore.composeSafeServerAuth(server: customServer, user: self.serverUsernameField.text, password: self.serverPasswordField.text) {

                let safeManager = SafeManager(safeConfigManager: safeConfigManager, safeStore: safeStore, safeApiService: SafeApiService())
                let result = safeManager.testServer(serverUrl: customServerUrl)
                if let errorMessage = result.errorMessage {
                    let alert = IntroQuestionViewHelper(parent: self, onAnswer: nil)
                    alert.showAlert(errorMessage, title: BundleUtil.localizedString(forKey: "safe_test_server"))
                    return false
                } else {
                    self.customServer = customServer
                    self.server = customServerUrl.absoluteString
                    self.serverUsername = self.serverUsernameField.text
                    self.serverPassword = self.serverPasswordField.text
                    self.maxBackupBytes = result.maxBackupBytes
                    self.retentionDays = result.retentionDays
                }
            }
        }
        return true
    }
}

extension SafeServerViewController: SetupTextFieldDelegate {
    func editingChangedTextField(_ sender: SetupTextField, forEvent event: UIEvent) {  }
    
    func primaryActionTriggered(_ sender: SetupTextField, forEvent event: UIEvent) {
        if sender == self.serverField {
            self.serverUsernameField.becomeFirstResponder()
        } else if sender == self.serverUsernameField {
            self.serverPasswordField.becomeFirstResponder()
        } else if sender == self.serverPasswordField {
            sender.resignFirstResponder()
            
            if self.validateServer() {
                self.performSegue(withIdentifier: self.okSegueID!, sender: self)
            }
        }
    }
}

extension SafeServerViewController {
    @IBAction func changedServerSwitch(_ sender: UISwitch) {
        self.serverStackView.isHidden = sender.isOn
    }
    
    @IBAction func touchDownButton(_ sender: UIButton) {
        if sender == self.cancelButton {
            performSegue(withIdentifier: self.cancelSegueID!, sender: sender)
        } else if sender == self.okButton {
            if self.validateServer() {
                performSegue(withIdentifier: self.okSegueID!, sender: sender)
            }
        }
    }
}

extension SafeServerViewController {
    override func dismissKeyboard() {
        super.dismissKeyboard()
        
        serverField.resignFirstResponder()
        serverUsernameField.resignFirstResponder()
        serverPasswordField.resignFirstResponder()
    }
}
