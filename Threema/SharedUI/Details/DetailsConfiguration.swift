//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2024 Threema GmbH
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

/// Configuration used by multiple detail views
///
/// Normally you don't create your own implementation but use the default implementation
protocol DetailsConfiguration {
    /// Size of the big profile picture
    var profilePictureSize: CGFloat { get }
    
    /// Font for contact or group name. Based on current dynamic type setting.
    var nameFont: UIFont { get }
}

// Default implementation
extension DetailsConfiguration {
    var profilePictureSize: CGFloat { 120 }
    
    var nameFont: UIFont {
        let title2Font = UIFont.preferredFont(forTextStyle: .title2)
        return UIFont.systemFont(ofSize: title2Font.pointSize + 2, weight: .semibold)
    }
}
