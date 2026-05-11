import CocoaLumberjackSwift
import Keychain
import MBProgressHUD
import RemoteSecret
import RemoteSecretProtocol
import ThreemaEssentials
import ThreemaFramework
import ThreemaMacros
import UIKit

// MARK: - RestoreSafeViewControllerDelegate

@objc protocol RestoreSafeViewControllerDelegate {
    func restoreSafeDone()
    func restoreSafeCancelled(showLocalDataInfo: Bool)

    @objc optional func restoreSafeViewController(
        _ viewController: RestoreSafeViewController,
        didRequestRestoreWith identity: String,
        password: String
    )
}

// MARK: - RestoreSafeViewController

/// OC: This is from storyboard and used in objc as well.
final class RestoreSafeViewController: IDCreationPageViewController, UITextFieldDelegate {
    
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var forgotIDButton: UIButton!
    @IBOutlet var identityField: SetupTextField!
    @IBOutlet var expertOptionsButton: SetupButton!
    @IBOutlet var cancelButton: SetupButton!
    @IBOutlet var okButton: SetupButton!

    @objc weak var delegate: RestoreSafeViewControllerDelegate?
    
    private(set) lazy var restoreSafeManager = OnboardingRestoreSafeManager(
        delegate: self
    )
    
    /// Restore just ID from Threema Safe, in case there is any data on this device
    @objc var restoreIdentityOnly = false
    var restoreIdentity: String?
    var restoreSafePassword: String?
    var restoreCustomServer: String?
    var restoreServer: String?
    var restoreServerUsername: String?
    var restoreServerPassword: String?
    
    var activateSafeAnyway = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        /// With a transparent background, the button is only accessible when
        /// the finger is positioned over the text
        expertOptionsButton.backgroundColor = .black.withAlphaComponent(0.02)
        cancelButton.backgroundColor = .black.withAlphaComponent(0.02)

        overrideUserInterfaceStyle = .dark

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
        
        /// check MDM for Threema Safe restore
        let mdmSetup = restoreSafeManager.mdm.mdmSetup
        if restoreSafeManager.flavorService.isBusinessApp {
            if mdmSetup.existsMdmKey(MDM_KEY_SAFE_ENABLE), !mdmSetup.isSafeBackupDisable() {
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
                /// add swipe right for cancel action
                let gestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(swipeAction))
                gestureRecognizer.numberOfTouchesRequired = 1
                view.addGestureRecognizer(gestureRecognizer)
            }
        }
        else {
            /// add swipe right for cancel action
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
        /// start restore in timer to give activity indicator time to start
        view.isUserInteractionEnabled = false
        MBProgressHUD.showAdded(to: view, animated: true)
        
        guard let enteredIdentity = restoreIdentity, let enteredPassword = restoreSafePassword else {
            showAlert(for: SafeError.restoreError(.invalidInput))
            return
        }
        
        #if SCENE_DELEGATE_ROOT_COORDINATOR_DEVELOPMENT
            delegate?.restoreSafeViewController?(
                self,
                didRequestRestoreWith: enteredIdentity,
                password: enteredPassword
            )
            return
        #endif
        
        let logFile = LogManager.safeRestoreLogFile
        LogManager.deleteLogFile(logFile)
        LogManager.addFileLogger(logFile)
        
        restoreSafeManager.startRestore(
            with: OnboardingRestoreSafeInformation(
                identity: enteredIdentity,
                password: enteredPassword,
                server: OnboardingRestoreSafeInformation.Server(
                    user: restoreServerUsername,
                    password: restoreSafePassword,
                    url: restoreServer
                ),
                customServer: OnboardingRestoreSafeInformation.Server(
                    user: restoreServerUsername,
                    password: restoreServerPassword,
                    url: restoreCustomServer
                ),
                restoreIdentityOnly: restoreIdentityOnly,
                activateSafeAnyway: activateSafeAnyway
            )
        )
    }
    
    // MARK: - Private helper
    
    @MainActor
    func showAlert(for error: Error) {
        let title = #localize("safe_restore_failed")
        let message: String =
            if let safeError = error as? SafeError {
                safeError.description
            }
            else {
                error.localizedDescription
            }
        DDLogError("[ThreemaSafe Restore] Error restoring safe: [\(message)]")
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

// MARK: - OnboardingRestoreSafeManagerDelegate

extension RestoreSafeViewController: OnboardingRestoreSafeManagerDelegate {
    func didCompleteRestoreSafe() {
        MBProgressHUD.hide(for: view, animated: true)
        view.isUserInteractionEnabled = true
        
        delegate?.restoreSafeDone()
        
        LogManager.removeFileLogger(LogManager.safeRestoreLogFile)
    }
    
    func didFail(with error: any Error) {
        showAlert(for: error)
    }
}
