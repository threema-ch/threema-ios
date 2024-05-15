//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

extension UIColor {
    
    /// The color below serves as an example for future implementations
    private static let dynamicTestColor = UIColor { (traitCollection: UITraitCollection) -> UIColor in
        let highContrast = UIAccessibility.isDarkerSystemColorsEnabled
        
        if traitCollection.userInterfaceStyle == .dark {
            return highContrast ? .red : .blue
        }
        else {
            return highContrast ? .green : .yellow
        }
    }
    
    @objc public static let primary = UIColor { _ in
        switch ThreemaApp.current {
        case .threema, .green:
            return Asset.TargetColors.Threema.primary.color
        case .work, .blue:
            return Asset.TargetColors.ThreemaWork.primary.color
        case .onPrem:
            return Asset.TargetColors.OnPrem.primary.color
        }
    }
}
