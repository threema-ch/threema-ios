import CocoaLumberjackSwift
import ThreemaMacros
import UIKit

@objc protocol RestoreOptionBackupViewControllerDelegate {
    func restoreSafe()
    func restoreIdentityFromSafe()
    func restoreIdentity()
    func restoreCancelled()
}

final class RestoreOptionBackupViewController: IDCreationPageViewController {
    
    @IBOutlet var mainContent: UIStackView!
    
    @IBOutlet var content: UIStackView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var safeButton: SetupButton!
    @IBOutlet var safeLabel: UILabel!
    @IBOutlet var idButton: SetupButton!
    @IBOutlet var idLabel: UILabel!

    @IBOutlet var faqLinkLabel: ZSWTappableLabel!
    @IBOutlet var cancelButton: SetupButton!

    @objc weak var delegate: RestoreOptionBackupViewControllerDelegate?
    
    @objc var hasDataOnDevice = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        overrideUserInterfaceStyle = .dark

        hideKeyboardWhenTappedAround()
        
        // With a transparent background, the button is only accessible when the finger is positioned over the text
        cancelButton.backgroundColor = .black.withAlphaComponent(0.02)
        idButton.backgroundColor = .black.withAlphaComponent(0.02)

        titleLabel.text = hasDataOnDevice ? #localize("restore_option_id_title") : #localize("restore_option_title")
        descriptionLabel.text = #localize("restore_option_description")
        safeButton.setTitle(
            String
                .localizedStringWithFormat(#localize("safe_setup_backup_title"), TargetManager.localizedAppName),
            for: .normal
        )
        safeButton.accessibilityIdentifier = "RestoreOptionBackupViewControllerThreemaSafeButton"
        safeLabel.text = hasDataOnDevice ? String.localizedStringWithFormat(
            #localize("restore_option_safe_keep_data"),
            TargetManager.localizedAppName
        ) : #localize("restore_option_safe")
        
        idButton.setTitle(#localize("id_backup"), for: .normal)
        idLabel.text = hasDataOnDevice ? String.localizedStringWithFormat(
            #localize("restore_option_id_keep_data"),
            TargetManager.localizedAppName
        ) : #localize("restore_option_id")
        
        faqLinkLabel.tapDelegate = self
        let linkAttributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.tappableRegion: true,
            NSAttributedString.Key.foregroundColor: Colors
                .textWizardLink,
            NSAttributedString.Key.underlineStyle: NSUnderlineStyle
                .single.rawValue,
            .font: UIFont.systemFont(ofSize: 16),
        ]
        let faqLabelText = NSAttributedString(
            string: String.localizedStringWithFormat(
                #localize("backup_faq_link_text"),
                TargetManager.appName
            ),
            attributes: linkAttributes
        )
        
        faqLinkLabel.attributedText = faqLabelText

        cancelButton.setTitle(#localize("cancel"), for: .normal)

        // add swipe right for cancel action
        let gestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(swipeAction))
        gestureRecognizer.numberOfTouchesRequired = 1
        view.addGestureRecognizer(gestureRecognizer)
    }
}

extension RestoreOptionBackupViewController {

    @objc func swipeAction(sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            delegate?.restoreCancelled()
        }
    }

    @IBAction func touchDownButton(_ sender: UIButton, forEvent event: UIEvent) {
        if sender == safeButton {
            if hasDataOnDevice {
                delegate?.restoreIdentityFromSafe()
            }
            else {
                delegate?.restoreSafe()
            }
        }
        else if sender == idButton {
            delegate?.restoreIdentity()
        }
        else if sender == cancelButton {
            delegate?.restoreCancelled()
        }
    }
}

// MARK: - ZSWTappableLabelTapDelegate

extension RestoreOptionBackupViewController: ZSWTappableLabelTapDelegate {
    func tappableLabel(
        _ tappableLabel: ZSWTappableLabel,
        tappedAt idx: Int,
        withAttributes attributes: [NSAttributedString.Key: Any] = [:]
    ) {
        let backupFaqURL = ThreemaURLProvider.backupFAQ
        if UIApplication.shared.canOpenURL(backupFaqURL) {
            UIApplication.shared.open(backupFaqURL, options: [:], completionHandler: nil)
        }
    }
}
