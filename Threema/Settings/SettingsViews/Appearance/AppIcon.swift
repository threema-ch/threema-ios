//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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
import ThreemaMacros

public enum AppIcon: CaseIterable {
    
    // Default Icon
    case `default`
    
    // Base Icons
    // We also have the current here, so users can `hard` select it
    case icon2019
    case icon20132
    case icon20131
    
    // Special Icons
    case anniversary10
    
    // This is also the order in AppIconSettingsView
    public static let defaultIcon: [AppIcon] = [.default]
    public static let baseIcons: [AppIcon] = [.icon2019, .icon20132, .icon20131]
    public static let specialIcons: [AppIcon] = [.anniversary10]
    
    // These strings are defined in the xcconfig
    public var iconName: String? {
        switch self {
        case .default:
            nil
        case .icon2019:
            "Icon2019"
        case .icon20131:
            "Icon2013_1"
        case .icon20132:
            "Icon2013_2"
        case .anniversary10:
            "Icon10Years"
        }
    }
        
    public var displayTitle: String {
        switch self {
        case .default:
            #localize("app_icon_title_current")
        case .icon2019:
            #localize("app_icon_title_current")
        case .icon20131:
            #localize("app_icon_title_first")
        case .icon20132:
            #localize("app_icon_title_second")
        case .anniversary10:
            #localize("app_icon_title_celebration")
        }
    }
    
    public var displayInfo: String {
        switch self {
        case .default:
            #localize("app_icon_description_current")
        case .icon2019:
            #localize("app_icon_description_current")
        case .icon20131:
            #localize("app_icon_description_first")
        case .icon20132:
            #localize("app_icon_description_second")
        case .anniversary10:
            #localize("app_icon_description_celebration")
        }
    }
    
    public var preview: UIImage {
        // Starting with the iOS 18 SDK (Xcode 16) app icon assets cannot be accessed from the app. Thus we have to add
        // them twice, once as an image asset. Our convention is to suffix these images with `-image`.
        // Source: https://forums.developer.apple.com/forums/thread/757162?answerId=799284022#799284022
        
        // We want to take advantage of the build time guarantees of image resources. At the same time we don't see a
        // reason to set active Swift compilation conditions for each app target. Our workaround is to also add the
        // `-image` assets to Green, but they are never actually used/shown.
        #if THREEMA_CUSTOMER
            let image: UIImage? =
                switch self {
                case .default:
                    UIImage(resource: .appIcon)
                case .icon2019:
                    UIImage(resource: .icon2019)
                case .icon20131:
                    UIImage(resource: .icon20131)
                case .icon20132:
                    UIImage(resource: .icon20132)
                case .anniversary10:
                    UIImage(resource: .icon10Years)
                }
        #else
            let image: UIImage? =
                switch self {
                case .default:
                    UIImage(resource: .appIcon)
                case .icon2019, .icon20131, .icon20132, .anniversary10:
                    UIImage(systemName: "questionmark.square.dashed")
                }
        #endif
        
        guard let image else {
            return UIImage(systemName: "questionmark.square.dashed")!
        }
        
        return image
    }
}
