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

import ThreemaMacros
import UIKit

class RestoreSafeForgotIDChooseViewController: IDCreationPageViewController {
    
    @IBOutlet var contentView: UIStackView!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var cancelButton: SetupButton!
    
    var ids: [String]?
    var choosenID: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        descriptionLabel.text = #localize("safe_select_id")
        
        cancelButton.setTitle(#localize("cancel"), for: .normal)
        
        if let ids {
            var index = 1
            for id in ids {
                print(id)
                let idButton = SetupButton()
                idButton.setTitle(id, for: .normal)
                idButton.addTarget(self, action: #selector(touchIDButton), for: .touchUpInside)

                contentView.insertArrangedSubview(idButton, at: index)
                index += 1
            }
        }
    }
    
    override open var shouldAutorotate: Bool {
        false
    }
    
    @objc func touchIDButton(_ sender: SetupButton) {
        if let id: String = sender.titleLabel?.text {
            choosenID = String(id[id.startIndex..<id.index(id.startIndex, offsetBy: 8)])
            performSegue(withIdentifier: "choosenSafeForgotIDChoose", sender: self)
        }
    }
}
