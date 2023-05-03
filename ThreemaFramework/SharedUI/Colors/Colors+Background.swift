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

public extension Colors {
    @objc class var backgroundViewController: UIColor {
        .systemBackground
    }
    
    @objc class var backgroundGroupedViewController: UIColor {
        .systemGroupedBackground
    }
    
    @objc class var backgroundNavigationController: UIColor {
        .systemBackground
    }
        
    @objc class var backgroundToolbar: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.white.color
        case .dark:
            return Asset.SharedColors.black.color
        }
    }
    
    @objc class var backgroundHeaderView: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.white.color
        case .dark:
            return Asset.SharedColors.black.color
        }
    }
    
    @objc class var backgroundView: UIColor {
        .systemGroupedBackground
    }
    
    @objc class var backgroundAlertView: UIColor {
        .secondarySystemBackground
    }
    
    @objc class var backgroundInverted: UIColor {
        .systemFill
    }
    
    @objc class var backgroundButton: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray450.color
        case .dark:
            return Asset.SharedColors.gray700.color
        }
    }
    
    @objc class var backgroundChatBarButton: UIColor {
        .systemGray
    }
    
    @objc class var backgroundQuickActionButton: UIColor {
        backgroundTableViewCell
    }
    
    @objc class var backgroundQuickActionButtonSelected: UIColor {
        .secondarySystemGroupedBackground
    }
    
    @objc class var backgroundTextView: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray200.color
        case .dark:
            return Asset.SharedColors.black.color
        }
    }
    
    @objc class var backgroundQrCode: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.white.color
        case .dark:
            return Asset.SharedColors.gray900.color
        }
    }
    
    @objc class var backgroundSafeImageCircle: UIColor {
        Asset.SharedColors.gray250.color
    }
                
    @objc class var backgroundMaterialShowcasePrompt: UIColor {
        Asset.SharedColors.gray750.color
    }
    
    @objc class var backgroundWizard: UIColor {
        Asset.SharedColors.black.color
    }
    
    @objc class var backgroundNotification: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.white.color
        case .dark:
            return Asset.SharedColors.black.color
        }
    }
    
    @objc class var backgroundUnreadMessageLine: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.black.color.withAlphaComponent(0.45)
        case .dark:
            return Asset.SharedColors.gray700.color.withAlphaComponent(0.45)
        }
    }
    
    @objc class var backgroundSegmentedControl: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.white.color
        case .dark:
            return Asset.SharedColors.gray650.color
        }
    }

    class var backgroundWizardBox: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray500.color
        case .dark:
            return Asset.SharedColors.gray700.color
        }
    }
}
