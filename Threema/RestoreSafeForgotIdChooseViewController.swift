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

class RestoreSafeForgotIdChooseViewController: IDCreationPageViewController {
    
    @IBOutlet weak var contentView: UIStackView!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var cancelButton: SetupButton!
    
    var ids: [String]?
    var choosenId: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.descriptionLabel.text = BundleUtil.localizedString(forKey: "safe_select_id")
        
        self.cancelButton.setTitle(BundleUtil.localizedString(forKey: "cancel"), for: .normal)
        
        if let ids = self.ids {
            var index: Int = 1
            for id in ids {
                print(id)
                let idButton = SetupButton()
                idButton.setTitle(id, for: .normal)
                idButton.addTarget(self, action: #selector(self.touchIdButton), for: .touchUpInside)

                self.contentView.insertArrangedSubview(idButton, at: index)
                index += 1
            }
        }
    }
    
    override open var shouldAutorotate: Bool {
        return false
    }
    
    @objc func touchIdButton(_ sender: SetupButton) {
        if let id: String = sender.titleLabel?.text {
            self.choosenId = String(id[id.startIndex..<id.index(id.startIndex, offsetBy: 8)])
            self.performSegue(withIdentifier: "choosenSafeForgotIdChoose", sender: self)
        }
    }
}
