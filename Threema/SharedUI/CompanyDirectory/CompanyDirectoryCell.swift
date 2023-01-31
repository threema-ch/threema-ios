//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2023 Threema GmbH
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
    
    @IBOutlet var companyAvatar: UIImageView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var labelStack: UIStackView!
    @IBOutlet var containerStack: UIStackView!
    
    private lazy var configuration = CellConfiguration(size: .small)
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        setup()
    }
    
    @objc func updateColors() {
        titleLabel.textColor = Colors.text
        descriptionLabel.textColor = Colors.textLight
        companyAvatar.image = AvatarMaker.shared().companyImage()
        tintColor = Colors.primary
    }

    private func setup() {
        companyAvatar.image = AvatarMaker.shared().companyImage()
        titleLabel.text = MyIdentityStore.shared().companyName
        descriptionLabel.text = BundleUtil.localizedString(forKey: "companydirectory_description")
        
        labelStack.spacing = configuration.verticalSpacing
        
        containerStack.spacing = configuration.horizontalSpacing
        containerStack.alignment = .center
        
        updateColors()
    }
    
    override public func layoutMarginsDidChange() {
        super.layoutMarginsDidChange()
        
        guard !traitCollection.preferredContentSizeCategory.isAccessibilityCategory else {
            separatorInset = .zero
            return
        }
        
        // Adjust separator inset
        let leftSeparatorInset = configuration.maxAvatarSize + configuration.horizontalSpacing
        separatorInset = UIEdgeInsets(top: 0, left: leftSeparatorInset, bottom: 0, right: 0)
    }
}
