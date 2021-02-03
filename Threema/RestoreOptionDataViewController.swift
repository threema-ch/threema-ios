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

@objc protocol RestoreOptionDataViewControllerDelegate {
    func optionDataKeepLocal()
    func optionDataCancelled()
}

class RestoreOptionDataViewController: IDCreationPageViewController {

    @IBOutlet weak var mainContent: UIStackView!
    
    @IBOutlet weak var content: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var keepLocalButton: SetupButton!
    @IBOutlet weak var keepLocalLabel: UILabel!
    @IBOutlet weak var deleteLocalButton: SetupButton!
    @IBOutlet weak var deleteLocalLabel: UILabel!
    
    @IBOutlet weak var cancelButton: UIButton!
    
    @objc weak var delegate: RestoreOptionDataViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.hideKeyboardWhenTappedAround()

        self.titleLabel.text = BundleUtil.localizedString(forKey: "restore_option_title")
        self.descriptionLabel.text = BundleUtil.localizedString(forKey: "restore_option_data_description")
        self.keepLocalButton.setTitle(BundleUtil.localizedString(forKey: "restore_option_data_keep_data"), for: .normal)
        self.keepLocalLabel.text = BundleUtil.localizedString(forKey: "restore_option_data_keep_data_description")
        self.deleteLocalButton.setTitle(BundleUtil.localizedString(forKey: "restore_option_data_delete_data"), for: .normal)
        self.deleteLocalLabel.text = BundleUtil.localizedString(forKey: "restore_option_data_delete_data_description")
    
        self.cancelButton.setTitle(NSLocalizedString("cancel", comment: ""), for: .normal)
        
        //add swipe right for cancel action
        let gestureRecognizer = UISwipeGestureRecognizer(target: self, action:#selector(swipeAction))
        gestureRecognizer.numberOfTouchesRequired = 1
        self.view.addGestureRecognizer(gestureRecognizer)
    }
}

extension RestoreOptionDataViewController {
    @objc func swipeAction(sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            self.delegate?.optionDataCancelled()
        }
    }
    
    @IBAction func touchDownButton(_ sender: UIButton, forEvent event: UIEvent) {
        if sender == self.keepLocalButton {
            self.delegate?.optionDataKeepLocal()
        } else if sender == self.deleteLocalButton {
            let alert = IntroQuestionViewHelper(parent: self, onAnswer: nil)
            alert.showAlert(BundleUtil.localizedString(forKey: "restore_option_data_delete_data_explain"), title: BundleUtil.localizedString(forKey: "safe_restore"))
        } else if sender == self.cancelButton {
            self.delegate?.optionDataCancelled()
        }
    }
}
