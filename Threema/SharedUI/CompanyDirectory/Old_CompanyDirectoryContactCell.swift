//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2025 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation

class Old_CompanyDirectoryContactCell: UITableViewCell {
    
    @IBOutlet var profilePictureView: UIImageView!
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
        profilePictureView.image = ProfilePictureGenerator.unknownContactImage
        profilePictureView.layer.masksToBounds = true
        profilePictureView.clipsToBounds = true
        profilePictureView.layer.cornerRadius = profilePictureView.frame.height / 2
        
        nameLabel.text = contact.fullName()
        categoryLabel.text = contact.categoryWithOrganisationString()
        csiLabel.text = contact.csi
        
        identityLabel.text = contact.id
        verificationLevel.image = StyleKit.verification3
        
        nameLabel.textColor = .label
        categoryLabel.textColor = .secondaryLabel
        csiLabel.textColor = .secondaryLabel
        identityLabel.textColor = .secondaryLabel
        
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
        
    @objc private func addContact() {
        ContactStore.shared().addWorkContact(
            with: contact.id,
            publicKey: contact.pk,
            firstname: contact.first,
            lastname: contact.last,
            csi: contact.csi,
            jobTitle: contact.jobTitle,
            department: contact.department,
            acquaintanceLevel: .direct
        ) { _ in
            DispatchQueue.main.async {
                self.setupCell()
            }
        } onError: { error in
            DDLogError("Add work contact failed \(error)")
            DispatchQueue.main.async {
                self.setupCell()
            }
        }
    }
}
