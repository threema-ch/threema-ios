//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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

import ThreemaFramework
import UIKit

class WallpaperTableViewCell: ThemedCodeStackTableViewCell {
    
    // MARK: Public Properties
    
    var action: Details.Action? {
        didSet {
            guard let action else {
                return
            }
            titleLabel.text = action.title
            stateLabel.text = BundleUtil.localizedString(forKey: "settings_chat_wallpaper_default")
            stateLabel.textColor = Colors.textLight
        }
    }
    
    var isDefault: Bool? {
        didSet {
            guard let isDefault else {
                return
            }
            if isDefault {
                stateLabel.text = BundleUtil.localizedString(forKey: "settings_chat_wallpaper_default")
            }
            else {
                stateLabel.text = BundleUtil.localizedString(forKey: "settings_chat_wallpaper_custom")
            }
        }
    }
        
    // MARK: Private Properties
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .body)
        
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            label.numberOfLines = 0
        }
        
        return label
    }()
    
    private lazy var stateLabel: UILabel = {
        let label = UILabel()
        
        label.font = UIFont.preferredFont(forTextStyle: .body)
        
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            label.numberOfLines = 0
        }
        
        label.textColor = Colors.textLight
        
        return label
    }()
        
    override func configureCell() {
        super.configureCell()
                
        accessoryType = .disclosureIndicator
        
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(stateLabel)
    }
    
    override func updateColors() {
        super.updateColors()
    }
    
    // MARK: - Accessibility
    
    override public var accessibilityLabel: String? {
        get {
            titleLabel.accessibilityLabel
        }
        set { }
    }
}

// MARK: - Reusable

extension WallpaperTableViewCell: Reusable { }
