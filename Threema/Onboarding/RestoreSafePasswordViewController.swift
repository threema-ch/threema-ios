import CocoaLumberjackSwift
import ThreemaFramework
import ThreemaMacros
import UIKit

final class RestoreSafePasswordViewController: IDCreationPageViewController {
    
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var passwordField: SetupTextField!
    @IBOutlet var cancelButton: SetupButton!
    @IBOutlet var okButton: SetupButton!
    @IBOutlet var forgotPasswordTappableLabel: ZSWTappableLabel!
    
    var keyboardResize: KeyboardResizeCenterY?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        overrideUserInterfaceStyle = .dark

        hideKeyboardWhenTappedAround()
        keyboardResize = KeyboardResizeCenterY(parent: view, resize: mainContentView)

        descriptionLabel.text = String.localizedStringWithFormat(
            #localize("safe_enter_password"),
            TargetManager.localizedAppName
        )
        passwordField.delegate = self
        passwordField.placeholder = #localize("Password")
        passwordField.accessibilityIdentifier = "RestoreSafePasswordViewControllerPasswordTextfield"
        passwordField.becomeFirstResponder()
        cancelButton.setTitle(#localize("cancel"), for: .normal)
        okButton.setTitle(#localize("ok"), for: .normal)
        okButton.accessibilityIdentifier = "RestoreSafePasswordViewControllerOkButton"

        forgotPasswordTappableLabel.tapDelegate = self
        let linkAttributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.tappableRegion: true,
            NSAttributedString.Key.foregroundColor: Colors
                .textWizardLink,
            NSAttributedString.Key.underlineStyle: NSUnderlineStyle
                .single.rawValue,
            .font: UIFont.systemFont(ofSize: 16),
        ]
        
        let faqLabelText = NSAttributedString(
            string: #localize("restore_option_help_link_text"),
            attributes: linkAttributes
        )
        forgotPasswordTappableLabel.attributedText = faqLabelText
        
        refreshView()
    }

    private func refreshView() {
        if let password = passwordField.text,
           password.count >= 8 {
            
            okButton.deactivated = false
        }
        else {
            okButton.deactivated = true
        }
    }
}

// MARK: - SetupTextFieldDelegate

extension RestoreSafePasswordViewController: SetupTextFieldDelegate {
    func editingChangedTextField(_ sender: SetupTextField, forEvent event: UIEvent) {
        refreshView()
    }
    
    func primaryActionTriggered(_ sender: SetupTextField, forEvent event: UIEvent) {
        performSegue(withIdentifier: "okSafePassword", sender: sender)
    }
}

extension RestoreSafePasswordViewController {
    override func dismissKeyboard() {
        super.dismissKeyboard()
        
        passwordField.resignFirstResponder()
    }
}

// MARK: - ZSWTappableLabelTapDelegate

extension RestoreSafePasswordViewController: ZSWTappableLabelTapDelegate {
    func tappableLabel(
        _ tappableLabel: ZSWTappableLabel,
        tappedAt idx: Int,
        withAttributes attributes: [NSAttributedString.Key: Any] = [:]
    ) {
        let url = ThreemaURLProvider.resetSafePassword
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}
