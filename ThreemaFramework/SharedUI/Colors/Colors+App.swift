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
            darkColor(for: Asset.TargetColors.Threema.primary)
        case .work, .blue:
            darkColor(for: Asset.TargetColors.ThreemaWork.primary)
        case .onPrem:
            darkColor(for: Asset.TargetColors.OnPrem.primary)
        }
    }
    
    @objc public class var secondary: UIColor {
        switch ThreemaApp.current {
        case .threema, .green:
            color(for: Asset.TargetColors.Threema.secondary)
        case .work, .blue:
            color(for: Asset.TargetColors.ThreemaWork.secondary)
        case .onPrem:
            color(for: Asset.TargetColors.OnPrem.secondary)
        }
    }
    
    @objc public class var chatBubbleSent: UIColor {
        switch ThreemaApp.current {
        case .threema, .green:
            color(for: Asset.TargetColors.Threema.chatBubbleSent)
        case .work, .blue:
            color(for: Asset.TargetColors.ThreemaWork.chatBubbleSent)
        case .onPrem:
            color(for: Asset.TargetColors.OnPrem.chatBubbleSent)
        }
    }
    
    @objc public class var chatBubbleSentSelected: UIColor {
        switch ThreemaApp.current {
        case .threema, .green:
            color(for: Asset.TargetColors.Threema.chatBubbleSentSelected)
        case .work, .blue:
            color(for: Asset.TargetColors.ThreemaWork.chatBubbleSentSelected)
        case .onPrem:
            color(for: Asset.TargetColors.OnPrem.chatBubbleSentSelected)
        }
    }
    
    @objc public class var chatCallButtonBubble: UIColor {
        switch ThreemaApp.current {
        case .threema, .green:
            color(for: Asset.TargetColors.Threema.primary)
        case .work, .blue:
            color(for: Asset.TargetColors.ThreemaWork.primary)
        case .onPrem:
            color(for: Asset.TargetColors.OnPrem.primary)
        }
    }
    
    @objc public class var navigationBarCall: UIColor {
        switch ThreemaApp.current {
        case .threema, .green:
            color(for: Asset.TargetColors.Threema.navigationBarCall)
        case .work, .blue:
            color(for: Asset.TargetColors.ThreemaWork.navigationBarCall)
        case .onPrem:
            color(for: Asset.TargetColors.OnPrem.navigationBarCall)
        }
    }
    
    @objc public class var navigationBarWeb: UIColor {
        switch ThreemaApp.current {
        case .threema, .green:
            color(for: Asset.TargetColors.Threema.navigationBarWeb)
        case .work, .blue:
            color(for: Asset.TargetColors.ThreemaWork.navigationBarWeb)
        case .onPrem:
            color(for: Asset.TargetColors.OnPrem.navigationBarWeb)
        }
    }
    
    @objc public class var threemaLogo: UIImage! {
        switch ThreemaApp.current {
        case .threema:
            UIImage(resource: .threema)
        case .work:
            UIImage(resource: .threemaWork)
        case .onPrem:
            UIImage(resource: .threemaOnPrem)
        case .green:
            UIImage(resource: .threemaGreen)
        case .blue:
            UIImage(resource: .threemaBlue)
        }
    }
    
    @objc public class var darkConsumerLogo: UIImage! {
        UIImage(resource: .threemaBlackLogo)
    }
        
    @objc public class var threemaLogoForPasscode: UIImage! {
        switch ThreemaApp.current {
        case .threema:
            UIImage(resource: .passcodeLogo)
        case .work:
            UIImage(resource: .passcodeLogoWork)
        case .onPrem:
            UIImage(resource: .passcodeLogoOnprem)
        case .green:
            UIImage(resource: .passcodeLogoGreen)
        case .blue:
            UIImage(resource: .passcodeLogoBlue)
        }
    }
    
    @objc public class var consumerLogoRoundCorners: UIImage! {
        switch ThreemaApp.current {
        case .blue:
            UIImage(resource: .passcodeLogoGreen)
        case .threema, .work, .onPrem, .green:
            UIImage(resource: .passcodeLogo)
        }
    }
    
    @objc public class var backgroundContactInfoSystemMessage: UIColor {
        switch ThreemaApp.current {
        case .threema:
            Colors.blue
        case .work:
            Colors.green
        case .green:
            Colors.blue
        case .blue:
            Colors.green
        case .onPrem:
            Colors.green
        }
    }
    
    @objc public class var backgroundCircleButton: UIColor {
        switch theme {
        case .light, .undefined:
            switch ThreemaApp.current {
            case .threema, .green:
                Asset.TargetColors.Threema.circleButton.color
            case .work, .blue:
                Asset.TargetColors.ThreemaWork.circleButton.color
            case .onPrem:
                Asset.TargetColors.OnPrem.circleButton.color
            }
        case .dark:
            .quaternarySystemFill
        }
    }
    
    public class var grayCircleBackground: UIColor {
        Colors.textLight
    }
    
    public class var grayCircleSymbol: UIColor {
        switch theme {
        case .light, .undefined:
            Asset.SharedColors.white.color
        case .dark:
            Asset.SharedColors.gray700.color
        }
    }
    
    @objc public class var threemaConsumerColor: UIColor {
        color(for: Asset.TargetColors.Threema.primary)
    }
    
    @objc public class var threemaWorkColor: UIColor {
        color(for: Asset.TargetColors.ThreemaWork.primary)
    }
}
