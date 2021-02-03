//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2021 Threema GmbH
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

protocol ProfilePictureRecipientCellDelegate: AnyObject {
    func valueChanged(_ cell: ProfilePictureRecipientCell)
}

class ProfilePictureRecipientCell: UITableViewCell {
    @IBOutlet weak var profilePictureRecipientLabel: UILabel!
    @IBOutlet weak var profilePictureRecipientSwitch: UISwitch!
    
    var identity: String? {
        didSet {
            guard let identity = identity else {
                profilePictureRecipientSwitch.isOn = false
                return
            }
            if UserSettings.shared().profilePictureContactList.contains(where: { $0 as! String == identity }) {
                profilePictureRecipientSwitch.isOn = true
            } else {
                profilePictureRecipientSwitch.isOn = false
            }
        }
    }
    
    weak var delegate : ProfilePictureRecipientCellDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()

        profilePictureRecipientLabel.text = BundleUtil.localizedString(forKey: "profile_picture_recipient")
    }

    @IBAction func profilePictureRecipientSwitchChanged(_ sender: UIButton) {
        guard let identity = identity else { return }

        let contactIdentities = UserSettings.shared().profilePictureContactList
        let selectedContacts = NSMutableSet(array: contactIdentities!)
        
        if profilePictureRecipientSwitch.isOn {
            selectedContacts.add(identity)
        } else {
            selectedContacts.remove(identity)
        }
        
        UserSettings.shared().profilePictureContactList = selectedContacts.allObjects
        
        if let delegate = delegate {
            delegate.valueChanged(self)
        }
    }

}


