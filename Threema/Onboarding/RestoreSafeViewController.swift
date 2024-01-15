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
import UIKit

@objc protocol RestoreSafeViewControllerDelegate {
    func restoreSafeDone()
    func restoreSafeCancelled()
}

class RestoreSafeViewController: IDCreationPageViewController, UITextFieldDelegate {
    
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var forgotIDButton: UIButton!
    @IBOutlet var identityField: SetupTextField!
    @IBOutlet var expertOptionsButton: UIButton!
    @IBOutlet var cancelButton: UIButton!
    @IBOutlet var okButton: SetupButton!

    @objc weak var delegate: RestoreSafeViewControllerDelegate?
    
    // restore just ID from Threema Safe, in case there is any data on this device
    @objc var restoreIdentityOnly = false
    var restoreIdentity: String?
    var restorePassword: String?
    var restoreCustomServer: String?
    var restoreServer: String?
    var restoreServerUsername: String?
    var restoreServerPassword: String?
    
    private var activateSafeAnyway = false

    override func viewDidLoad() {
        super.viewDidLoad()

        hideKeyboardWhenTappedAround()
        
        titleLabel.text = BundleUtil.localizedString(forKey: "safe_restore")
        descriptionLabel.text = BundleUtil.localizedString(forKey: "safe_restore_enter_id")
        forgotIDButton.setTitle(BundleUtil.localizedString(forKey: "safe_forgot_your_id"), for: .normal)
        identityField.delegate = self
        identityField.placeholder = BundleUtil.localizedString(forKey: "safe_threema_id")
        identityField.threemaID = true
        identityField.accessibilityIdentifier = "RestoreSafeViewControllerIdentityTextField"
        expertOptionsButton.setTitle(BundleUtil.localizedString(forKey: "safe_advanced_options"), for: .normal)

        cancelButton.setTitle(BundleUtil.localizedString(forKey: "cancel"), for: .normal)
        okButton.setTitle(BundleUtil.localizedString(forKey: "restore"), for: .normal)
        okButton.accessibilityIdentifier = "RestoreSafeViewControllerRestoreButton"
        
        forgotIDButton.setTitleColor(Colors.primaryWizard, for: .normal)
        
        // check MDM for Threema Safe restore
        let mdmSetup = MDMSetup(setup: true)!
        if LicenseStore.shared().getRequiresLicenseKey() {
            if !mdmSetup.isSafeBackupDisable() {
                activateSafeAnyway = true
            }
            
            if mdmSetup.isSafeRestoreServerPreset() {
                expertOptionsButton.isHidden = true
                
                let safeConfigManager = SafeConfigManager()
                let safeStore = SafeStore(
                    safeConfigManager: safeConfigManager,
                    serverApiConnector: ServerAPIConnector(),
                    groupManager: GroupManager()
                )

                restoreCustomServer = mdmSetup.safeServerURL()
                restoreServer = safeStore.composeSafeServerAuth(
                    server: mdmSetup.safeServerURL(),
                    user: mdmSetup.safeServerUsername(),
                    password: mdmSetup.safeServerPassword()
                )?.absoluteString
            }
            
            if mdmSetup.isSafeRestoreForce() {
                restoreIdentity = mdmSetup.safeRestoreID()
                
                descriptionLabel.isHidden = true
                forgotIDButton.isHidden = true
                expertOptionsButton.isHidden = true
                cancelButton.isHidden = true
                
                okButton.removeConstraint(okButton.constraints[0])
                okButton.addConstraint(NSLayoutConstraint(
                    item: okButton!,
                    attribute: NSLayoutConstraint.Attribute.width,
                    relatedBy: NSLayoutConstraint.Relation.equal,
                    toItem: nil,
                    attribute: NSLayoutConstraint.Attribute.notAnAttribute,
                    multiplier: 1.0,
                    constant: 280.0
                ))
                
                identityField.isUserInteractionEnabled = false
                identityField.alpha = 0.5
                identityField.text = restoreIdentity
                
                if mdmSetup.isSafeRestorePasswordPreset() {
                    restorePassword = mdmSetup.safePassword()
                    
                    okButton.isHidden = true
                    
                    startRestore()
                }
            }
            else {
                // add swipe right for cancel action
                let gestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(swipeAction))
                gestureRecognizer.numberOfTouchesRequired = 1
                view.addGestureRecognizer(gestureRecognizer)
            }
        }
        else {
            // add swipe right for cancel action
            let gestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(swipeAction))
            gestureRecognizer.numberOfTouchesRequired = 1
            view.addGestureRecognizer(gestureRecognizer)
        }
    }
    
    // MARK: - Navigation
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "RestoreSafePassword" {
            guard let identity = identityField.text, identity.count == 8 else {
                let alert = IntroQuestionViewHelper(parent: self, onAnswer: nil)
                alert.showAlert(BundleUtil.localizedString(forKey: "invalid_threema_id"))
                return false
            }
        }
        
        return true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        mainContentView.isHidden = true

        if let safeServerViewController = segue.destination as? SafeServerViewController {
            safeServerViewController.isServerForRestore = true
            safeServerViewController.customServer = restoreCustomServer
            safeServerViewController.server = restoreServer
            safeServerViewController.serverUsername = restoreServerUsername
            safeServerViewController.serverPassword = restoreServerPassword
        }
    }
}

// MARK: - SetupTextFieldDelegate

extension RestoreSafeViewController: SetupTextFieldDelegate {
    func editingChangedTextField(_ sender: SetupTextField, forEvent event: UIEvent) { }
    
    func primaryActionTriggered(_ sender: SetupTextField, forEvent event: UIEvent) {
        performSegue(withIdentifier: "RestoreSafePassword", sender: sender)
    }
}

extension RestoreSafeViewController {
    @IBAction func touchDownButton(_ sender: UIButton, forEvent event: UIEvent) {
        if sender == cancelButton {
            delegate?.restoreSafeCancelled()
        }
    }
    
    @objc func swipeAction(sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            delegate?.restoreSafeCancelled()
        }
    }
    
    @IBAction func cancelSafeForgotID(_ segue: UIStoryboardSegue) {
        mainContentView.isHidden = false
    }
    
    @IBAction func okSafeForgotID(_ segue: UIStoryboardSegue) {
        guard let restoreSafeForgotIDViewController = segue.source as? RestoreSafeForgotIDViewController else {
            return
        }
        identityField.text = restoreSafeForgotIDViewController.selectedIdentity
        mainContentView.isHidden = false
    }
    
    @IBAction func cancelRestoreSafeServer(_ segue: UIStoryboardSegue) {
        mainContentView.isHidden = false
    }

    @IBAction func okRestoreSafeServer(_ segue: UIStoryboardSegue) {
        guard let safeServerViewController = segue.source as? SafeServerViewController else {
            return
        }
        
        mainContentView.isHidden = false
        
        restoreCustomServer = safeServerViewController.customServer
        restoreServer = safeServerViewController.server
        restoreServerUsername = safeServerViewController.serverUsername
        restoreServerPassword = safeServerViewController.serverPassword
    }
    
    @IBAction func cancelSafePassword(_ segue: UIStoryboardSegue) {
        mainContentView.isHidden = false
    }

    @IBAction func okSafePassword(_ segue: UIStoryboardSegue) {
        mainContentView.isHidden = false

        if let restoreSafePasswordViewController = segue.source as? RestoreSafePasswordViewController,
           let password = restoreSafePasswordViewController.passwordField.text,
           let identity = identityField.text {

            restoreIdentity = identity
            restorePassword = password
            
            startRestore()
        }
    }
    
    func startRestore() {
        // start restore in timer to give activity indicator time to start
        view.isUserInteractionEnabled = false
        MBProgressHUD.showAdded(to: view, animated: true)
        
        Timer.scheduledTimer(
            timeInterval: TimeInterval(0.3),
            target: self,
            selector: #selector(restore),
            userInfo: nil,
            repeats: false
        )
    }
    
    @objc func restore() {
        
        let logFile = LogManager.safeRestoreLogFile
        LogManager.deleteLogFile(logFile)
        LogManager.addFileLogger(logFile)
        DDLogNotice("Threema Safe restore started")

        let safeConfigManager = SafeConfigManager()
        let safeStore = SafeStore(
            safeConfigManager: safeConfigManager,
            serverApiConnector: ServerAPIConnector(),
            groupManager: GroupManager()
        )
        let safeManager = SafeManager(
            safeConfigManager: safeConfigManager,
            safeStore: safeStore,
            safeApiService: SafeApiService()
        )

        safeManager.startRestore(
            identity: restoreIdentity!,
            password: restorePassword!,
            customServer: restoreCustomServer,
            server: restoreServer,
            restoreIdentityOnly: restoreIdentityOnly,
            activateSafeAnyway: activateSafeAnyway,
            completionHandler: { error in
            
                DispatchQueue.main.async {
                    MBProgressHUD.hide(for: self.view, animated: true)
                    self.view.isUserInteractionEnabled = true
                
                    if let error {
                        switch error {
                        case let .restoreError(message):
                            DDLogError(message)
                            let alert = IntroQuestionViewHelper(parent: self, onAnswer: { _, _ in
                                self.delegate?.restoreSafeDone()
                            })
                            alert.showAlert(message, title: BundleUtil.localizedString(forKey: "safe_restore_failed"))
                        case let .restoreFailed(message):
                            DDLogError(message)
                            let alert = IntroQuestionViewHelper(parent: self, onAnswer: nil)
                            alert.showAlert(message, title: BundleUtil.localizedString(forKey: "safe_restore_failed"))
                        default: break
                        }
                    }
                    else {
                        DDLogNotice("Threema Safe restore successfully finished")
                    
                        self.delegate?.restoreSafeDone()
                    }
                
                    LogManager.removeFileLogger(logFile)
                }
            }
        )
    }
}

extension RestoreSafeViewController {
    override func dismissKeyboard() {
        super.dismissKeyboard()
        
        identityField.resignFirstResponder()
    }
}
