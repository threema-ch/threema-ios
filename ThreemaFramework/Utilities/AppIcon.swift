//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

public enum AppIcon: CaseIterable {
    
    // Default Icon
    case `default`
    
    // Base Icons
    case icon2019
    case icon20132
    case icon20131
    
    // Special Icons
    case anniversary10
    
    // This is also the order in AppIconSettingsView
    public static let defaultIcon: [AppIcon] = [.default]
    public static let baseIcons: [AppIcon] = [.icon2019, .icon20132, .icon20131]
    public static let specialIcons: [AppIcon] = [.anniversary10]
    
    public var iconName: String? {
        switch self {
        case .default:
            return nil
        case .icon2019:
            return "icon_2019"
        case .icon20131:
            return "icon_2013_march"
        case .icon20132:
            return "icon_2013_september"
        case .anniversary10:
            return "icon_10_years"
        }
    }
        
    public var displayTitle: String {
        switch self {
        case .default:
            return BundleUtil.localizedString(forKey: "app_icon_title_current")
        case .icon2019:
            return BundleUtil.localizedString(forKey: "app_icon_title_current")
        case .icon20131:
            return BundleUtil.localizedString(forKey: "app_icon_title_first")
        case .icon20132:
            return BundleUtil.localizedString(forKey: "app_icon_title_second")
        case .anniversary10:
            return BundleUtil.localizedString(forKey: "app_icon_title_celebration")
        }
    }
    
    public var displayInfo: String {
        switch self {
        case .default:
            return BundleUtil.localizedString(forKey: "app_icon_description_current")
        case .icon2019:
            return BundleUtil.localizedString(forKey: "app_icon_description_current")
        case .icon20131:
            return BundleUtil.localizedString(forKey: "app_icon_description_first")
        case .icon20132:
            return BundleUtil.localizedString(forKey: "app_icon_description_second")
        case .anniversary10:
            return BundleUtil.localizedString(forKey: "app_icon_description_celebration")
        }
    }
    
    public var preview: UIImage {
        let image: UIImage?
        
        switch self {
        case .default:
            image = UIImage(named: "icon_2019_full")
        case .icon2019:
            image = UIImage(named: "icon_2019_full")
        case .icon20131:
            image = UIImage(named: "icon_2013_march_full")
        case .icon20132:
            image = UIImage(named: "icon_2013_september_full")
        case .anniversary10:
            image = UIImage(named: "icon_10_years_full")
        }
        guard let image = image else {
            return UIImage(systemName: "questionmark.square.dashed")!
        }
        return image
    }
}
