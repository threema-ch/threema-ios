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

class DeleteIdentityViewController: UIViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var closeButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.titleLabel.text = BundleUtil.localizedString(forKey: "delete_identity_title")
        self.descriptionLabel.text = BundleUtil.localizedString(forKey: "delete_identity_description")
        self.closeButton.setTitle(BundleUtil.localizedString(forKey: "delete_identity_app_close"), for: .normal)
        
        closeButton.backgroundColor = Colors.mainThemeDark()
        closeButton.setTitleColor(Colors.white(), for: .normal)

        self.deleteAllData()
    }
    
    @IBAction func touchDownButton(_ sender: UIButton) {
        self.deleteAllData()
        exit(EXIT_SUCCESS)
    }
    
    private func deleteAllData() {
        if let items = FileUtility.dir(pathUrl: FileUtility.appDataDirectory) {
            for item in items {
                let itemUrl = URL(fileURLWithPath: String(format: "%@/%@", FileUtility.appDataDirectory!.path, item))
                FileUtility.delete(at: itemUrl)
            }
        }
    }
}
