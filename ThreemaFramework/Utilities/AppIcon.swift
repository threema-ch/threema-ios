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
    
    // This is also the order in AppIconSettingsView
    case `default`
    case icon2019
    case icon20132
    case icon20131
    
    public var iconName: String? {
        switch self {
        case .default:
            return nil
        case .icon20131:
            return "icon_2013_march"
        case .icon20132:
            return "icon_2013_september"
        case .icon2019:
            return "icon_2019"
        }
    }
        
    public var displayTitle: String {
        switch self {
        case .default:
            return BundleUtil.localizedString(forKey: "app_icon_title_celebration")
        case .icon20131:
            return BundleUtil.localizedString(forKey: "app_icon_title_first")
        case .icon20132:
            return BundleUtil.localizedString(forKey: "app_icon_title_second")
        case .icon2019:
            return BundleUtil.localizedString(forKey: "app_icon_title_current")
        }
    }
    
    public var displayInfo: String {
        switch self {
        case .default:
            return BundleUtil.localizedString(forKey: "app_icon_description_celebration")
        case .icon20131:
            return BundleUtil.localizedString(forKey: "app_icon_description_first")
        case .icon20132:
            return BundleUtil.localizedString(forKey: "app_icon_description_second")
        case .icon2019:
            return BundleUtil.localizedString(forKey: "app_icon_description_current")
        }
    }
    
    public var preview: UIImage {
        let image: UIImage?
        
        switch self {
        case .default:
            image = UIImage(named: "icon_10_years_full")
        case .icon20131:
            image = UIImage(named: "icon_2013_march_full")
        case .icon20132:
            image = UIImage(named: "icon_2013_september_full")
        case .icon2019:
            image = UIImage(named: "icon_2019_full")
        }
        guard let image = image else {
            return UIImage(systemName: "questionmark.square.dashed")!
        }
        return image
    }
}
