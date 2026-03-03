//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

import ThreemaMacros

final class ReleasePictureCell: UITableViewCell {
    
    // MARK: - Configure

    func configure(secondaryText: String, isEnabled: Bool) {
        var content = defaultContentConfiguration()
        
        content.text = #localize("edit_profile_picture_cell_title")
        content.textProperties.color = isEnabled ? .label : .secondaryLabel
        content.secondaryText = secondaryText
        content.secondaryTextProperties.color = .secondaryLabel
        content.secondaryTextProperties.font = .preferredFont(forTextStyle: .body)
        content.prefersSideBySideTextAndSecondaryText = true
        
        contentConfiguration = content
        accessoryType = .disclosureIndicator
        isUserInteractionEnabled = isEnabled
    }
}

// MARK: - Reusable

extension ReleasePictureCell: Reusable { }
