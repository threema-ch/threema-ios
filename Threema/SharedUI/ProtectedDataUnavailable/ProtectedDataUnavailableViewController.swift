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

import Foundation
import ThreemaMacros

class ProtectedDataUnavailableViewController: UIViewController {
    
    @IBOutlet var errorTextLabel: UILabel!
    @IBOutlet var exitButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        errorTextLabel.text = #localize("protectedDataUnavailable_error_text")
        exitButton.setTitle(#localize("protectedDataUnavailable_exitbutton"), for: .normal)
        exitButton.setTitle(
            #localize("protectedDataUnavailable_exitbutton"),
            for: .highlighted
        )
        exitButton.setTitle(#localize("protectedDataUnavailable_exitbutton"), for: .selected)
    }
    
    @IBAction func exitButtonPressed(_ sender: Any) {
        exit(0)
    }
}
