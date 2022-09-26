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

import Foundation

class Old_CompanyDirectoryContactCell: UITableViewCell {
    
    @IBOutlet var avatar: UIImageView!
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var categoryLabel: UILabel!
    @IBOutlet var identityLabel: UILabel!
    @IBOutlet var csiLabel: UILabel!
    @IBOutlet var verificationLevel: UIImageView!
    
    var addContactActive = true
    
    var contact: CompanyDirectoryContact! {
        didSet {
            setupCell()
        }
    }
    
    func setupCell() {

        avatar.image = AvatarMaker.shared()
            .avatar(forFirstName: contact.first, lastName: contact.last, size: avatar.frame.size.width)
    
        nameLabel.text = contact.fullName()
        categoryLabel.text = contact.categoryWithOrganisationString()
        csiLabel.text = contact.csi
        
        identityLabel.text = contact.id
        verificationLevel.image = StyleKit.verification3
        
        if ContactStore.shared().contact(for: contact.id) != nil {
            accessoryView = nil
            accessoryType = addContactActive == true ? .disclosureIndicator : .none
        }
        else {
            if addContactActive == true {
                accessoryType = .none
                let addButton = UIButton(type: .contactAdd)
                addButton.addTarget(self, action: #selector(addContact), for: .touchUpInside)
                addButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: -5)
                accessoryView = addButton
            }
            else {
                accessoryView = nil
                accessoryType = .none
            }
        }
    }
    
    func updateColors() {
        categoryLabel.textColor = Colors.textLight
        csiLabel.textColor = Colors.textLight
        identityLabel.textColor = Colors.textLight
    }
    
    @objc private func addContact() {
        ContactStore.shared().addWorkContact(
            with: contact.id,
            publicKey: contact.pk,
            firstname: contact.first,
            lastname: contact.last,
            shouldUpdateFeatureMask: true
        )
        setupCell()
    }
}
