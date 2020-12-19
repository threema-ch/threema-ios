//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020 Threema GmbH
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
import ThreemaFramework

class DevModeViewController: ThemedTableViewController {
                    
    @IBOutlet weak var quoteV2Label: UILabel!
    @IBOutlet weak var quoteV2Switch: UISwitch!
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .all
        }
        return .allButUpsideDown
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateQuoteSwitch()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
}

extension DevModeViewController {
    // MARK: Private methods
    
    private func updateQuoteSwitch() {
        quoteV2Label.text = BundleUtil.localizedString(forKey: "settings_devmode_quote_v2")
        quoteV2Switch.isOn = UserSettings.shared().quoteV2Active
    }
}

extension DevModeViewController {
    // MARK: IBActions
    @IBAction func quoteV2ValueChanged(sender: UISwitch) {
        UserSettings.shared().quoteV2Active = sender.isOn
    }
}
