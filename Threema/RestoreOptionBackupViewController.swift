//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2020 Threema GmbH
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

@objc protocol RestoreOptionBackupViewControllerDelegate {
    func restoreSafe()
    func restoreIdentityFromSafe()
    func restoreIdentity()
    func restoreCancelled()
}

class RestoreOptionBackupViewController: IDCreationPageViewController {
    
    @IBOutlet weak var mainContent: UIStackView!
    
    @IBOutlet weak var content: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var safeButton: SetupButton!
    @IBOutlet weak var safeLabel: UILabel!
    @IBOutlet weak var idButton: SetupButton!
    @IBOutlet weak var idLabel: UILabel!

    @IBOutlet weak var cancelButton: UIButton!
    
    @objc weak var delegate: RestoreOptionBackupViewControllerDelegate?
    
    @objc var hasDataOnDevice: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.hideKeyboardWhenTappedAround()

        self.titleLabel.text = self.hasDataOnDevice ? BundleUtil.localizedString(forKey: "restore_option_id_title") : BundleUtil.localizedString(forKey: "restore_option_title")
        self.descriptionLabel.text = BundleUtil.localizedString(forKey: "restore_option_description")
        self.safeButton.setTitle("Threema Safe", for: .normal)
        self.safeLabel.text = self.hasDataOnDevice ? BundleUtil.localizedString(forKey: "restore_option_safe_keep_data") : BundleUtil.localizedString(forKey: "restore_option_safe")
        self.idButton.setTitle(BundleUtil.localizedString(forKey: "id_backup"), for: .normal)
        self.idLabel.text = self.hasDataOnDevice ? BundleUtil.localizedString(forKey: "restore_option_id_keep_data") : BundleUtil.localizedString(forKey: "restore_option_id")
        
        let mdmSetup = MDMSetup(setup: true)
        self.idButton.deactivated = mdmSetup!.disableIdExport()

        self.cancelButton.setTitle(NSLocalizedString("cancel", comment: ""), for: .normal)

        //add swipe right for cancel action
        let gestureRecognizer = UISwipeGestureRecognizer(target: self, action:#selector(swipeAction))
        gestureRecognizer.numberOfTouchesRequired = 1
        self.view.addGestureRecognizer(gestureRecognizer)
    }
}

extension RestoreOptionBackupViewController {

    @objc func swipeAction(sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            self.delegate?.restoreCancelled()
        }
    }

    @IBAction func touchDownButton(_ sender: UIButton, forEvent event: UIEvent) {
        if sender == self.safeButton {
            if self.hasDataOnDevice {
                self.delegate?.restoreIdentityFromSafe()
            } else {
                self.delegate?.restoreSafe()
            }
        } else if sender == self.idButton {
            self.delegate?.restoreIdentity()
        } else if sender == cancelButton {
            self.delegate?.restoreCancelled()
        }
    }
}
