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

import Foundation

public extension Colors {
    @objc class var separator: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray400.color
        case .dark:
            return Asset.SharedColors.gray750.color
        }
    }
    
    @objc class var backgroundTableView: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray150.color
        case .dark:
            return Asset.SharedColors.black.color
        }
    }
    
    @objc class var backgroundTableHeaderView: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray200.color
        case .dark:
            return Asset.SharedColors.black.color
        }
    }
    
    @objc class var backgroundTableViewCell: UIColor {
        .secondarySystemGroupedBackground
    }
    
    @objc class var backgroundTableViewCellSelected: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.backgroundCellSelectedLight.color
        case .dark:
            return Asset.SharedColors.backgroundCellSelectedDark.color
        }
    }
    
    @objc class var backgroundTableViewCellShareExtensionSelected: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray400.color
        case .dark:
            return Asset.SharedColors.gray350.color
        }
    }
}
