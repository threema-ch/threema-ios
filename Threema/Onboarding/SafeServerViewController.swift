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

import ThreemaFramework
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

        titleLabel.text = BundleUtil.localizedString(forKey: "safe_configure_choose_server")
        if ThreemaApp.current == .onPrem {
            descriptionLabel.text = BundleUtil.localizedString(forKey: "safe_configure_server_explain_onprem")
        }
        else {
            descriptionLabel.text = BundleUtil.localizedString(forKey: "safe_configure_server_explain")
        }

        serverSwitchLabel.text = BundleUtil.localizedString(forKey: "safe_use_default_server")
        serverField.delegate = self
        serverField.placeholder = "https://server.example.com"
        serverLabel.text = BundleUtil.localizedString(forKey: "safe_server_authentication")
        serverUsernameField.delegate = self
        serverUsernameField.placeholder = BundleUtil.localizedString(forKey: "username")
        serverPasswordField.delegate = self
        serverPasswordField.placeholder = BundleUtil.localizedString(forKey: "Password")
        cancelButton.setTitle(BundleUtil.localizedString(forKey: "cancel"), for: .normal)
        okButton.setTitle(BundleUtil.localizedString(forKey: "ok"), for: .normal)

        let isDefault = server == nil
        serverSwitch.isOn = isDefault
        serverStackView.isHidden = isDefault
        serverField.text = customServer
        serverUsernameField.text = serverUsername
        serverPasswordField.text = serverPassword
        
        serverSwitch.onTintColor = Colors.primaryWizard
    }
    
    // MARK: - Controlling the Keyboard
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {

        true
    }
    
    func validateServer() -> Bool {
        if serverSwitch.isOn {
            customServer = nil
            server = nil
            serverUsername = nil
            serverPassword = nil
            maxBackupBytes = nil
            retentionDays = nil
        }
        else {
            let safeConfigManager = SafeConfigManager()
            let safeStore = SafeStore(
                safeConfigManager: safeConfigManager,
                serverApiConnector: ServerAPIConnector(),
                groupManager: GroupManager()
            )
            
            if let customServer = serverField.text,
               let customServerURL = safeStore.composeSafeServerAuth(
                   server: customServer,
                   user: serverUsernameField.text,
                   password: serverPasswordField.text
               ) {

                let safeManager = SafeManager(
                    safeConfigManager: safeConfigManager,
                    safeStore: safeStore,
                    safeApiService: SafeApiService()
                )
                let result = safeManager.testServer(serverURL: customServerURL)
                if let errorMessage = result.errorMessage {
                    let alert = IntroQuestionViewHelper(parent: self, onAnswer: nil)
                    alert.showAlert(errorMessage, title: BundleUtil.localizedString(forKey: "safe_test_server"))
                    return false
                }
                else {
                    self.customServer = customServer
                    server = customServerURL.absoluteString
                    serverUsername = serverUsernameField.text
                    serverPassword = serverPasswordField.text
                    maxBackupBytes = result.maxBackupBytes
                    retentionDays = result.retentionDays
                }
            }
        }
        return true
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
            
            if validateServer() {
                performSegue(withIdentifier: okSegueID!, sender: self)
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
        else if sender == okButton,
                validateServer() {
            performSegue(withIdentifier: okSegueID!, sender: sender)
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
