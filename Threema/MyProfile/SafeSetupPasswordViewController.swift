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
import MBProgressHUD
import ThreemaMacros
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
    var serverUser: String?
    var serverPassword: String?
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
            groupManager: BusinessInjector().groupManager
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
        
        passwordField.placeholder = #localize("Password")
        passwordAgainField.placeholder = #localize("password_again")
        serverSwitchLabel.text = #localize("safe_use_default_server")
        serverField.placeholder = "https://server.example.com"
        serverUserNameField.placeholder = #localize("username")
        serverPasswordField.placeholder = #localize("Password")
        
        passwordField.isHidden = (mdmSetup.safePassword() != nil)
        passwordAgainField.isHidden = (mdmSetup.safePassword() != nil)
        
        if safeManager.isActivated || mdmSetup.isSafeBackupServerPreset() || isForcedBackup {
            // is already activated means is in change password mode or server is given by MDM
            // hide server config elements
            serverSwitchLabel.isHidden = true
            serverSwitch.isHidden = true
            serverField.isHidden = true
        }
        
        if safeManager.isActivated {
            // is in change password mode, use existing server
            let safeConfigManager = SafeConfigManager()
            customServer = safeConfigManager.getCustomServer()
            serverUser = safeConfigManager.getServerUser()
            serverPassword = safeConfigManager.getServerPassword()
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !passwordField.isHidden {
            passwordField.becomeFirstResponder()
        }
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
            // TODO: (IOS-4577) Init view again, because Threema Safe could be changed in meantime
            let safeConfigManager = SafeConfigManager()
            customServer = safeConfigManager.getCustomServer()
            server = safeConfigManager.getServer()
            maxBackupBytes = safeConfigManager.getMaxBackupBytes()
            retentionDays = safeConfigManager.getRetentionDays()

            checkPasswordAndActivate()
            return
        }

        navigationItem.leftBarButtonItem?.isEnabled = false
        navigationItem.rightBarButtonItem?.isEnabled = false
        view.isUserInteractionEnabled = false
        MBProgressHUD.showAdded(to: view, animated: true)
        validateServer { success in
            // Is already activated means is in change password mode and server validation is not necessary
            if success, !self.safeManager.isActivated {
                DispatchQueue.main.async {
                    self.checkPasswordAndActivate()
                }
            }
            else {
                DispatchQueue.main.async {
                    MBProgressHUD.hide(for: self.view, animated: true)
                    self.navigationItem.leftBarButtonItem?.isEnabled = true
                    self.navigationItem.rightBarButtonItem?.isEnabled = true
                    self.view.isUserInteractionEnabled = true
                }
            }
        }
    }
    
    private func checkPasswordAndActivate() {
        guard mdmSetup.safePassword() == nil else {
            activate(safePassword: mdmSetup.safePassword())
            return
        }
        
        if let safePassword = validatedPassword() {
            if safeManager.isPasswordBad(password: safePassword) {
                UIAlertTemplate.showConfirm(
                    owner: self,
                    popOverSource: passwordField,
                    title: #localize("password_bad"),
                    message: #localize("password_bad_explain"),
                    titleOk: #localize("continue_anyway"),
                    actionOk: { _ in
                        self.activate(safePassword: safePassword)
                    },
                    titleCancel: #localize("try_again"),
                    actionCancel: { _ in
                        self.passwordField.becomeFirstResponder()
                        MBProgressHUD.hide(for: self.view, animated: true)
                        self.navigationItem.leftBarButtonItem?.isEnabled = true
                        self.navigationItem.rightBarButtonItem?.isEnabled = true
                        self.view.isUserInteractionEnabled = true
                    }
                )
            }
            else {
                activate(safePassword: safePassword)
            }
        }
        else {
            MBProgressHUD.hide(for: view, animated: true)
            navigationItem.leftBarButtonItem?.isEnabled = true
            navigationItem.rightBarButtonItem?.isEnabled = true
            view.isUserInteractionEnabled = true
        }
    }
    
    private func activate(safePassword: String) {
        navigationItem.leftBarButtonItem?.isEnabled = false
        navigationItem.rightBarButtonItem?.isEnabled = false
        view.isUserInteractionEnabled = false
        let queue = DispatchQueue.global(qos: .userInitiated)
        queue.async {
            // is already activated means is in change password mode, deactivate safe and activate with new password
            if self.safeManager.isActivated {
                self.safeManager.deactivate()
            }
            
            self.safeManager.activate(
                identity: MyIdentityStore.shared().identity,
                safePassword: safePassword,
                customServer: self.customServer,
                serverUser: self.serverUser,
                serverPassword: self.serverPassword,
                server: self.server,
                maxBackupBytes: self.maxBackupBytes != nil ? NSNumber(integerLiteral: self.maxBackupBytes!) : nil,
                retentionDays: self.retentionDays != nil ? NSNumber(integerLiteral: self.retentionDays!) : nil
            ) { error in
                if let safeError = error as? SafeManager.SafeError {
                    DDLogError("\(safeError.errorDescription ?? safeError.localizedDescription)")
                    DispatchQueue.main.async {
                        UIAlertTemplate.showAlert(
                            owner: self,
                            title: #localize("safe_error_preparing"),
                            message: safeError.errorDescription ?? safeError.localizedDescription
                        )
                    }
                }
                else if let error {
                    DispatchQueue.main.async {
                        UIAlertTemplate.showAlert(
                            owner: self,
                            title: #localize("safe_error_preparing"),
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
                    self.navigationItem.leftBarButtonItem?.isEnabled = true
                    self.navigationItem.rightBarButtonItem?.isEnabled = true
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
                                title: #localize("Password"),
                                message: message
                            )
                        }
                        else {
                            UIAlertTemplate.showAlert(
                                owner: self,
                                title: #localize("Password"),
                                message: #localize("password_bad_guidelines")
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
                        title: #localize("Password"),
                        message: String.localizedStringWithFormat(
                            #localize("password_bad_regex"),
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
                        title: #localize("password_too_short_title"),
                        message: #localize("password_too_short_message")
                    )
                    return nil
                }
            }
            
            if let passwordAgain = passwordAgainField.text,
               !password.elementsEqual(passwordAgain) {
                
                UIAlertTemplate.showAlert(
                    owner: self,
                    title: #localize("password_mismatch_title"),
                    message: #localize("password_mismatch_message")
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
            serverUser = mdmSetup?.safeServerUsername()
            serverPassword = mdmSetup?.safeServerPassword()
            server = customServer
            completion(true)
            return
        }
        else if serverSwitch.isOn {
            // server is standard (Threema)
            customServer = nil
            serverUser = nil
            serverPassword = nil
            server = nil
            maxBackupBytes = nil
            retentionDays = nil
            completion(true)
            return
        }
        else {
            // server is WebDAV
            let safeConfigManager = SafeConfigManager()
            let safeStore = SafeStore(
                safeConfigManager: SafeConfigManager(),
                serverApiConnector: ServerAPIConnector(),
                groupManager: BusinessInjector().groupManager
            )
            
            if let customServer = serverField.text, let customServerURL = URL(string: customServer) {

                let safeManager = SafeManager(
                    safeConfigManager: safeConfigManager,
                    safeStore: safeStore,
                    safeApiService: SafeApiService()
                )
                
                safeManager.testServer(
                    serverURL: customServerURL,
                    user: serverUserNameField.text,
                    password: serverPasswordField.text
                ) { errorMessage, maxBackupBytes, retentionDays in

                    if let errorMessage {
                        DispatchQueue.main.async {
                            UIAlertTemplate.showAlert(
                                owner: self,
                                title: #localize("safe_test_server"),
                                message: errorMessage
                            )
                        }
                        completion(false)
                        return
                    }
                    else {
                        self.customServer = customServer
                        self.serverUser = self.serverUserNameField.text
                        self.serverPassword = self.serverPasswordField.text
                        self.server = customServerURL.absoluteString
                        self.maxBackupBytes = maxBackupBytes
                        self.retentionDays = retentionDays
                        completion(true)
                        return
                    }
                }
            }
            else {
                UIAlertTemplate.showAlert(
                    owner: self,
                    title: #localize("safe_test_server"),
                    message: #localize("safe_test_server_invalid_url")
                )
                completion(false)
                return
            }
        }
    }
    
    // MARK: - Table view data source
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if safeManager.isActivated || mdmSetup.isSafeBackupServerPreset() || isForcedBackup {
            return indexPath.section != 0 ? 0.0 : UITableView.automaticDimension
        }
        else {
            switch indexPath.section {
            case 0:
                if mdmSetup.safePassword() != nil {
                    return 0.0
                }
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
            if mdmSetup.safePassword() != nil {
                return nil
            }
            return #localize("safe_configure_choose_password_title")
        case 1:
            return !safeManager.isActivated && !mdmSetup
                .isSafeBackupServerPreset() && !isForcedBackup ? #localize("safe_server_name") : nil
        case 2:
            if safeManager.isActivated {
                return nil
            }
            else {
                return !serverSwitch.isOn ? #localize("safe_server_authentication") : nil
            }
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            if mdmSetup.safePassword() != nil {
                return #localize("threema_safe_company_mdm_password_changed_title") + ".\n" +
                    #localize("safe_change_password_disabled") + "."
            }
            else if isForcedBackup {
                return #localize("safe_configure_choose_password_mdm") + "\n\n" +
                    #localize("safe_configure_choose_password")
            }
            else {
                return #localize("safe_configure_choose_password")
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
