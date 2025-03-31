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

import ThreemaMacros
import UIKit

@objc class SafeViewController: IDCreationPageViewController, IntroQuestionDelegate {
    
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var passwordField: SetupTextField!
    @IBOutlet var passwordAgainField: SetupTextField!
    @IBOutlet var advancedOptionsButton: UIButton!
    
    var didShowAlert = false
    var didShowConfirm = false
    
    var customServer: String?
    var server: String?
    var serverUsername: String?
    var serverPassword: String?
    var maxBackupBytes: Int?
    var retentionDays: Int?
    
    var passwordAgainOffset: CGFloat = 0
    
    var mdmSetup: MDMSetup
    
    required init?(coder aDecoder: NSCoder) {
        self.mdmSetup = MDMSetup(setup: true)

        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        hideKeyboardWhenTappedAround()

        titleLabel.text = #localize("safe_setup_backup_title")
        descriptionLabel.text = #localize("safe_setup_backup_description")
        
        passwordField.delegate = self
        passwordField.placeholder = #localize("Password")
        passwordAgainField.delegate = self
        passwordAgainField.placeholder = #localize("password_again")
        advancedOptionsButton.setTitle(#localize("safe_advanced_options"), for: .normal)
        advancedOptionsButton.isHidden = mdmSetup.isSafeBackupForce() || mdmSetup.isSafeBackupServerPreset()
        
        moreView.mainView = mainContentView
        moreView.moreButtonTitle = #localize("more_information")
        moreView.moreMessageText = #localize("safe_enable_explain")
        
        passwordAgainOffset = passwordAgainField.frame.origin.y
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        registerForKeyboardNotifications()
        UIAccessibility.post(notification: .screenChanged, argument: titleLabel)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        unregisterForKeyboardNotifications()
    }

    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let safeServerViewController = segue.destination as? SafeServerViewController else {
            return
        }
        
        mainContentView.isHidden = true
        moreView.isHidden = true
        containerDelegate.hideControls(true)
        
        safeServerViewController.customServer = customServer
        safeServerViewController.server = server
        safeServerViewController.serverUsername = serverUsername
        safeServerViewController.serverPassword = serverPassword
    }
    
    private func validatedPassword() -> String? {
        
        if let password = passwordField.text {
            if let regExPattern = mdmSetup.safePasswordPattern() {
                do {
                    if try !SafeManager.isPasswordPatternValid(password: password, regExPattern: regExPattern) {
                        if let message = mdmSetup.safePasswordMessage() {
                            let alert = IntroQuestionViewHelper(parent: self, onAnswer: nil)
                            alert.showAlert(message, title: #localize("Password"))
                        }
                        else {
                            let alert = IntroQuestionViewHelper(parent: self, onAnswer: nil)
                            alert.showAlert(
                                #localize("password_bad_guidelines"),
                                title: #localize("Password")
                            )
                        }
                        return nil
                    }
                }
                catch {
                    ValidationLogger.shared()?
                        .logString("Threema Safe: Can't check safe password because regex is invalid")
                    let alert = IntroQuestionViewHelper(parent: self, onAnswer: nil)
                    alert.showAlert(
                        String.localizedStringWithFormat(
                            #localize("password_bad_regex"),
                            TargetManager.appName
                        ),
                        title: #localize("Password")
                    )
                    return nil
                }
            }
            else {
                if password.count < kMinimumPasswordLength {
                    let alert = IntroQuestionViewHelper(parent: self, onAnswer: nil)
                    alert.showAlert(
                        #localize("password_too_short_message"),
                        title: #localize("password_too_short_title")
                    )
                    return nil
                }
            }
            
            if let passwordAgain = passwordAgainField.text,
               !password.elementsEqual(passwordAgain) {
                
                let alert = IntroQuestionViewHelper(parent: self, onAnswer: nil)
                alert.showAlert(
                    #localize("password_mismatch_message"),
                    title: #localize("password_mismatch_title")
                )
                return nil
            }
            else {
                return password
            }
        }
        
        return nil
    }
    
    override func isInputValid() -> Bool {
        if moreView.isShown() {
            return false
        }
        
        if let password = passwordField.text,
           password.count <= 0, !self.mdmSetup.isSafeBackupForce(), didShowAlert {
            
            return true
        }
        else if let password = passwordField.text,
                !password.isEmpty, didShowConfirm {
            
            return true
        }
        else if let password = passwordField.text,
                !password.isEmpty {

            // store custom safe backup server
            let safeConfigManager = SafeConfigManager()
            if let server {
                safeConfigManager.setServer(server)
                safeConfigManager.setCustomServer(customServer)
                safeConfigManager.setMaxBackupBytes(maxBackupBytes)
                safeConfigManager.setRetentionDays(retentionDays)
            }
            else {
                safeConfigManager.setServer(nil)
                safeConfigManager.setCustomServer(nil)
                safeConfigManager.setMaxBackupBytes(nil)
                safeConfigManager.setRetentionDays(nil)
            }

            if let validPassword = validatedPassword() {
                let safeConfigManager = SafeConfigManager()
                let safeStore = SafeStore(
                    safeConfigManager: safeConfigManager,
                    serverApiConnector: ServerAPIConnector(),
                    groupManager: BusinessInjector.ui.groupManager
                )
                let safeManager = SafeManager(
                    safeConfigManager: safeConfigManager,
                    safeStore: safeStore,
                    safeApiService: SafeApiService()
                )
                if safeManager.isPasswordBad(password: validPassword) {
                    let alert = IntroQuestionViewHelper(parent: self) { _, answer in
                        if answer == .yes {
                            self.didShowConfirm = true
                            // store password temp. just in memory for setup completion process
                            MyIdentityStore.shared()?.tempSafePassword = self.passwordField.text
                            self.containerDelegate.pageLeft()
                        }
                        else {
                            self.passwordField.becomeFirstResponder()
                        }
                    }
                    alert.showConfirm(
                        #localize("password_bad_explain"),
                        noButtonLabel: #localize("try_again"),
                        yesButtonLabel: #localize("continue_anyway")
                    )
                    
                    return false
                }
                
                // store password temp. just in memory for setup completion process
                MyIdentityStore.shared()?.tempSafePassword = validPassword
                return true
            }
            
            return false
        }
        else if !mdmSetup.isSafeBackupForce() {
            let alert = IntroQuestionViewHelper(parent: self) { _, answer in
                if answer != .yes {
                    self.didShowAlert = true
                    self.containerDelegate.pageLeft()
                }
                else {
                    self.passwordField.becomeFirstResponder()
                }
            }
            alert.showConfirm(
                #localize("safe_disable_confirm"),
                noButtonLabel: #localize("yes"),
                yesButtonLabel: #localize("no")
            )
        }
        
        return false
    }
}

extension SafeViewController {
    // private functions
    
    private func registerForKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    private func unregisterForKeyboardNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func keyboardWillShow(notification: Notification) {
        if passwordField.isFirstResponder {
            if let info = notification.userInfo {
                let keyboardScreenEndFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
                let keyboardRectConverted = view.convert(keyboardScreenEndFrame, from: view.window)
                let diff = keyboardRectConverted.minY - passwordField.frame.midY - 32.0
                
                if diff < 21.0 {
                    passwordField.isHidden = false
                    passwordAgainField.isHidden = true
                }
            }
        }
        else if passwordAgainField.isFirstResponder {
            if let info = notification.userInfo {
                let keyboardScreenEndFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
                let keyboardRectConverted = view.convert(keyboardScreenEndFrame, from: view.window)
                let diff = keyboardRectConverted.minY - passwordAgainField.frame.midY - 32.0
                
                if diff < 0.0 {
                    passwordField.isHidden = true
                    passwordAgainField.isHidden = false
                    
                    var animationDuration = TimeInterval()
                    let options = ThreemaUtilityObjC.animationOptions(
                        for: notification,
                        animationDuration: &animationDuration
                    )
                    UIView.animate(withDuration: animationDuration, delay: 0, options: options, animations: {
                        self.passwordAgainField.frame = RectUtil.offsetRect(
                            self.passwordAgainField.frame,
                            byX: 0.0,
                            byY: diff
                        )
                    }) { _ in
                    }
                }
            }
        }
    }
    
    @objc private func keyboardWillHide(notification: Notification) {
        var animationDuration = TimeInterval()
        let options = ThreemaUtilityObjC.animationOptions(for: notification, animationDuration: &animationDuration)
        
        UIView.animate(withDuration: animationDuration, delay: 0, options: options, animations: {
            self.passwordAgainField.frame = RectUtil.setYPositionOf(
                self.passwordAgainField.frame,
                y: self.passwordAgainOffset
            )
        }) { _ in
            if self.passwordAgainField.isFirstResponder == false {
                self.passwordField.isHidden = false
                self.passwordAgainField.isHidden = false
            }
            else {
                if let info = notification.userInfo {
                    let keyboardScreenEndFrame = (info[UIResponder.keyboardFrameBeginUserInfoKey] as! NSValue)
                        .cgRectValue
                    let keyboardRectConverted = self.view.convert(keyboardScreenEndFrame, from: self.view.window)
                    let diff = keyboardRectConverted.minY - self.passwordAgainField.frame.midY - 32.0
                    self.passwordField.isHidden = diff <= 0.0 ? true : false
                }
                else {
                    self.passwordField.isHidden = false
                }
                self.passwordAgainField.isHidden = false
            }
        }
    }
}

// MARK: - SetupTextFieldDelegate

extension SafeViewController: SetupTextFieldDelegate {
    func editingChangedTextField(_ sender: SetupTextField, forEvent event: UIEvent) {
        didShowConfirm = false
    }
    
    func primaryActionTriggered(_ sender: SetupTextField, forEvent event: UIEvent) {
        if sender == passwordField {
            sender.resignFirstResponder()
            passwordAgainField.becomeFirstResponder()
        }
        else if sender == passwordAgainField {
            sender.resignFirstResponder()
        }
    }
}

extension SafeViewController {
    @IBAction func cancelSafeServer(_ segue: UIStoryboardSegue) {
        mainContentView.isHidden = false
        moreView.isHidden = false
        containerDelegate.hideControls(false)
    }

    @IBAction func okSafeServer(_ segue: UIStoryboardSegue) {
        guard let safeServerViewController = segue.source as? SafeServerViewController else {
            return
        }
        
        didShowConfirm = false
        
        mainContentView.isHidden = false
        moreView.isHidden = false
        containerDelegate.hideControls(false)
        
        customServer = safeServerViewController.customServer
        server = safeServerViewController.server
        serverUsername = safeServerViewController.serverUsername
        serverPassword = safeServerViewController.serverPassword
        maxBackupBytes = safeServerViewController.maxBackupBytes
        retentionDays = safeServerViewController.retentionDays
    }
}

extension SafeViewController {
    override func dismissKeyboard() {
        super.dismissKeyboard()
        
        passwordField.resignFirstResponder()
        passwordAgainField.resignFirstResponder()
    }
}

extension UIViewController {
    func hideKeyboardWhenTappedAround() {
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
        view.resignFirstResponder()
    }
}
