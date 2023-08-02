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

import MBProgressHUD
import UIKit

class SafeSetupPasswordViewController: ThemedTableViewController {
    
    @IBOutlet var passwordField: UITextField!
    @IBOutlet var passwordAgainField: UITextField!
    @IBOutlet var serverSwitchLabel: UILabel!
    @IBOutlet var serverSwitch: UISwitch!
    @IBOutlet var serverField: UITextField!
    @IBOutlet var serverUserNameField: UITextField!
    @IBOutlet var serverPasswordField: UITextField!
    
    // TODO: (IOS-3251) Remove
    weak var launchModalDelegate: LaunchModalManagerDelegate?
    
    private var safeStore: SafeStore
    private var safeManager: SafeManager
    private var mdmSetup: MDMSetup
    
    var customServer: String?
    var server: String?
    var maxBackupBytes: Int?
    var retentionDays: Int?
    
    var isOpenedFromIntro = false
    @objc var isForcedBackup = false
    
    required init?(coder aDecoder: NSCoder) {
        let safeConfigManager = SafeConfigManager()
        self.safeStore = SafeStore(
            safeConfigManager: safeConfigManager,
            serverApiConnector: ServerAPIConnector(),
            groupManager: GroupManager()
        )
        self.safeManager = SafeManager(
            safeConfigManager: safeConfigManager,
            safeStore: safeStore,
            safeApiService: SafeApiService()
        )
        self.mdmSetup = MDMSetup(setup: false)
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        hideKeyboardWhenTappedAround()
        
        passwordField.placeholder = BundleUtil.localizedString(forKey: "Password")
        passwordAgainField.placeholder = BundleUtil.localizedString(forKey: "password_again")
        serverSwitchLabel.text = BundleUtil.localizedString(forKey: "safe_use_default_server")
        serverField.placeholder = "https://server.example.com"
        serverUserNameField.placeholder = BundleUtil.localizedString(forKey: "username")
        serverPasswordField.placeholder = BundleUtil.localizedString(forKey: "Password")
        
        if safeManager.isActivated || mdmSetup.isSafeBackupServerPreset() || isForcedBackup {
            // is already activated means is in change password mode or server is given by MDM
            // hide server config elements
            serverSwitchLabel.isHidden = true
            serverSwitch.isHidden = true
            serverField.isHidden = true
        }
        
        if safeManager.isActivated {
            // is in change paasword mode, use existing server
            let safeConfigManager = SafeConfigManager()
            customServer = safeConfigManager.getCustomServer()
            server = safeConfigManager.getServer()
            maxBackupBytes = safeConfigManager.getMaxBackupBytes()
            retentionDays = safeConfigManager.getRetentionDays()
        }
        
        if isForcedBackup == false {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .cancel,
                target: self,
                action: #selector(cancel)
            )
        }
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(done)
        )
    }

    // TODO: (IOS-3251) Remove
    override func viewDidDisappear(_ animated: Bool) {
        launchModalDelegate?.didDismiss()
    }
    
    // MARK: - Navigation
    
    @objc private func cancel() {
        if view.isUserInteractionEnabled {
            dismiss(animated: true, completion: nil)
        }
    }
    
    @objc private func done() {
        if safeManager.isActivated {
            checkPasswordAndActivate()
            return
        }
        
        validateServer { success in
            // Is already activated means is in change password mode and server validation is not necessary
            if success, !self.safeManager.isActivated {
                DispatchQueue.main.async {
                    self.checkPasswordAndActivate()
                }
            }
        }
    }
    
    private func checkPasswordAndActivate() {
        if let password = validatedPassword() {
            if safeManager.isPasswordBad(password: password) {
                UIAlertTemplate.showConfirm(
                    owner: self,
                    popOverSource: passwordField,
                    title: BundleUtil.localizedString(forKey: "password_bad"),
                    message: BundleUtil.localizedString(forKey: "password_bad_explain"),
                    titleOk: BundleUtil.localizedString(forKey: "continue_anyway"),
                    actionOk: { _ in
                        self.activate(password: password)
                    },
                    titleCancel: BundleUtil.localizedString(forKey: "try_again"),
                    actionCancel: { _ in
                        self.passwordField.becomeFirstResponder()
                    }
                )
            }
            else {
                activate(password: password)
            }
        }
    }
    
    private func activate(password: String) {
        view.isUserInteractionEnabled = false
        MBProgressHUD.showAdded(to: view, animated: true)

        let queue = DispatchQueue.global(qos: .userInitiated)
        queue.async {
            // is already activated means is in change password mode, deactivate safe and activate with new password
            if self.safeManager.isActivated {
                self.safeManager.deactivate()
            }
            
            self.safeManager.activate(
                identity: MyIdentityStore.shared().identity,
                password: password,
                customServer: self.customServer,
                server: self.server,
                maxBackupBytes: self.maxBackupBytes != nil ? NSNumber(integerLiteral: self.maxBackupBytes!) : nil,
                retentionDays: self.retentionDays != nil ? NSNumber(integerLiteral: self.retentionDays!) : nil
            ) { error in
                if let error {
                    DispatchQueue.main.async {
                        UIAlertTemplate.showAlert(
                            owner: self,
                            title: BundleUtil.localizedString(forKey: "safe_error_preparing"),
                            message: error.localizedDescription
                        )
                    }
                }
                else {
                    DispatchQueue.main.async {
                        if self.isForcedBackup {
                            // dismiss the view and show it again at the next app start
                            self.dismiss(animated: true, completion: nil)
                        }
                        else {
                            self.performSegue(
                                withIdentifier: self
                                    .isOpenedFromIntro ? "SafeIntroPasswordDone" : "SafeSetupPasswordDone",
                                sender: self
                            )
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    MBProgressHUD.hide(for: self.view, animated: true)
                    self.view.isUserInteractionEnabled = true
                }
            }
        }
    }
    
    private func validatedPassword() -> String? {
        if let password = passwordField.text {
            if let regExPattern = mdmSetup.safePasswordPattern() {
                do {
                    if try !SafeManager.isPasswordPatternValid(password: password, regExPattern: regExPattern) {
                        if let message = mdmSetup.safePasswordMessage() {
                            UIAlertTemplate.showAlert(
                                owner: self,
                                title: BundleUtil.localizedString(forKey: "Password"),
                                message: message
                            )
                        }
                        else {
                            UIAlertTemplate.showAlert(
                                owner: self,
                                title: BundleUtil.localizedString(forKey: "Password"),
                                message: BundleUtil.localizedString(forKey: "password_bad_guidelines")
                            )
                        }
                        return nil
                    }
                }
                catch {
                    ValidationLogger.shared()?
                        .logString("Threema Safe: Can't check safe password because regex is invalid")
                    UIAlertTemplate.showAlert(
                        owner: self,
                        title: BundleUtil.localizedString(forKey: "Password"),
                        message: String.localizedStringWithFormat(
                            BundleUtil.localizedString(forKey: "password_bad_regex"),
                            ThreemaApp.currentName
                        )
                    )
                    return nil
                }
            }
            else {
                if password.count < kMinimumPasswordLength {
                    UIAlertTemplate.showAlert(
                        owner: self,
                        title: BundleUtil.localizedString(forKey: "password_too_short_title"),
                        message: BundleUtil.localizedString(forKey: "password_too_short_message")
                    )
                    return nil
                }
            }
            
            if let passwordAgain = passwordAgainField.text,
               !password.elementsEqual(passwordAgain) {
                
                UIAlertTemplate.showAlert(
                    owner: self,
                    title: BundleUtil.localizedString(forKey: "password_mismatch_title"),
                    message: BundleUtil.localizedString(forKey: "password_mismatch_message")
                )
                return nil
            }
            else {
                return password
            }
        }
        
        return nil
    }

    private func validateServer(completion: @escaping (Bool) -> Void) {
        if mdmSetup.isSafeBackupServerPreset() {
            // server is given by MDM
            let mdmSetup = MDMSetup(setup: false)
            customServer = mdmSetup?.safeServerURL()
            server = safeStore.composeSafeServerAuth(
                server: mdmSetup?.safeServerURL(),
                user: mdmSetup?.safeServerUsername(),
                password: mdmSetup?.safeServerPassword()
            )?.absoluteString
        }
        else if serverSwitch.isOn {
            // server is standard (Threema)
            customServer = nil
            server = nil
            maxBackupBytes = nil
            retentionDays = nil
        }
        else {
            // server is WebDAV
            let safeConfigManager = SafeConfigManager()
            let safeStore = SafeStore(
                safeConfigManager: SafeConfigManager(),
                serverApiConnector: ServerAPIConnector(),
                groupManager: GroupManager()
            )
            
            if let customServer = serverField.text,
               let customServerURL = safeStore.composeSafeServerAuth(
                   server: customServer,
                   user: serverUserNameField.text,
                   password: serverPasswordField.text
               ) {
                
                let safeManager = SafeManager(
                    safeConfigManager: safeConfigManager,
                    safeStore: safeStore,
                    safeApiService: SafeApiService()
                )
                safeManager.testServer(serverURL: customServerURL) { errorMessage, maxBackupBytes, retentionDays in
                        
                    if let errorMessage {
                        DispatchQueue.main.async {
                            UIAlertTemplate.showAlert(
                                owner: self,
                                title: BundleUtil.localizedString(forKey: "safe_test_server"),
                                message: errorMessage
                            )
                        }
                        completion(false)
                        return
                    }
                    else {
                        self.customServer = customServer
                        self.server = customServerURL.absoluteString
                        self.maxBackupBytes = maxBackupBytes
                        self.retentionDays = retentionDays
                    }
                }
            }
            else {
                UIAlertTemplate.showAlert(
                    owner: self,
                    title: BundleUtil.localizedString(forKey: "safe_test_server"),
                    message: BundleUtil.localizedString(forKey: "safe_test_server_invalid_url")
                )
                completion(false)
                return
            }
        }
        completion(true)
    }
    
    // MARK: - Table view data source
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if safeManager.isActivated || mdmSetup.isSafeBackupServerPreset() || isForcedBackup {
            return indexPath.section != 0 ? 0.0 : UITableView.automaticDimension
        }
        else {
            switch indexPath.section {
            case 1:
                if indexPath.row != 0 {
                    return serverSwitch.isOn ? 0.0 : UITableView.automaticDimension
                }
            case 2:
                return serverSwitch.isOn ? 0.0 : UITableView.automaticDimension
            default:
                return UITableView.automaticDimension
            }
        }
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return BundleUtil.localizedString(forKey: "safe_configure_choose_password_title")
        case 1:
            return !safeManager.isActivated && !mdmSetup.isSafeBackupServerPreset() && !isForcedBackup ? BundleUtil
                .localizedString(forKey: "safe_server_name") : nil
        case 2:
            if safeManager.isActivated {
                return nil
            }
            else {
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
                return BundleUtil.localizedString(forKey: "safe_configure_choose_password_mdm") + "\n\n" + BundleUtil
                    .localizedString(forKey: "safe_configure_choose_password")
            }
            else {
                return BundleUtil.localizedString(forKey: "safe_configure_choose_password")
            }
        case 1:
            var explainText = "safe_configure_server_explain"
            if ThreemaApp.current == .onPrem {
                explainText = "safe_configure_server_explain_onprem"
            }
            return !safeManager.isActivated && !mdmSetup.isSafeBackupServerPreset() && !isForcedBackup ? BundleUtil
                .localizedString(forKey: explainText) : nil
        case 2:
            return nil
        default:
            return nil
        }
    }
    
    override func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        super.tableView(tableView, willDisplay: cell, forRowAt: indexPath)
    }
}

extension SafeSetupPasswordViewController {
    @IBAction func primaryActionTriggered(_ sender: UITextField, forEvent event: UIEvent) {
        if sender == passwordField {
            passwordAgainField.becomeFirstResponder()
        }
        else if sender == passwordAgainField, !serverSwitch.isOn {
            serverField.becomeFirstResponder()
        }
        else if sender == passwordAgainField, serverSwitch.isOn {
            done()
        }
        else if sender == serverField {
            serverUserNameField.becomeFirstResponder()
        }
        else if sender == serverUserNameField {
            serverPasswordField.becomeFirstResponder()
        }
        else if sender == serverPasswordField {
            done()
        }
    }

    @IBAction func changedServerSwitch(_ sender: UISwitch) {
        serverField.isEnabled = !sender.isOn
        tableView.reloadData()
        if let currentText = serverField.text, currentText.isEmpty {
            serverField.text = "https://"
        }
        serverField.becomeFirstResponder()
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
