//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2025 Threema GmbH
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

import MBProgressHUD
import ThreemaFramework
import ThreemaMacros
import UIKit

class SafeServerViewController: IDCreationPageViewController {
    
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var serverSwitchLabel: UILabel!
    @IBOutlet var serverSwitch: UISwitch!
    @IBOutlet var serverStackView: UIStackView!
    @IBOutlet var serverField: SetupTextField!
    @IBOutlet var serverLabel: UILabel!
    @IBOutlet var serverUsernameField: SetupTextField!
    @IBOutlet var serverPasswordField: SetupTextField!
    @IBOutlet var cancelButton: SetupButton!
    @IBOutlet var okButton: SetupButton!

    var keyboardResize: KeyboardResizeCenterY?
    
    var isServerForRestore = false
    private var cancelSegueID: String?
    private var okSegueID: String?
    
    var customServer: String?
    var server: String?
    var serverUsername: String?
    var serverPassword: String?
    var maxBackupBytes: Int?
    var retentionDays: Int?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        cancelSegueID = isServerForRestore ? "CancelRestoreSafeServer" : "CancelSafeServer"
        okSegueID = isServerForRestore ? "OkRestoreSafeServer" : "OkSafeServer"

        hideKeyboardWhenTappedAround()
        keyboardResize = KeyboardResizeCenterY(parent: view, resize: mainContentView)

        titleLabel.text = String.localizedStringWithFormat(
            #localize("safe_configure_choose_server"),
            TargetManager.localizedAppName
        )
        if TargetManager.isOnPrem {
            descriptionLabel.text = String.localizedStringWithFormat(
                #localize("safe_configure_server_explain_onprem"),
                TargetManager.localizedAppName
            )
        }
        else {
            descriptionLabel.text = String.localizedStringWithFormat(
                #localize("safe_configure_server_explain"),
                TargetManager.localizedAppName
            )
        }

        serverSwitchLabel.text = #localize("safe_use_default_server")
        serverField.delegate = self
        serverField.placeholder = "https://server.example.com"
        serverLabel.text = #localize("safe_server_authentication")
        serverUsernameField.delegate = self
        serverUsernameField.placeholder = #localize("username")
        serverPasswordField.delegate = self
        serverPasswordField.placeholder = #localize("Password")
        cancelButton.setTitle(#localize("cancel"), for: .normal)
        okButton.setTitle(#localize("ok"), for: .normal)

        let isDefault = server == nil
        serverSwitch.isOn = isDefault
        serverStackView.isHidden = isDefault
        serverField.text = customServer
        serverUsernameField.text = serverUsername
        serverPasswordField.text = serverPassword
    }
    
    // MARK: - Controlling the Keyboard
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {

        true
    }
    
    func validateServer(completion: @escaping (Bool) -> Void) {
        if serverSwitch.isOn {
            customServer = nil
            server = nil
            serverUsername = nil
            serverPassword = nil
            maxBackupBytes = nil
            retentionDays = nil
            completion(true)
            return
        }
        else {
            let safeConfigManager = SafeConfigManager()
            let safeStore = SafeStore(
                safeConfigManager: safeConfigManager,
                serverApiConnector: ServerAPIConnector(),
                groupManager: BusinessInjector.ui.groupManager
            )
            
            if let customServer = serverField.text,
               let customServerURL = URL(string: customServer) {

                let safeManager = SafeManager(
                    safeConfigManager: safeConfigManager,
                    safeStore: safeStore,
                    safeApiService: SafeApiService()
                )
                DispatchQueue.main.async {
                    MBProgressHUD.showAdded(to: self.view, animated: true)
                }
                safeManager.testServer(
                    serverURL: customServerURL,
                    user: serverUsernameField.text,
                    password: serverPasswordField.text
                ) { errorMessage, maxBackupBytes, retentionDays in
                    DispatchQueue.main.async {
                        MBProgressHUD.hide(for: self.view, animated: true)
                        
                        if let errorMessage {
                            let alert = IntroQuestionViewHelper(parent: self, onAnswer: nil)
                            alert.showAlert(errorMessage, title: #localize("safe_test_server"))
                            completion(false)
                            return
                        }
                        else {
                            self.customServer = customServer
                            self.server = customServerURL.absoluteString
                            self.serverUsername = self.serverUsernameField.text
                            self.serverPassword = self.serverPasswordField.text
                            self.maxBackupBytes = maxBackupBytes
                            self.retentionDays = retentionDays
                            completion(true)
                            return
                        }
                    }
                }
            }
        }
    }
}

// MARK: - SetupTextFieldDelegate

extension SafeServerViewController: SetupTextFieldDelegate {
    func editingChangedTextField(_ sender: SetupTextField, forEvent event: UIEvent) { }
    
    func primaryActionTriggered(_ sender: SetupTextField, forEvent event: UIEvent) {
        if sender == serverField {
            serverUsernameField.becomeFirstResponder()
        }
        else if sender == serverUsernameField {
            serverPasswordField.becomeFirstResponder()
        }
        else if sender == serverPasswordField {
            sender.resignFirstResponder()
            
            validateServer { success in
                if success {
                    self.performSegue(withIdentifier: self.okSegueID!, sender: self)
                }
            }
        }
    }
}

extension SafeServerViewController {
    @IBAction func changedServerSwitch(_ sender: UISwitch) {
        serverStackView.isHidden = sender.isOn
    }
    
    @IBAction func touchDownButton(_ sender: UIButton) {
        if sender == cancelButton {
            performSegue(withIdentifier: cancelSegueID!, sender: sender)
        }
        else if sender == okButton {
            validateServer { success in
                if success {
                    self.performSegue(withIdentifier: self.okSegueID!, sender: sender)
                }
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
