//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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
            case .dark: "Dark"
            case .light: "Light"
            case .undefined: "Light"
            }
        }
    }
    
    @objc public static var theme: Theme = .undefined {
        didSet {
            UserSettings.shared().darkTheme = theme == .dark
            StyleKit.resetThemedCache()
            Colors.setupAppearance()
            
            NotificationCenter.default.post(
                name: NSNotification.Name(rawValue: kNotificationColorThemeChanged),
                object: nil
            )
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
}
