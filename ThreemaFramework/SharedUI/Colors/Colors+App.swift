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
    
    @objc public class var primaryWizard: UIColor {
        switch ThreemaApp.current {
        case .threema, .green:
            return darkColor(for: Asset.TargetColors.Threema.primary)
        case .work, .blue:
            return darkColor(for: Asset.TargetColors.ThreemaWork.primary)
        case .onPrem:
            return darkColor(for: Asset.TargetColors.OnPrem.primary)
        }
    }
    
    @objc public class var secondary: UIColor {
        switch ThreemaApp.current {
        case .threema, .green:
            return color(for: Asset.TargetColors.Threema.secondary)
        case .work, .blue:
            return color(for: Asset.TargetColors.ThreemaWork.secondary)
        case .onPrem:
            return color(for: Asset.TargetColors.OnPrem.secondary)
        }
    }
    
    @objc public class var chatBubbleSent: UIColor {
        switch ThreemaApp.current {
        case .threema, .green:
            return color(for: Asset.TargetColors.Threema.chatBubbleSent)
        case .work, .blue:
            return color(for: Asset.TargetColors.ThreemaWork.chatBubbleSent)
        case .onPrem:
            return color(for: Asset.TargetColors.OnPrem.chatBubbleSent)
        }
    }
    
    @objc public class var chatBubbleSentSelected: UIColor {
        switch ThreemaApp.current {
        case .threema, .green:
            return color(for: Asset.TargetColors.Threema.chatBubbleSentSelected)
        case .work, .blue:
            return color(for: Asset.TargetColors.ThreemaWork.chatBubbleSentSelected)
        case .onPrem:
            return color(for: Asset.TargetColors.OnPrem.chatBubbleSentSelected)
        }
    }
    
    @objc public class var chatCallButtonBubble: UIColor {
        switch ThreemaApp.current {
        case .threema, .green:
            return color(for: Asset.TargetColors.Threema.primary)
        case .work, .blue:
            return color(for: Asset.TargetColors.ThreemaWork.primary)
        case .onPrem:
            return color(for: Asset.TargetColors.OnPrem.primary)
        }
    }
    
    @objc public class var navigationBarCall: UIColor {
        switch ThreemaApp.current {
        case .threema, .green:
            return color(for: Asset.TargetColors.Threema.navigationBarCall)
        case .work, .blue:
            return color(for: Asset.TargetColors.ThreemaWork.navigationBarCall)
        case .onPrem:
            return color(for: Asset.TargetColors.OnPrem.navigationBarCall)
        }
    }
    
    @objc public class var navigationBarWeb: UIColor {
        switch ThreemaApp.current {
        case .threema, .green:
            return color(for: Asset.TargetColors.Threema.navigationBarWeb)
        case .work, .blue:
            return color(for: Asset.TargetColors.ThreemaWork.navigationBarWeb)
        case .onPrem:
            return color(for: Asset.TargetColors.OnPrem.navigationBarWeb)
        }
    }
    
    @objc public class var threemaLogo: UIImage! {
        switch ThreemaApp.current {
        case .threema:
            return UIImage(resource: .threema)
        case .work:
            return UIImage(resource: .threemaWork)
        case .onPrem:
            return UIImage(resource: .threemaOnPrem)
        case .green:
            return UIImage(resource: .threemaGreen)
        case .blue:
            return UIImage(resource: .threemaBlue)
        }
    }
    
    @objc public class var darkConsumerLogo: UIImage! {
        UIImage(resource: .threemaBlackLogo)
    }
        
    @objc public class var threemaLogoForPasscode: UIImage! {
        switch ThreemaApp.current {
        case .threema:
            return UIImage(resource: .passcodeLogo)
        case .work:
            return UIImage(resource: .passcodeLogoWork)
        case .onPrem:
            return UIImage(resource: .passcodeLogoOnprem)
        case .green:
            return UIImage(resource: .passcodeLogoGreen)
        case .blue:
            return UIImage(resource: .passcodeLogoBlue)
        }
    }
    
    @objc public class var consumerLogoRoundCorners: UIImage! {
        switch ThreemaApp.current {
        case .blue:
            return UIImage(resource: .passcodeLogoGreen)
        case .threema, .work, .onPrem, .green:
            return UIImage(resource: .passcodeLogo)
        }
    }
    
    @objc public class var backgroundContactInfoSystemMessage: UIColor {
        switch ThreemaApp.current {
        case .threema:
            return Colors.blue
        case .work:
            return Colors.green
        case .green:
            return Colors.blue
        case .blue:
            return Colors.green
        case .onPrem:
            return Colors.green
        }
    }
    
    @objc public class var backgroundCircleButton: UIColor {
        switch theme {
        case .light, .undefined:
            switch ThreemaApp.current {
            case .threema, .green:
                return Asset.TargetColors.Threema.circleButton.color
            case .work, .blue:
                return Asset.TargetColors.ThreemaWork.circleButton.color
            case .onPrem:
                return Asset.TargetColors.OnPrem.circleButton.color
            }
        case .dark:
            return .quaternarySystemFill
        }
    }
    
    public class var grayCircleBackground: UIColor {
        Colors.textLight
    }
    
    public class var grayCircleSymbol: UIColor {
        switch theme {
        case .light, .undefined:
            return Asset.SharedColors.white.color
        case .dark:
            return Asset.SharedColors.gray700.color
        }
    }
    
    @objc public class var threemaConsumerColor: UIColor {
        color(for: Asset.TargetColors.Threema.primary)
    }
    
    @objc public class var threemaWorkColor: UIColor {
        color(for: Asset.TargetColors.ThreemaWork.primary)
    }
}
