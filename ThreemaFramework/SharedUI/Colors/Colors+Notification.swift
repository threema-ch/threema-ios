//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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

extension Colors {
    public class var pillBackground: UIColor {
        switch theme {
        case .light, .undefined:
            Asset.SharedColors.white.color
        case .dark:
            Asset.SharedColors.gray900.color
        }
    }
    
    public class var pillText: UIColor {
        switch theme {
        case .light, .undefined:
            .secondaryLabel.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        case .dark:
            .secondaryLabel.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        }
    }
    
    public class var pillShadow: UIColor {
        switch theme {
        case .light, .undefined:
            Colors.black.withAlphaComponent(0.3)
        case .dark:
            .clear
        }
    }
    
    public class var successGreen: UIColor {
        color(for: Asset.TargetColors.Threema.primary)
    }
}
