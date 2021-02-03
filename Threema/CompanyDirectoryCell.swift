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

class CompanyDirectoryCell: UITableViewCell {
    
    @IBOutlet weak var companyAvatar: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        setup()
    }
    
    @objc func setupColors() {
        titleLabel.textColor = Colors.fontNormal()
        descriptionLabel.textColor = Colors.fontLight()
    }

    private func setup() {
        companyAvatar.image = AvatarMaker.shared()?.companyImage()
        titleLabel.text = MyIdentityStore.shared()?.companyName
        descriptionLabel.text = BundleUtil.localizedString(forKey: "companydirectory_description")
        
        setupColors()
    }
}
