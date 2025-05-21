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
            return highContrast ? .systemRed : .systemBlue
        }
        else {
            return highContrast ? .systemGreen : .systemYellow
        }
    }
    
    @objc static var primary = UIColor { _ in
        switch TargetManager.current {
        case .threema, .green:
            UIColor(resource: .accentColorPrivate)
        case .work, .blue:
            UIColor(resource: .accentColorWork)
        case .onPrem:
            UIColor(resource: .accentColorOnPrem)
        case .customOnPrem:
            UIColor(resource: .accentColorCustomOnPrem)
        }
    }
    
    @objc public static var secondary = UIColor { _ in
        switch TargetManager.current {
        case .threema, .green:
            UIColor(resource: .secondaryPrivate)
        case .work, .blue:
            UIColor(resource: .secondaryWork)
        case .onPrem:
            UIColor(resource: .secondaryOnPrem)
        case .customOnPrem:
            UIColor(resource: .secondaryCustomOnPrem)
        }
    }
    
    @objc public static let backgroundCircleButton = UIColor { _ in
        switch TargetManager.current {
        case .threema, .green:
            .circleButtonPrivate
        case .work, .blue:
            .circleButtonWork
        case .onPrem:
            .circleButtonOnPrem
        case .customOnPrem:
            .circleButtonCustomOnPrem
        }
    }
}
