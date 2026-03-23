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

import CocoaLumberjackSwift
import Keychain
import MBProgressHUD
import RemoteSecret
import RemoteSecretProtocol
import ThreemaEssentials
import ThreemaFramework
import ThreemaMacros
import UIKit

@objc protocol RestoreSafeViewControllerDelegate {
    func restoreSafeDone()
    func restoreSafeCancelled(showLocalDataInfo: Bool)
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
    
    // Restore just ID from Threema Safe, in case there is any data on this device
    @objc var restoreIdentityOnly = false
    var restoreIdentity: String?
    var restoreSafePassword: String?
    var restoreCustomServer: String?
    var restoreServer: String?
    var restoreServerUsername: String?
    var restoreServerPassword: String?
    
    private var activateSafeAnyway = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        hideKeyboardWhenTappedAround()
        
        titleLabel.text = String.localizedStringWithFormat(
            #localize("safe_restore"),
            TargetManager.localizedAppName
        )
        descriptionLabel.text = String.localizedStringWithFormat(
            #localize("safe_restore_enter_id"),
            TargetManager.localizedAppName
        )
        forgotIDButton.setTitle(#localize("safe_forgot_your_id"), for: .normal)
        forgotIDButton.setTitleColor(UIColor.tintColor, for: .normal)
        identityField.delegate = self
        identityField.placeholder = String.localizedStringWithFormat(
            #localize("safe_threema_id"),
            TargetManager.localizedAppName
        )
        identityField.threemaID = true
        identityField.accessibilityIdentifier = "RestoreSafeViewControllerIdentityTextField"
        expertOptionsButton.setTitle(#localize("safe_advanced_options"), for: .normal)

        cancelButton.setTitle(#localize("cancel"), for: .normal)
        okButton.setTitle(#localize("restore"), for: .normal)
        okButton.accessibilityIdentifier = "RestoreSafeViewControllerRestoreButton"
                
        // check MDM for Threema Safe restore
        let mdmSetup = MDMSetup()!
        if TargetManager.isBusinessApp {
            if !mdmSetup.isSafeBackupDisable() {
                activateSafeAnyway = true
            }
            
            if mdmSetup.isSafeRestoreServerPreset() {
                expertOptionsButton.isHidden = true
                
                restoreCustomServer = mdmSetup.safeServerURL()
                restoreServer = mdmSetup.safeServerURL()
                restoreServerUsername = mdmSetup.safeServerUsername()
                restoreServerPassword = mdmSetup.safeServerPassword()
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
                    restoreSafePassword = mdmSetup.safePassword()
                    
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
                alert.showAlert(String.localizedStringWithFormat(
                    #localize("invalid_threema_id"),
                    TargetManager.localizedAppName
                ))
                return false
            }
        }
        if restoreIdentityOnly {
            let alert = IntroQuestionViewHelper(parent: self) { _, answer in
                if answer == .yes {
                    self.performSegue(withIdentifier: "RestoreSafePassword", sender: nil)
                }
                else {
                    self.delegate?.restoreSafeCancelled(showLocalDataInfo: true)
                }
            }
            let message = String.localizedStringWithFormat(
                #localize("restore_option_safe_keep_data"),
                TargetManager.localizedAppName
            )
            alert.showConfirm(message, noButtonLabel: #localize("no"), yesButtonLabel: #localize("yes"))
            return false
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
            delegate?.restoreSafeCancelled(showLocalDataInfo: false)
        }
    }
    
    @objc func swipeAction(sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            delegate?.restoreSafeCancelled(showLocalDataInfo: false)
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
           let safePassword = restoreSafePasswordViewController.passwordField.text,
           let identity = identityField.text {

            restoreIdentity = identity
            restoreSafePassword = safePassword

            startRestore()
        }
    }
    
    func startRestore() {
        // start restore in timer to give activity indicator time to start
        view.isUserInteractionEnabled = false
        MBProgressHUD.showAdded(to: view, animated: true)
        
        guard let enteredIdentity = restoreIdentity, let enteredPassword = restoreSafePassword else {
            showAlert(for: SafeError.restoreError(.invalidInput))
            return
        }
        
        Task(priority: .userInitiated) {
            // We keep a separate log file for safe restores
            let logFile = LogManager.safeRestoreLogFile
            LogManager.deleteLogFile(logFile)
            LogManager.addFileLogger(logFile)
            DDLogNotice("[ThreemaSafe Restore] Restore started")
            
            do {
                // First, we download the safe backup and parse it
                let safeBackupDataDownloader = SafeBackupDataDownloader()
                let safeBackupData = try await safeBackupDataDownloader.getSafeBackupData(
                    identity: enteredIdentity,
                    safePassword: enteredPassword,
                    serverUser: restoreServerUsername,
                    serverPassword: restoreServerPassword,
                    server: restoreServer
                )
                
                DDLogNotice("[ThreemaSafe Restore] Preparing to initialize remote secret")
                
                // To be able to restore the backup, we first need to initialize remote secret. For this we need to
                // extract some info from the backup already
                
                guard let clientKeyString = safeBackupData.user?.privatekey,
                      let clientKey = Data(base64Encoded: clientKeyString) else {
                    DDLogError("[ThreemaSafe Restore] Failed to extract and encode client key from backup")
                    throw SafeError.RestoreError.invalidClientKey
                }
                
                // Prepare identity store
                DDLogNotice("[ThreemaSafe Restore] Restoring identity store with backup data")
                let myIdentityStore = MyIdentityStore.shared()
                do {
                    // Fill in info from backup to identity store
                    try await myIdentityStore.restoreFromBackup(
                        identity: enteredIdentity,
                        clientKey: clientKey
                    )
                    
                    // Fetch server group and other stuff
                    let serverAPIConnector = ServerAPIConnector()
                    try await serverAPIConnector.update(myIdentityStore: myIdentityStore)
                }
                catch {
                    DDLogError(
                        "[ThreemaSafe Restore] Failed to restore identity store from backup with error: \(error)"
                    )
                    throw error
                }

                let setupApp = SetupApp(
                    delegate: self,
                    licenseStore: LicenseStore.shared(),
                    myIdentityStore: MyIdentityStore.shared(),
                    mdmSetup: MDMSetup(),
                    hasPreexistingData: restoreIdentityOnly
                )

                var remoteSecretAndKeychain: RemoteSecretAndKeychainObjC

                do {
                    guard let rs = try await setupApp.setupRemoteSecretAndKeychain() else {
                        throw SafeError.restoreError(.remoteSecretError)
                    }
                    
                    remoteSecretAndKeychain = rs
                }
                catch {
                    DDLogError(
                        "[ThreemaSafe Restore] Failed to setup remote secret with error: \(error)"
                    )
                    throw SafeError.restoreError(.remoteSecretError)
                }

                try await SetupApp
                    .runDatabaseMigrationIfNeeded(remoteSecretAndKeychain: remoteSecretAndKeychain)
                try await SetupApp.runAppMigrationIsNeeded()

                // Use business to restore other Threema Safe data
                let business = try AppLaunchManager.shared.business(forBackgroundProcess: false)

                DDLogNotice("[ThreemaSafe Restore] Beginning ThreemaSafe restore")

                let safeConfigManager = SafeConfigManager()
                let safeStore = SafeStore(
                    safeConfigManager: safeConfigManager,
                    serverApiConnector: ServerAPIConnector(),
                    groupManager: business.groupManager,
                    myIdentityStore: myIdentityStore
                )
                
                let safeManager = SafeManager(
                    safeConfigManager: safeConfigManager,
                    safeStore: safeStore,
                    safeApiService: SafeApiService()
                )
                
                try await safeManager.startRestore(
                    safeBackupData: safeBackupData,
                    onlyIdentity: restoreIdentityOnly
                )
                
                // Immediately activate Safe
                // In general we don't active Safe if we restore with existing data, because this would immediately
                // override the existing Safe backup. (Otherwise this might lead to unexpected behavior, if for some
                // reasons, the data backup actually missed some/all of the user data as experienced by the developer
                // before)
                if !restoreIdentityOnly || activateSafeAnyway {
                    DDLogNotice("[ThreemaSafe Restore] Activating ThreemaSafe")
                    try await safeManager.activate(
                        identity: enteredIdentity,
                        safePassword: enteredPassword,
                        customServer: restoreCustomServer,
                        serverUser: restoreServerUsername,
                        serverPassword: restoreServerPassword,
                        server: restoreServer,
                        maxBackupBytes: nil,
                        retentionDays: nil
                    )
                }
                else {
                    // Show Threema Safe-Intro
                    business.userSettings.safeIntroShown = false
                    // Trigger backup
                    NotificationCenter.default.post(
                        name: NSNotification.Name(kSafeBackupTrigger),
                        object: nil
                    )
                }
                
                MBProgressHUD.hide(for: self.view, animated: true)
                self.view.isUserInteractionEnabled = true
                
                DDLogNotice("[ThreemaSafe Restore] Restoring ThreemaSafe done")
                
                LogManager.removeFileLogger(logFile)
                delegate?.restoreSafeDone()
            }
            catch {
                DDLogError("[ThreemaSafe Restore] Error: \(error)")
                showAlert(for: error)
            }
        }
    }
    
    // MARK: - Private helper
    
    @MainActor
    private func showAlert(for error: Error) {
        let title = #localize("safe_restore_failed")
        let message: String =
            if let safeError = error as? SafeError {
                safeError.description
            }
            else {
                error.localizedDescription
            }
        DDLogError("[ThremaSafe Restore] Error restoring safe: [\(message)]")
        let alert = IntroQuestionViewHelper(parent: self) { [weak self] _, _ in
            if let safeError = error as? SafeError.RestoreError {
                self?.delegate?.restoreSafeCancelled(showLocalDataInfo: false)
            }
        }
        
        MBProgressHUD.hide(for: view, animated: true)
        view.isUserInteractionEnabled = true
        alert.showAlert(message, title: title)
    }
}

extension RestoreSafeViewController {
    override func dismissKeyboard() {
        super.dismissKeyboard()
        
        identityField.resignFirstResponder()
    }
}

// MARK: - SetupAppDelegate

extension RestoreSafeViewController: SetupAppDelegate {
    func encryptedDataDetected() {
        assertionFailure("Should not be reached")
    }
    
    func mismatchCancelled() {
        delegate?.restoreSafeCancelled(showLocalDataInfo: false)
    }
}
