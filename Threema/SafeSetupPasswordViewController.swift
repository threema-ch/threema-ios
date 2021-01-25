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
import MBProgressHUD

class SafeSetupPasswordViewController: ThemedTableViewController {
    
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var passwordAgainField: UITextField!
    @IBOutlet weak var serverSwitchLabel: UILabel!
    @IBOutlet weak var serverSwitch: UISwitch!
    @IBOutlet weak var serverField: UITextField!
    @IBOutlet weak var serverUserNameField: UITextField!
    @IBOutlet weak var serverPasswordField: UITextField!
    
    private var safeStore: SafeStore
    private var safeManager: SafeManager
    private var mdmSetup: MDMSetup
    
    var customServer: String?
    var server: String?
    var maxBackupBytes: Int?
    var retentionDays: Int?
    
    var isOpenedFromIntro: Bool = false
    @objc var isForcedBackup: Bool = false
    
    required init?(coder aDecoder: NSCoder) {
        let safeConfigManager = SafeConfigManager()
        self.safeStore = SafeStore(safeConfigManager: safeConfigManager, serverApiConnector: ServerAPIConnector())
        self.safeManager = SafeManager(safeConfigManager: safeConfigManager, safeStore: self.safeStore, safeApiService: SafeApiService())
        self.mdmSetup = MDMSetup(setup: false)
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.hideKeyboardWhenTappedAround()
        
        self.passwordField.placeholder = BundleUtil.localizedString(forKey: "Password")
        self.passwordAgainField.placeholder = BundleUtil.localizedString(forKey: "password_again")
        self.serverSwitchLabel.text = BundleUtil.localizedString(forKey: "safe_use_default_server")
        self.serverField.placeholder = "https://server.example.com"
        self.serverUserNameField.placeholder = BundleUtil.localizedString(forKey: "username")
        self.serverPasswordField.placeholder = BundleUtil.localizedString(forKey: "Password")
        
        if self.safeManager.isActivated || self.mdmSetup.isSafeBackupServerPreset() || isForcedBackup {
            // is already activated means is in change password mode or server is given by MDM
            // hide server config elements
            self.serverSwitchLabel.isHidden = true
            self.serverSwitch.isHidden = true
            self.serverField.isHidden = true
        }
        
        if self.safeManager.isActivated {
            // is in change paasword mode, use existing server
            let safeConfigManager = SafeConfigManager()
            self.customServer = safeConfigManager.getCustomServer()
            self.server = safeConfigManager.getServer()
            self.maxBackupBytes = safeConfigManager.getMaxBackupBytes()
            self.retentionDays = safeConfigManager.getRetentionDays()
        }
        
        if isForcedBackup == false {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(self.cancel))
        }
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.done))
    }
    
    //MARK: - Navigation
    
    @objc private func cancel() {
        if self.view.isUserInteractionEnabled {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    @objc private func done() {
        // is already activated means is in change password mode and server validation is not necessary
        if (!self.safeManager.isActivated && validateServer()) || self.safeManager.isActivated {
            if let password = validatedPassword() {
                if self.safeManager.isPasswordBad(password: password) {
                    UIAlertTemplate.showConfirm(owner: self, popOverSource: self.passwordField, title: BundleUtil.localizedString(forKey: "password_bad"), message: BundleUtil.localizedString(forKey: "password_bad_explain"), titleOk: BundleUtil.localizedString(forKey: "continue_anyway"), actionOk: { (action) in
                        self.activate(password: password)
                    }, titleCancel: BundleUtil.localizedString(forKey:"try_again"), actionCancel: { (action) in
                        self.passwordField.becomeFirstResponder()
                    })
                } else {
                    self.activate(password: password)
                }
            }
        }
    }
    
    private func activate(password: String) {
        self.view.isUserInteractionEnabled = false
        MBProgressHUD.showAdded(to: self.view, animated: true)

        let queue = DispatchQueue.global(qos: .userInitiated)
        queue.async {
            do {
                // is already activated means is in change password mode, deactivate safe and activate with new password
                if self.safeManager.isActivated {
                    self.safeManager.deactivate()
                }
                
                try self.safeManager.activate(identity: MyIdentityStore.shared().identity, password: password, customServer: self.customServer, server: self.server, maxBackupBytes: self.maxBackupBytes != nil ? NSNumber(integerLiteral: self.maxBackupBytes!) : nil, retentionDays: self.retentionDays != nil ? NSNumber(integerLiteral:self.retentionDays!) : nil)
                
                DispatchQueue.main.async {
                    if self.isForcedBackup {
                        self.dismiss(animated: true, completion: nil)
                    } else {
                        self.performSegue(withIdentifier: self.isOpenedFromIntro ? "SafeIntroPasswordDone" : "SafeSetupPasswordDone", sender: self)
                    }
                }
            } catch let error {
                DispatchQueue.main.async {
                    // isFordedBackup maybe we dismiss the view and show it again at the next app start
                    UIAlertTemplate.showAlert(owner: self, title: BundleUtil.localizedString(forKey: "safe_error_preparing"), message: error.localizedDescription)
                }
            }

            DispatchQueue.main.async {
                MBProgressHUD.hide(for: self.view, animated: true)
                self.view.isUserInteractionEnabled = true
            }
        }
    }
    
    private func validatedPassword() -> String? {
        if let password = self.passwordField.text {
            if let regExPattern = self.mdmSetup.safePasswordPattern() {
                do {
                    if try !SafeManager.isPasswordPatternValid(password: password, regExPattern: regExPattern) {
                        if let message = self.mdmSetup.safePasswordMessage() {
                            UIAlertTemplate.showAlert(owner: self, title: BundleUtil.localizedString(forKey: "Password"), message: message)
                        } else {
                            UIAlertTemplate.showAlert(owner: self, title: BundleUtil.localizedString(forKey: "Password"), message: BundleUtil.localizedString(forKey: "password_bad_guidelines"))
                        }
                        return nil
                    }
                }
                catch {
                    ValidationLogger.shared()?.logString("Threema Safe: Can't check safe password because regex is invalid")
                    UIAlertTemplate.showAlert(owner: self, title: BundleUtil.localizedString(forKey: "Password"), message: BundleUtil.localizedString(forKey: "password_bad_regex"))
                    return nil
                }
            } else {
                if password.count < kMinimumPasswordLength {
                    UIAlertTemplate.showAlert(owner: self, title: BundleUtil.localizedString(forKey: "password_too_short_title"), message: BundleUtil.localizedString(forKey: "password_too_short_message"))
                    return nil
                }
            }
            
            if let passwordAgain = self.passwordAgainField.text,
                !password.elementsEqual(passwordAgain) {
                
                UIAlertTemplate.showAlert(owner: self, title: BundleUtil.localizedString(forKey: "password_mismatch_title"), message: BundleUtil.localizedString(forKey: "password_mismatch_message"))
                return nil
            } else {
                return password
            }
        }
        
        return nil
    }

    private func validateServer() -> Bool {
        if self.mdmSetup.isSafeBackupServerPreset() {
            // server is given by MDM
            let mdmSetup = MDMSetup(setup: false)
            self.customServer = mdmSetup?.safeServerUrl()
            self.server = self.safeStore.composeSafeServerAuth(server: mdmSetup?.safeServerUrl(), user: mdmSetup?.safeServerUsername(), password: mdmSetup?.safeServerPassword())?.absoluteString
        }
        else if self.serverSwitch.isOn {
            // server is standard (Threema)
            self.customServer = nil
            self.server = nil
            self.maxBackupBytes = nil
            self.retentionDays = nil
        } else {
            // server is WebDAV
            let safeConfigManager = SafeConfigManager()
            let safeStore = SafeStore(safeConfigManager: SafeConfigManager(), serverApiConnector: ServerAPIConnector())
            
            if let customServer = self.serverField.text,
                let customServerUrl = safeStore.composeSafeServerAuth(server: customServer, user: self.serverUserNameField.text, password: self.serverPasswordField.text) {
                
                let safeManager = SafeManager(safeConfigManager: safeConfigManager, safeStore: safeStore, safeApiService: SafeApiService())
                let result = safeManager.testServer(serverUrl: customServerUrl)
                if let errorMessage = result.errorMessage {
                    UIAlertTemplate.showAlert(owner: self, title: BundleUtil.localizedString(forKey: "safe_test_server"), message: errorMessage)
                    return false
                } else {
                    self.customServer = customServer
                    self.server = customServerUrl.absoluteString
                    self.maxBackupBytes = result.maxBackupBytes
                    self.retentionDays = result.retentionDays
                }
            } else {
                UIAlertTemplate.showAlert(owner: self, title: BundleUtil.localizedString(forKey: "safe_test_server"), message: BundleUtil.localizedString(forKey: "safe_test_server_invalid_url"))
                return false
            }
        }
        return true
    }
    
    // MARK: - Table view data source
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if self.safeManager.isActivated || self.mdmSetup.isSafeBackupServerPreset() || isForcedBackup {
            return indexPath.section != 0 ? 0.0 : UITableView.automaticDimension
        } else {
            switch indexPath.section {
            case 1:
                if indexPath.row != 0 {
                    return self.serverSwitch.isOn ? 0.0 : UITableView.automaticDimension
                }
            case 2:
                return self.serverSwitch.isOn ? 0.0 : UITableView.automaticDimension
            default:
                return UITableView.automaticDimension
            }
        }
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return BundleUtil.localizedString(forKey: "safe_configure_choose_password_title")
        case 1:
            return !self.safeManager.isActivated && !self.mdmSetup.isSafeBackupServerPreset() && !isForcedBackup ? BundleUtil.localizedString(forKey: "safe_server_name") : nil
        case 2:
            if self.safeManager.isActivated {
                return nil
            } else {
                return !serverSwitch.isOn ? BundleUtil.localizedString(forKey: "safe_server_authentication") : nil
            }
        default:
           return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            if isForcedBackup {
                return BundleUtil.localizedString(forKey: "safe_configure_choose_password_mdm") + "\n\n" + BundleUtil.localizedString(forKey: "safe_configure_choose_password")
            } else {
                return BundleUtil.localizedString(forKey: "safe_configure_choose_password")
            }
        case 1:
            return !self.safeManager.isActivated && !self.mdmSetup.isSafeBackupServerPreset() && !isForcedBackup ? BundleUtil.localizedString(forKey: "safe_configure_server_explain") : nil
        case 2:
            return nil
        default:
            return nil
        }
    }
}

extension SafeSetupPasswordViewController {
    @IBAction func primaryActionTriggered(_ sender: UITextField, forEvent event: UIEvent) {
        if sender == self.passwordField {
            self.passwordAgainField.becomeFirstResponder()
        }
        else if sender == self.passwordAgainField && !self.serverSwitch.isOn {
            self.serverField.becomeFirstResponder()
        }
        else if sender == self.passwordAgainField && self.serverSwitch.isOn {
            done()
        }
        else if sender == self.serverField {
            self.serverUserNameField.becomeFirstResponder()
        }
        else if sender == self.serverUserNameField {
            self.serverPasswordField.becomeFirstResponder()
        }
        else if sender == self.serverPasswordField {
            done()
        }
    }

    @IBAction func changedServerSwitch(_ sender: UISwitch) {        
        self.serverField.isEnabled = !sender.isOn
        self.tableView.reloadData()
        if let currentText = self.serverField.text, currentText.count == 0 {
            self.serverField.text = "https://"
        }
        self.serverField.becomeFirstResponder()
    }
}

extension SafeSetupPasswordViewController {
    override func dismissKeyboard() {
        super.dismissKeyboard()
        
        passwordField.resignFirstResponder()
        passwordAgainField.resignFirstResponder()
        serverField.resignFirstResponder()
        serverUserNameField.resignFirstResponder()
        serverPasswordField.resignFirstResponder()
    }
}
