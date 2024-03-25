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

extension Colors {
    @objc public class var backgroundViewController: UIColor {
        .systemBackground
    }
    
    @objc public class var backgroundGroupedViewController: UIColor {
        .systemGroupedBackground
    }
    
    @objc public class var backgroundNavigationController: UIColor {
        .systemBackground
    }
        
    @objc public class var backgroundToolbar: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.white.color
        case .dark:
            return Asset.SharedColors.black.color
        }
    }
    
    @objc public class var backgroundHeaderView: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.white.color
        case .dark:
            return Asset.SharedColors.black.color
        }
    }
    
    @objc public class var backgroundView: UIColor {
        .systemGroupedBackground
    }
    
    @objc public class var backgroundAlertView: UIColor {
        .secondarySystemBackground
    }
    
    @objc public class var backgroundInverted: UIColor {
        .systemFill
    }
    
    @objc public class var backgroundButton: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray450.color
        case .dark:
            return Asset.SharedColors.gray700.color
        }
    }
    
    @objc public class var backgroundChatBarButton: UIColor {
        .systemGray
    }
    
    @objc public class var backgroundQuickActionButton: UIColor {
        backgroundTableViewCell
    }
    
    @objc public class var backgroundQuickActionButtonSelected: UIColor {
        .secondarySystemGroupedBackground
    }
    
    @objc public class var backgroundTextView: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray200.color
        case .dark:
            return Asset.SharedColors.black.color
        }
    }
    
    @objc public class var backgroundQrCode: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.white.color
        case .dark:
            return Asset.SharedColors.gray900.color
        }
    }
    
    @objc public class var backgroundSafeImageCircle: UIColor {
        Asset.SharedColors.gray250.color
    }
    
    @objc public class var backgroundWizard: UIColor {
        Asset.SharedColors.black.color
    }
    
    @objc public class var backgroundNotification: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.white.color
        case .dark:
            return Asset.SharedColors.black.color
        }
    }
    
    @objc public class var backgroundUnreadMessageLine: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.black.color.withAlphaComponent(0.45)
        case .dark:
            return Asset.SharedColors.gray700.color.withAlphaComponent(0.45)
        }
    }
    
    @objc public class var backgroundSegmentedControl: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.white.color
        case .dark:
            return Asset.SharedColors.gray650.color
        }
    }

    public class var backgroundWizardBox: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray500.color
        case .dark:
            return Asset.SharedColors.gray700.color
        }
    }
}
