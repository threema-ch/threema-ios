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
            .white
        case .dark:
            .black
        }
    }
    
    @objc public class var backgroundView: UIColor {
        .systemGroupedBackground
    }
    
    @objc public class var backgroundInverted: UIColor {
        .systemFill
    }
    
    @objc public class var backgroundButton: UIColor {
        switch theme {
        case .light, .undefined:
            UIColor(resource: .gray450)
        case .dark:
            UIColor(resource: .gray700)
        }
    }
    
    @objc public class var backgroundChatBarButton: UIColor {
        .systemGray
    }
    
    @objc public class var backgroundChevronCircleButton: UIColor {
        switch theme {
        case .light, .undefined:
            UIColor(resource: .gray250)
        case .dark:
            UIColor(resource: .gray800)
        }
    }
    
    @objc public class var backgroundTintChevronCircleButton: UIColor {
        switch theme {
        case .light, .undefined:
            UIColor(resource: .gray550)
        case .dark:
            UIColor(resource: .gray400)
        }
    }
    
    @objc public class var backgroundSafeImageCircle: UIColor {
        UIColor(resource: .gray250)
    }
    
    @objc public class var backgroundWizard: UIColor {
        .black
    }
    
    @objc public class var backgroundNotification: UIColor {
        switch theme {
        case .light, .undefined:
            .white
        case .dark:
            .black
        }
    }
    
    public class var backgroundWizardBox: UIColor {
        switch theme {
        case .light, .undefined:
            UIColor(resource: .gray500)
        case .dark:
            UIColor(resource: .gray700)
        }
    }
}
