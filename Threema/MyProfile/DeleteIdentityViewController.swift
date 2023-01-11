//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2022 Threema GmbH
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

@objc class DeleteIdentityViewController: UIViewController {
    
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var closeButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = BundleUtil.localizedString(forKey: "delete_identity_title")
        descriptionLabel.text = String.localizedStringWithFormat(
            BundleUtil.localizedString(forKey: "delete_identity_description"),
            ThreemaApp.currentName
        )
        closeButton.setTitle(BundleUtil.localizedString(forKey: "delete_identity_app_close"), for: .normal)
        closeButton.accessibilityIdentifier = "DeleteIdentityViewControllerCloseButton"
        closeButton.backgroundColor = Colors.primaryWizard
        closeButton.setTitleColor(Colors.textSetup, for: .normal)
    }
    
    @IBAction func touchDownButton(_ sender: UIButton) {
        exit(EXIT_SUCCESS)
    }
}
