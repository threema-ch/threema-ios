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

@objc class SafeViewController: IDCreationPageViewController, IntroQuestionDelegate {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var passwordField: SetupTextField!
    @IBOutlet weak var passwordAgainField: SetupTextField!
    @IBOutlet weak var advancedOptionsButton: UIButton!
    
    var didShowAlert: Bool = false
    var didShowConfirm: Bool = false
    
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
        
        self.hideKeyboardWhenTappedAround()

        self.titleLabel.text = NSLocalizedString("safe_setup_backup_title", comment: "")
        self.descriptionLabel.text = NSLocalizedString("safe_setup_backup_description", comment: "")
        
        self.passwordField.delegate = self
        self.passwordField.placeholder = NSLocalizedString("Password", comment: "")
        self.passwordAgainField.delegate = self
        self.passwordAgainField.placeholder = NSLocalizedString("password_again", comment: "")
        self.advancedOptionsButton.setTitle(NSLocalizedString("safe_advanced_options", comment: ""), for: .normal)
        self.advancedOptionsButton.isHidden = self.mdmSetup.isSafeBackupForce()
        
        self.moreView.mainView = self.mainContentView
        self.moreView.moreButtonTitle = NSLocalizedString("more_information", comment: "")
        self.moreView.moreMessageText = NSLocalizedString("safe_enable_explain", comment: "")
        
        passwordAgainOffset = passwordAgainField.frame.origin.y
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        registerForKeyboardNotifications()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        unregisterForKeyboardNotifications()
    }

    //MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let safeServerViewController = segue.destination as? SafeServerViewController else {
            return
        }
        
        self.mainContentView.isHidden = true
        self.moreView.isHidden = true
        self.containerDelegate.hideControls(true)
        
        safeServerViewController.customServer = self.customServer
        safeServerViewController.server = self.server
        safeServerViewController.serverUsername = self.serverUsername
        safeServerViewController.serverPassword = self.serverPassword
    }
    
    private func validatedPassword() -> String? {
        
        if let password = self.passwordField.text {
            if let regExPattern = self.mdmSetup.safePasswordPattern() {
                do {
                    if try !SafeManager.isPasswordPatternValid(password: password, regExPattern: regExPattern) {
                        if let message = self.mdmSetup.safePasswordMessage() {
                            let alert = IntroQuestionViewHelper(parent: self, onAnswer: nil)
                            alert.showAlert(message, title: BundleUtil.localizedString(forKey: "Password"))
                        } else {
                            let alert = IntroQuestionViewHelper(parent: self, onAnswer: nil)
                            alert.showAlert(BundleUtil.localizedString(forKey: "password_bad_guidelines"), title: BundleUtil.localizedString(forKey: "Password"))
                        }
                        return nil
                    }
                }
                catch {
                    ValidationLogger.shared()?.logString("Threema Safe: Can't check safe password because regex is invalid")
                    let alert = IntroQuestionViewHelper(parent: self, onAnswer: nil)
                    alert.showAlert(BundleUtil.localizedString(forKey: "password_bad_regex"), title: BundleUtil.localizedString(forKey: "Password"))
                    return nil
                }
            } else {
                if password.count < kMinimumPasswordLength {
                    let alert = IntroQuestionViewHelper(parent: self, onAnswer: nil)
                    alert.showAlert(BundleUtil.localizedString(forKey: "password_too_short_message"), title: BundleUtil.localizedString(forKey: "password_too_short_title"))
                    return nil
                }
            }
            
            if let passwordAgain = self.passwordAgainField.text,
                !password.elementsEqual(passwordAgain) {
                
                let alert = IntroQuestionViewHelper(parent: self, onAnswer: nil)
                alert.showAlert(BundleUtil.localizedString(forKey: "password_mismatch_message"), title: BundleUtil.localizedString(forKey: "password_mismatch_title"))
                return nil
            } else {
                return password
            }
        }
        
        return nil
    }
    
    override func isInputValid() -> Bool {
        if self.moreView.isShown() {
            return false
        }
        
        if let password = self.passwordField.text,
            password.count <= 0 && !self.mdmSetup.isSafeBackupForce() && self.didShowAlert {
            
            return true
        } else if let password = self.passwordField.text,
            password.count > 0 && self.didShowConfirm {
            
            return true
        } else if let password = self.passwordField.text,
            password.count > 0 {

            //store custom safe backup server
            let safeConfigManager = SafeConfigManager()
            if let server = self.server {
                safeConfigManager.setServer(server)
                safeConfigManager.setCustomServer(self.customServer)
                safeConfigManager.setMaxBackupBytes(self.maxBackupBytes)
                safeConfigManager.setRetentionDays(self.retentionDays)
            } else {
                safeConfigManager.setServer(nil)
                safeConfigManager.setCustomServer(nil)
                safeConfigManager.setMaxBackupBytes(nil)
                safeConfigManager.setRetentionDays(nil)
            }

            if let validPassword = self.validatedPassword() {
                let safeConfigManager = SafeConfigManager()
                let safeStore = SafeStore(safeConfigManager: safeConfigManager, serverApiConnector: ServerAPIConnector())
                let safeManager = SafeManager(safeConfigManager: safeConfigManager, safeStore: safeStore, safeApiService: SafeApiService())
                if safeManager.isPasswordBad(password:validPassword) {
                    let alert = IntroQuestionViewHelper(parent: self) { (sender, answer) in
                        if answer == .yes {
                            self.didShowConfirm = true
                            //store password temp. just in memory for setup completion process
                            MyIdentityStore.shared()?.tempSafePassword = self.passwordField.text
                            self.containerDelegate.pageLeft()
                        } else {
                            self.passwordField.becomeFirstResponder()
                        }
                    }
                    alert.showConfirm(BundleUtil.localizedString(forKey: "password_bad_explain"), noButtonLabel: BundleUtil.localizedString(forKey: "try_again"), yesButtonLabel: BundleUtil.localizedString(forKey: "continue_anyway"))
                    
                    return false
                }
                
                //store password temp. just in memory for setup completion process
                MyIdentityStore.shared()?.tempSafePassword = validPassword
                return true;
            }
            
            return false
        } else if !self.mdmSetup.isSafeBackupForce() {
            let alert = IntroQuestionViewHelper(parent: self) { (sender, answer) in
                if answer == .yes {
                    self.didShowAlert = true;
                    self.containerDelegate.pageLeft()
                } else {
                    self.passwordField.becomeFirstResponder()
                }
            }
            alert.showConfirm(BundleUtil.localizedString(forKey: "safe_disable_confirm"))
            
        }
        
        return false
    }
}

extension SafeViewController {
    // private functions
    
    private func registerForKeyboardNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    private func unregisterForKeyboardNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func keyboardWillShow(notification: Notification) {
        if self.passwordField.isFirstResponder {
            if let info = notification.userInfo {
                let keyboardScreenEndFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
                let keyboardRectConverted = self.view.convert(keyboardScreenEndFrame, from: view.window)
                let diff = keyboardRectConverted.minY - passwordField.frame.midY - 32.0
                
                if diff < 21.0 {
                    passwordField.isHidden = false
                    passwordAgainField.isHidden = true
                }
            }
        }
        else if self.passwordAgainField.isFirstResponder {
            if let info = notification.userInfo {
                let keyboardScreenEndFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
                let keyboardRectConverted = self.view.convert(keyboardScreenEndFrame, from: view.window)
                let diff = keyboardRectConverted.minY - passwordAgainField.frame.midY - 32.0
                
                if diff < 0.0 {
                    passwordField.isHidden = true
                    passwordAgainField.isHidden = false
                    
                    var animationDuration = TimeInterval()
                    let options = Utils.animationOptions(for: notification, animationDuration: &animationDuration)
                    UIView.animate(withDuration: animationDuration, delay: 0, options: options, animations: {
                        self.passwordAgainField.frame = RectUtil.offsetRect(self.passwordAgainField.frame, byX: 0.0, byY: diff)
                    }) { (finished) in
                    }
                }
            }
        }
    }
    
    @objc private func keyboardWillHide(notification: Notification) {
        var animationDuration = TimeInterval()
        let options = Utils.animationOptions(for: notification, animationDuration: &animationDuration)
        
        UIView.animate(withDuration: animationDuration, delay: 0, options: options, animations: {
            self.passwordAgainField.frame = RectUtil.setYPositionOf(self.passwordAgainField.frame, y: self.passwordAgainOffset)
        }) { (finished) in
            if self.passwordAgainField.isFirstResponder == false {
                self.passwordField.isHidden = false
                self.passwordAgainField.isHidden = false
            } else {
                if let info = notification.userInfo {
                    let keyboardScreenEndFrame = (info[UIResponder.keyboardFrameBeginUserInfoKey] as! NSValue).cgRectValue
                    let keyboardRectConverted = self.view.convert(keyboardScreenEndFrame, from: self.view.window)
                    let diff = keyboardRectConverted.minY - self.passwordAgainField.frame.midY - 32.0
                    self.passwordField.isHidden = diff <= 0.0 ? true : false
                } else {
                    self.passwordField.isHidden = false
                }
                self.passwordAgainField.isHidden = false
            }
        }

    }
}

extension SafeViewController : SetupTextFieldDelegate {
    func editingChangedTextField(_ sender: SetupTextField, forEvent event: UIEvent) {
        self.didShowConfirm = false
    }
    
    func primaryActionTriggered(_ sender: SetupTextField, forEvent event: UIEvent) {
        if sender == self.passwordField {
            sender.resignFirstResponder()
            passwordAgainField.becomeFirstResponder()
        } else if sender == self.passwordAgainField {
            sender.resignFirstResponder()
        }
    }
}

extension SafeViewController {
    @IBAction func cancelSafeServer(_ segue: UIStoryboardSegue) {
        self.mainContentView.isHidden = false
        self.moreView.isHidden = false
        self.containerDelegate.hideControls(false)
    }

    @IBAction func okSafeServer(_ segue: UIStoryboardSegue) {
        guard let safeServerViewController = segue.source as? SafeServerViewController else {
            return
        }
        
        self.didShowConfirm = false
        
        self.mainContentView.isHidden = false
        self.moreView.isHidden = false
        self.containerDelegate.hideControls(false)
        
        self.customServer = safeServerViewController.customServer
        self.server = safeServerViewController.server
        self.serverUsername = safeServerViewController.serverUsername
        self.serverPassword = safeServerViewController.serverPassword
        self.maxBackupBytes = safeServerViewController.maxBackupBytes
        self.retentionDays = safeServerViewController.retentionDays
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
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
        view.resignFirstResponder()
    }
}
