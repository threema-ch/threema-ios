//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2021 Threema GmbH
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

class CompanyDirectoryContactCell: UITableViewCell {
    
    @IBOutlet weak var avatar: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var identityLabel: UILabel!
    @IBOutlet weak var csiLabel: UILabel!
    @IBOutlet weak var verificationLevel: UIImageView!
    
    var addContactActive: Bool = true
    
    var contact: CompanyDirectoryContact! {
        didSet {
            setupCell()
        }
    }
    
    func setupCell() {

        avatar.image = AvatarMaker.shared().avatar(forFirstName: contact.first, lastName: contact.last, size: avatar.frame.size.width)
    
        nameLabel.text = contact.fullName()
        categoryLabel.text = contact.categoryWithOrganisationString()
        csiLabel.text = contact.csi
        
        identityLabel.text = contact.id
        verificationLevel.image = StyleKit.verification3
        
        if ContactStore.shared()?.contact(forIdentity: contact.id) != nil {
            self.accessoryView = nil
            self.accessoryType = addContactActive == true ? .disclosureIndicator : .none
        } else {
            if addContactActive == true {
                self.accessoryType = .none
                let addButton = UIButton.init(type: .contactAdd)
                addButton.addTarget(self, action: #selector(addContact), for: .touchUpInside)
                addButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: -5)
                self.accessoryView = addButton
            } else {
                self.accessoryView = nil
                self.accessoryType = .none
            }
        }
    }
    
    func setupColors() {
        nameLabel.textColor = Colors.fontNormal()
        categoryLabel.textColor = Colors.fontLight()
        csiLabel.textColor = Colors.fontLight()
        identityLabel.textColor = Colors.fontLight()
    }
    
    @objc private func addContact() {
        ContactStore.shared()?.addWorkContact(withIdentity: contact.id, publicKey: contact.pk, firstname: contact.first, lastname: contact.last)
        setupCell()
    }
}
