//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

import UIKit

/// Base class for `UITableViewCells` that are implemented in code
open class ThemedCodeTableViewCell: UITableViewCell {
    
    private var themeUsedInLastColorsUpdate = Colors.theme
    
    // Normally you don't need to override `init`. Just do you configuration in `configureCell()`.
    override public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        configureCell()
        updateColors()
    }
    
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Called during initialization
    open func configureCell() {
        // The min cell height should always be 44 pt
        contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
    }
    
    override open func prepareForReuse() {
        super.prepareForReuse()
        
        // Only update colors if theme changed
        if themeUsedInLastColorsUpdate != Colors.theme {
            updateColors()
        }
    }
    
    /// Called whenever the colors of the views should be set to the current theme colors
    @objc open func updateColors() {
        Colors.update(cell: self)
        themeUsedInLastColorsUpdate = Colors.theme
    }
}
