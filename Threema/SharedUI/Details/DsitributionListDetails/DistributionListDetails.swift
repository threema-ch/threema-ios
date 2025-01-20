//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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

/// When we ditch `objc` move this into the `DistributionListDetails` name space and remove `Int`
@objc enum DistributionListDetailsDisplayMode: Int {
    case `default`
    case conversation
}

enum DistributionListDetails {
    enum Section {
        case recipients
        case contentActions
        case destructiveDistributionListActions
        case wallpaperActions
    }
    
    enum Row: Hashable {
        // General
        case action(_ action: Details.Action)
        
        // Distribution List Recipients
        case contact(_ contact: Contact, isSelfMember: Bool = true)
        case unknownContact
        case recipientsAction(_ action: Details.Action)
        
        // Wallpaper
        case wallpaper(action: Details.Action, isDefault: Bool)
    }
}
