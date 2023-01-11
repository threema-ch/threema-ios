//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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
    @objc class var text: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.black.color
        case .dark:
            return Asset.SharedColors.gray30.color
        }
    }
    
    @objc class var textLight: UIColor {
        
        // We respect the increase contrast setting
        if UIAccessibility.isDarkerSystemColorsEnabled {
            return text
        }
        
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray550.color
        case .dark:
            return Asset.SharedColors.gray400.color
        }
    }
    
    @objc class var textVeryLight: UIColor {
        
        // We respect the increase contrast setting
        if UIAccessibility.isDarkerSystemColorsEnabled {
            return text
        }
        
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray400.color
        case .dark:
            return Asset.SharedColors.gray500.color
        }
    }
    
    @objc class var textPlaceholder: UIColor {
        Asset.SharedColors.gray400.color
    }
    
    @objc class var textSetup: UIColor {
        Asset.SharedColors.white.color
    }
    
    @objc class var textLockScreen: UIColor {
        Asset.SharedColors.white.color
    }
    
    @objc class var textMaterialShowcase: UIColor {
        Asset.SharedColors.white.color
    }
    
    @objc class var textInverted: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.white.color
        case .dark:
            return Asset.SharedColors.black.color
        }
    }
    
    @objc class var textLink: UIColor {
        Colors.primary
    }
        
    @objc class var textQuoteID: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray700.color
        case .dark:
            return Asset.SharedColors.gray500.color
        }
    }
    
    @objc class var textQuote: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray600.color
        case .dark:
            return Asset.SharedColors.gray400.color
        }
    }
    
    @objc class var textMentionMe: UIColor {
        textInverted
    }
    
    @objc class var textMentionMeOwnMessage: UIColor {
        textInverted
    }
    
    @objc class var textMentionMeOverviewMessage: UIColor {
        textInverted
    }
    
    @objc class var textWizardLink: UIColor {
        primaryWizard
    }
    
    @objc class var textChatDateCustomImage: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.gray650.color
        case .dark:
            return Asset.SharedColors.gray300.color
        }
    }
}
