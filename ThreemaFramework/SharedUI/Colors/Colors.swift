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

import Foundation

public final class Colors: NSObject {
    @objc public enum Theme: NSInteger {
        case undefined
        case light
        case dark

        public var name: String {
            switch self {
            case .dark: return "Dark"
            case .light: return "Light"
            case .undefined: return "Light"
            }
        }
    }
    
    @objc public static var theme: Theme = .undefined {
        didSet {
            UserSettings.shared().darkTheme = theme == .dark
            StyleKit.resetThemedCache()
            Colors.setupAppearance()
        }
    }
             
    @objc public class func initTheme() {
        if UserSettings.shared().useSystemTheme {
            let traitCollection = UITraitCollection.current
            Colors.theme = traitCollection.userInterfaceStyle == .dark ? .dark : .light
        }
        else {
            Colors.theme = UserSettings.shared().darkTheme ? .dark : .light
        }
    }
        
    internal class func color(for colorAsset: ColorAsset) -> UIColor {
        switch theme {
        case .light, .undefined:
            return colorAsset.color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        case .dark:
            return darkColor(for: colorAsset)
        }
    }
    
    internal class func darkColor(for colorAsset: ColorAsset) -> UIColor {
        colorAsset.color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
    }
}
