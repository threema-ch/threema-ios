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

import UIKit

@objc protocol RestoreOptionDataViewControllerDelegate {
    func optionDataKeepLocal()
    func optionDataCancelled()
}

class RestoreOptionDataViewController: IDCreationPageViewController {

    @IBOutlet var mainContent: UIStackView!
    
    @IBOutlet var content: UIStackView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var keepLocalButton: SetupButton!
    @IBOutlet var keepLocalLabel: UILabel!
    @IBOutlet var deleteLocalButton: SetupButton!
    @IBOutlet var deleteLocalLabel: UILabel!
    
    @IBOutlet var cancelButton: UIButton!
    
    @objc weak var delegate: RestoreOptionDataViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        hideKeyboardWhenTappedAround()

        titleLabel.text = BundleUtil.localizedString(forKey: "restore_option_title")
        descriptionLabel.text = String.localizedStringWithFormat(
            BundleUtil.localizedString(forKey: "restore_option_data_description"),
            ThreemaApp.currentName
        )
        keepLocalButton.setTitle(BundleUtil.localizedString(forKey: "restore_option_data_keep_data"), for: .normal)
        keepLocalLabel.text = BundleUtil.localizedString(forKey: "restore_option_data_keep_data_description")
        deleteLocalButton.setTitle(BundleUtil.localizedString(forKey: "restore_option_data_delete_data"), for: .normal)
        deleteLocalLabel.text = BundleUtil.localizedString(forKey: "restore_option_data_delete_data_description")
    
        cancelButton.setTitle(BundleUtil.localizedString(forKey: "cancel"), for: .normal)
        
        // add swipe right for cancel action
        let gestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(swipeAction))
        gestureRecognizer.numberOfTouchesRequired = 1
        view.addGestureRecognizer(gestureRecognizer)
    }
}

extension RestoreOptionDataViewController {
    @objc func swipeAction(sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            delegate?.optionDataCancelled()
        }
    }
    
    @IBAction func touchDownButton(_ sender: UIButton, forEvent event: UIEvent) {
        if sender == keepLocalButton {
            delegate?.optionDataKeepLocal()
        }
        else if sender == deleteLocalButton {
            let alert = IntroQuestionViewHelper(parent: self, onAnswer: nil)
            let message = String.localizedStringWithFormat(
                BundleUtil.localizedString(forKey: "restore_option_data_delete_data_explain"),
                ThreemaApp.currentName
            )
            alert.showAlert(message, title: BundleUtil.localizedString(forKey: "safe_restore"))
        }
        else if sender == cancelButton {
            delegate?.optionDataCancelled()
        }
    }
}
