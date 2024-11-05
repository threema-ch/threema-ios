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
import ThreemaMacros
import UIKit

@objc protocol RestoreOptionBackupViewControllerDelegate {
    func restoreSafe()
    func restoreIdentityFromSafe()
    func restoreIdentity()
    func restoreCancelled()
}

class RestoreOptionBackupViewController: IDCreationPageViewController {
    
    @IBOutlet var mainContent: UIStackView!
    
    @IBOutlet var content: UIStackView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var safeButton: SetupButton!
    @IBOutlet var safeLabel: UILabel!
    @IBOutlet var idButton: SetupButton!
    @IBOutlet var idLabel: UILabel!

    @IBOutlet var faqLinkLabel: ZSWTappableLabel!
    @IBOutlet var cancelButton: UIButton!
    
    @objc weak var delegate: RestoreOptionBackupViewControllerDelegate?
    
    @objc var hasDataOnDevice = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        hideKeyboardWhenTappedAround()

        titleLabel.text = hasDataOnDevice ? #localize("restore_option_id_title") : BundleUtil
            .localizedString(forKey: "restore_option_title")
        descriptionLabel.text = #localize("restore_option_description")
        safeButton.setTitle("Threema Safe", for: .normal)
        safeButton.accessibilityIdentifier = "RestoreOptionBackupViewControllerThreemaSafeButton"
        safeLabel.text = hasDataOnDevice ? BundleUtil
            .localizedString(forKey: "restore_option_safe_keep_data") : BundleUtil
            .localizedString(forKey: "restore_option_safe")
        idButton.setTitle(#localize("id_backup"), for: .normal)
        idLabel.text = hasDataOnDevice ? #localize("restore_option_id_keep_data") : BundleUtil
            .localizedString(forKey: "restore_option_id")
        
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
                ThreemaApp.currentName
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
        let urlString = BundleUtil.object(forInfoDictionaryKey: "ThreemaBackupInfo") as! String
        guard let url = URL(string: urlString) else {
            DDLogError("Could not create url from string \(urlString)")
            return
        }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}
