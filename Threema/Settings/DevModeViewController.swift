//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2022 Threema GmbH
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
import SwiftUI
import ThreemaFramework
class DevModeViewController: ThemedTableViewController {
    
    @IBOutlet var newChatViewLabel: UILabel!
    @IBOutlet var newChatViewSwitch: UISwitch!
    
    @IBOutlet var styleKitDebugViewLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = BundleUtil.localizedString(forKey: "settings_dev_mode")
        navigationItem.largeTitleDisplayMode = .never
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateNewChatViewSwitch()
        updateStyleKitDebugViewLabel()
        if ThreemaApp.current != .threema, ThreemaApp.current != .red {
            let cell = tableView.cellForRow(at: IndexPath(row: 2, section: 1))
            cell?.isHidden = true
        }
    }
}

// MARK: Private methods

extension DevModeViewController {
    private func updateNewChatViewSwitch() {
        newChatViewLabel.text = BundleUtil.localizedString(forKey: "settings_devmode_new_chat_view")
        newChatViewSwitch.isOn = UserSettings.shared().newChatViewActive
    }
    
    private func updateStyleKitDebugViewLabel() {
        styleKitDebugViewLabel.text = BundleUtil.localizedString(forKey: "settings_devmode_stylekit_debug_view")
    }
}

// MARK: IBActions

extension DevModeViewController {
    @IBAction func newChatViewValueChanged(_ sender: UISwitch) {
        UserSettings.shared().newChatViewActive = sender.isOn
    }
}
