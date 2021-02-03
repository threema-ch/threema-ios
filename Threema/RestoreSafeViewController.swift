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
import CocoaLumberjackSwift
import MBProgressHUD

@objc protocol RestoreSafeViewControllerDelegate {
    func restoreSafeDone();
    func restoreSafeCancelled();
}

class RestoreSafeViewController: IDCreationPageViewController, UITextFieldDelegate {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var forgotIdButton: UIButton!
    @IBOutlet weak var identityField: SetupTextField!
    @IBOutlet weak var expertOptionsButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var okButton: SetupButton!

    @objc weak var delegate: RestoreSafeViewControllerDelegate?
    
    //restore just ID from Threems Safe, in case there is any data on this device
    @objc var restoreIdentityOnly: Bool = false
    var restoreIdentity: String?
    var restorePassword: String?
    var restoreCustomServer: String?
    var restoreServer: String?
    var restoreServerUsername: String?
    var restoreServerPassword: String?
    
    private var activateSafeAnyway: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()

        self.hideKeyboardWhenTappedAround()
        
        self.titleLabel.text = NSLocalizedString("safe_restore", comment: "")
        self.descriptionLabel.text = NSLocalizedString("safe_restore_enter_id", comment: "")
        self.forgotIdButton.setTitle(NSLocalizedString("safe_forgot_your_id", comment: ""), for: .normal)
        self.identityField.delegate = self
        self.identityField.placeholder = NSLocalizedString("safe_threema_id", comment: "")
        self.expertOptionsButton.setTitle(NSLocalizedString("safe_advanced_options", comment: ""), for: .normal)

        self.cancelButton.setTitle(NSLocalizedString("cancel", comment: ""), for: .normal)
        self.okButton.setTitle(NSLocalizedString("restore", comment: ""), for: .normal)
        
        self.forgotIdButton.setTitleColor(Colors.mainThemeDark(), for: .normal)
        
        //check MDM for Threema Safe restore
        let mdmSetup = MDMSetup(setup: true)!
        if mdmSetup.isManaged() {
            if !mdmSetup.isSafeBackupDisable() {
                self.activateSafeAnyway = true
            }
            
            if mdmSetup.isSafeRestoreServerPreset() {
                self.expertOptionsButton.isHidden = true
                
                let safeConfigManager = SafeConfigManager()
                let safeStore = SafeStore(safeConfigManager: safeConfigManager, serverApiConnector: ServerAPIConnector())

                self.restoreCustomServer = mdmSetup.safeServerUrl()
                self.restoreServer =  safeStore.composeSafeServerAuth(server: mdmSetup.safeServerUrl(), user: mdmSetup.safeServerUsername(), password: mdmSetup.safeServerPassword())?.absoluteString
            }
            
            if mdmSetup.isSafeRestoreForce() {
                self.restoreIdentity = mdmSetup.safeRestoreId()
                
                self.descriptionLabel.isHidden = true
                self.forgotIdButton.isHidden = true
                self.expertOptionsButton.isHidden = true
                self.cancelButton.isHidden = true
                
                self.okButton.removeConstraint(self.okButton.constraints[0])
                self.okButton.addConstraint(NSLayoutConstraint(item: self.okButton!, attribute: NSLayoutConstraint.Attribute.width, relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil, attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1.0, constant: 280.0))
                
                self.identityField.isUserInteractionEnabled = false
                self.identityField.alpha = 0.5
                self.identityField.text = self.restoreIdentity
                
                if mdmSetup.isSafeRestorePasswordPreset() {
                    self.restorePassword = mdmSetup.safePassword()
                    
                    self.okButton.isHidden = true
                    
                    self.startRestore()
                }
            } else {
                //add swipe right for cancel action
                let gestureRecognizer = UISwipeGestureRecognizer(target: self, action:#selector(swipeAction))
                gestureRecognizer.numberOfTouchesRequired = 1
                self.view.addGestureRecognizer(gestureRecognizer)
            }
        } else {
            //add swipe right for cancel action
            let gestureRecognizer = UISwipeGestureRecognizer(target: self, action:#selector(swipeAction))
            gestureRecognizer.numberOfTouchesRequired = 1
            self.view.addGestureRecognizer(gestureRecognizer)
        }
    }
    
    //MARK: - Navigation
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "RestoreSafePassword" {
            guard let identity = self.identityField.text, identity.count == 8 else {
                let alert = IntroQuestionViewHelper(parent: self, onAnswer: nil)
                alert.showAlert(BundleUtil.localizedString(forKey: "invalid_threema_id"))
                return false
            }
        }
        
        return true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        self.mainContentView.isHidden = true

        if let safeServerViewController = segue.destination as? SafeServerViewController {
            safeServerViewController.isServerForRestore = true
            safeServerViewController.customServer = self.restoreCustomServer
            safeServerViewController.server = self.restoreServer
            safeServerViewController.serverUsername = self.restoreServerUsername
            safeServerViewController.serverPassword = self.restoreServerPassword
        }
    }
}

extension RestoreSafeViewController: SetupTextFieldDelegate {
    func editingChangedTextField(_ sender: SetupTextField, forEvent event: UIEvent) { }
    
    func primaryActionTriggered(_ sender: SetupTextField, forEvent event: UIEvent) {
        self.performSegue(withIdentifier: "RestoreSafePassword", sender: sender)
    }
}

extension RestoreSafeViewController {
    @IBAction func touchDownButton(_ sender: UIButton, forEvent event: UIEvent) {
        if sender == cancelButton {
            self.delegate?.restoreSafeCancelled()
        }
    }
    
    @objc func swipeAction(sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            self.delegate?.restoreSafeCancelled()
        }
    }
    
    @IBAction func cancelSafeForgotId(_ segue: UIStoryboardSegue) {
        self.mainContentView.isHidden = false
    }
    
    @IBAction func okSafeForgotId(_ segue: UIStoryboardSegue) {
        guard let restoreSafeForgotIdViewController = segue.source as? RestoreSafeForgotIdViewController else {
            return
        }
        self.identityField.text = restoreSafeForgotIdViewController.selectedIdentity
        self.mainContentView.isHidden = false
    }
    
    @IBAction func cancelRestoreSafeServer(_ segue: UIStoryboardSegue) {
        self.mainContentView.isHidden = false
    }

    @IBAction func okRestoreSafeServer(_ segue: UIStoryboardSegue) {
        guard let safeServerViewController = segue.source as? SafeServerViewController else {
            return
        }
        
        self.mainContentView.isHidden = false
        
        self.restoreCustomServer = safeServerViewController.customServer
        self.restoreServer = safeServerViewController.server
        self.restoreServerUsername = safeServerViewController.serverUsername
        self.restoreServerPassword = safeServerViewController.serverPassword
    }
    
    @IBAction func cancelSafePassword(_ segue: UIStoryboardSegue) {
        self.mainContentView.isHidden = false
    }

    @IBAction func okSafePassword(_ segue: UIStoryboardSegue) {
        self.mainContentView.isHidden = false

        if let restoreSafePasswordViewController = segue.source as? RestoreSafePasswordViewController,
            let password = restoreSafePasswordViewController.passwordField.text,
            let identity = self.identityField.text {

            self.restoreIdentity = identity
            self.restorePassword = password
            
            self.startRestore()
        }
    }
    
    func startRestore() {
        // start restore in timer to give activity indicator time to start
        self.view.isUserInteractionEnabled = false
        MBProgressHUD.showAdded(to: self.view, animated: true)
        
        Timer.scheduledTimer(timeInterval: TimeInterval(0.3), target: self, selector: #selector(self.restore), userInfo: nil, repeats: false)
    }
    
    @objc func restore() {
        
        let logFile = FileUtility.appDocumentsDirectory?.appendingPathComponent("safe-restore.log")
        LogManager.deleteLogFile(logFile)
        LogManager.addFileLogger(logFile)
        DDLogNotice("Threema Safe restore started")

        let safeConfigManager = SafeConfigManager()
        let safeStore = SafeStore(safeConfigManager: safeConfigManager, serverApiConnector: ServerAPIConnector())
        let safeManager = SafeManager(safeConfigManager: safeConfigManager, safeStore: safeStore, safeApiService: SafeApiService())

        safeManager.startRestore(identity: self.restoreIdentity!, password: self.restorePassword!, customServer: self.restoreCustomServer, server: self.restoreServer, restoreIdentityOnly: self.restoreIdentityOnly, activateSafeAnyway: self.activateSafeAnyway, completionHandler: { (error) in
            
            DispatchQueue.main.async {
                MBProgressHUD.hide(for: self.view, animated: true)
                self.view.isUserInteractionEnabled = true
                
                if let error = error {
                    switch error {
                    case .restoreError(let message):
                        DDLogError(message)
                        let alert = IntroQuestionViewHelper(parent: self, onAnswer: { (sender, answer) in
                            self.delegate?.restoreSafeDone()
                        })
                        alert.showAlert(message, title: BundleUtil.localizedString(forKey: "safe_restore_failed"))
                    case .restoreFailed(let message):
                        DDLogError(message)
                        let alert = IntroQuestionViewHelper(parent: self, onAnswer: nil)
                        alert.showAlert(message, title: BundleUtil.localizedString(forKey: "safe_restore_failed"))
                    default: break
                    }
                } else {
                    DDLogNotice("Threema Safe restore successfully finished")
                    
                    self.delegate?.restoreSafeDone()
                }
                
                LogManager.removeFileLogger(logFile)
            }

        })
    }
}

extension RestoreSafeViewController {
    override func dismissKeyboard() {
        super.dismissKeyboard()
        
        identityField.resignFirstResponder()
    }
}
