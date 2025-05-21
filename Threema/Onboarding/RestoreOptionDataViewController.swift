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

import ThreemaMacros
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

        titleLabel.text = #localize("restore_option_title")
        descriptionLabel.text = String.localizedStringWithFormat(
            #localize("restore_option_data_description"),
            TargetManager.appName
        )
        keepLocalButton.setTitle(#localize("restore_option_data_keep_data"), for: .normal)
        keepLocalLabel.text = String.localizedStringWithFormat(
            #localize("restore_option_data_keep_data_description"),
            TargetManager.localizedAppName,
            TargetManager.localizedAppName
        )
        deleteLocalButton.setTitle(#localize("restore_option_data_delete_data"), for: .normal)
        deleteLocalLabel.text = String.localizedStringWithFormat(
            #localize("restore_option_data_delete_data_description"),
            TargetManager.localizedAppName,
            TargetManager.localizedAppName
        )
    
        cancelButton.setTitle(#localize("cancel"), for: .normal)
        
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
                #localize("restore_option_data_delete_data_explain"),
                TargetManager.localizedAppName,
                TargetManager.appName
            )
            alert.showAlert(
                message,
                title: String.localizedStringWithFormat(
                    #localize("safe_restore"),
                    TargetManager.localizedAppName
                )
            )
        }
        else if sender == cancelButton {
            delegate?.optionDataCancelled()
        }
    }
}
