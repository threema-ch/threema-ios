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

class BlockContactCell: UITableViewCell {
    @IBOutlet weak var blockContactLabel: UILabel!
    @IBOutlet weak var blockContactSwitch: UISwitch!
    
    var identity: String? {
        didSet {
            guard let identity = identity else {
                blockContactSwitch.isOn = false
                return
            }
            blockContactSwitch.isOn = UserSettings.shared().blacklist.contains(identity)
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()

        blockContactLabel.text = BundleUtil.localizedString(forKey: "block_contact")
    }

    @IBAction func blockSwitchChanged(_ sender: UIButton) {
        guard let identity = identity else { return }
        let blackList = NSMutableOrderedSet(orderedSet: UserSettings.shared().blacklist)
        if blockContactSwitch.isOn {
            blackList.add(identity)
        } else {
            blackList.remove(identity)
        }
        UserSettings.shared().blacklist = blackList
        
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: kNotificationBlockedContact), object: identity)
    }

}
