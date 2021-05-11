//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021 Threema GmbH
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

class ChevronBackCircleImage {
    static func get() -> UIImage {
        let size = CGSize(width: 32, height: 36)
        
        let isDark = Colors.getTheme().rawValue == 2 || Colors.getTheme().rawValue == 3
        
        let lightThemelightGray = UIColor.init(red: 232/255, green: 232/255, blue: 234/255, alpha: 1.0)
        let lightThemedarkGray = UIColor.init(red: 129/255, green: 129/255, blue: 133/255, alpha: 1.0)
        
        let darkThemeLightGray = UIColor.init(red: 165/255, green: 165/255, blue: 171/255, alpha: 1.0)
        let darkThemeDarkGray = UIColor.init(red: 59/255, green: 59/255, blue: 61/255, alpha: 1.0)
        
        let circleColor = isDark ? darkThemeDarkGray : lightThemelightGray
        let chevronColor = isDark ? darkThemeLightGray : lightThemedarkGray
        
        guard let circleImage = BundleUtil.imageNamed("circle.fill_semibold.L")?.withTint(circleColor) else {
            fatalError("Back button image is missing")
        }
        guard let chevronImage = BundleUtil.imageNamed("chevron.small.backward.L")?.withTint(chevronColor) else {
            fatalError("Back button image is missing")
        }
        
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)

        let areaSize = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        circleImage.draw(in: areaSize)

        chevronImage.draw(in: areaSize, blendMode: .normal, alpha: 1.0)

        guard let finalImage : UIImage = UIGraphicsGetImageFromCurrentImageContext() else {
            fatalError("Could not create image.")
        }
        UIGraphicsEndImageContext()
        
        return finalImage
    }
}
