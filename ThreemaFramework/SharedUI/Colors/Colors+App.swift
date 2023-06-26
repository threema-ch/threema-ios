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
        case .threema:
            return darkColor(for: Asset.TargetColors.Threema.primary)
        case .work:
            return darkColor(for: Asset.TargetColors.ThreemaWork.primary)
        case .red, .workRed:
            return darkColor(for: Asset.TargetColors.ThreemaRed.primary)
        case .onPrem:
            return darkColor(for: Asset.TargetColors.OnPrem.primary)
        }
    }
    
    @objc public class var secondary: UIColor {
        switch ThreemaApp.current {
        case .threema:
            return color(for: Asset.TargetColors.Threema.secondary)
        case .work:
            return color(for: Asset.TargetColors.ThreemaWork.secondary)
        case .red, .workRed:
            return color(for: Asset.TargetColors.ThreemaRed.secondary)
        case .onPrem:
            return color(for: Asset.TargetColors.OnPrem.secondary)
        }
    }
    
    @objc public class var chatBubbleSent: UIColor {
        switch ThreemaApp.current {
        case .threema:
            return color(for: Asset.TargetColors.Threema.chatBubbleSent)
        case .work:
            return color(for: Asset.TargetColors.ThreemaWork.chatBubbleSent)
        case .red, .workRed:
            return color(for: Asset.TargetColors.ThreemaRed.chatBubbleSent)
        case .onPrem:
            return color(for: Asset.TargetColors.OnPrem.chatBubbleSent)
        }
    }
    
    @objc public class var chatBubbleSentSelected: UIColor {
        switch ThreemaApp.current {
        case .threema:
            return color(for: Asset.TargetColors.Threema.chatBubbleSentSelected)
        case .work:
            return color(for: Asset.TargetColors.ThreemaWork.chatBubbleSentSelected)
        case .red, .workRed:
            return color(for: Asset.TargetColors.ThreemaRed.chatBubbleSentSelected)
        case .onPrem:
            return color(for: Asset.TargetColors.OnPrem.chatBubbleSentSelected)
        }
    }
    
    @objc public class var chatCallButtonBubble: UIColor {
        switch ThreemaApp.current {
        case .threema:
            return color(for: Asset.TargetColors.Threema.primary)
        case .work:
            return color(for: Asset.TargetColors.ThreemaWork.primary)
        case .red, .workRed:
            return color(for: Asset.TargetColors.ThreemaRed.primary)
        case .onPrem:
            return color(for: Asset.TargetColors.OnPrem.primary)
        }
    }
    
    @objc public class var navigationBarCall: UIColor {
        switch ThreemaApp.current {
        case .threema:
            return color(for: Asset.TargetColors.Threema.navigationBarCall)
        case .work:
            return color(for: Asset.TargetColors.ThreemaWork.navigationBarCall)
        case .red, .workRed:
            return color(for: Asset.TargetColors.ThreemaRed.navigationBarCall)
        case .onPrem:
            return color(for: Asset.TargetColors.OnPrem.navigationBarCall)
        }
    }
    
    @objc public class var navigationBarWeb: UIColor {
        switch ThreemaApp.current {
        case .threema:
            return color(for: Asset.TargetColors.Threema.navigationBarWeb)
        case .work:
            return color(for: Asset.TargetColors.ThreemaWork.navigationBarWeb)
        case .red, .workRed:
            return color(for: Asset.TargetColors.ThreemaRed.navigationBarWeb)
        case .onPrem:
            return color(for: Asset.TargetColors.OnPrem.navigationBarWeb)
        }
    }
    
    @objc public class var threemaLogo: UIImage? {
        var flavor = ""
        switch ThreemaApp.current {
        case .threema, .red, .workRed:
            flavor = ""
        case .work:
            flavor = "Work"
        case .onPrem:
            flavor = "OnPrem"
        }
        
        switch Colors.theme {
        case .light, .undefined:
            return BundleUtil.imageNamed("Threema\(flavor)Black")
        case .dark:
            return BundleUtil.imageNamed("Threema\(flavor)White")
        }
    }
    
    @objc public class var backgroundContactInfoSystemMessage: UIColor {
        switch ThreemaApp.current {
        case .threema:
            return Colors.blue
        case .work:
            return Colors.green
        case .red:
            return Colors.blue
        case .workRed:
            return Colors.green
        case .onPrem:
            return Colors.green
        }
    }
    
    @objc public class var backgroundCircleButton: UIColor {
        switch theme {
        case .light, .undefined:
            switch ThreemaApp.current {
            case .threema:
                return Asset.TargetColors.Threema.circleButton.color
            case .work:
                return Asset.TargetColors.ThreemaWork.circleButton.color
            case .red, .workRed:
                return Asset.TargetColors.ThreemaRed.circleButton.color
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
