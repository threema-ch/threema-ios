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
                
    @objc public class var threemaLogo: UIImage! {
        switch TargetManager.current {
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
        switch TargetManager.current {
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
        switch TargetManager.current {
        case .blue:
            UIImage(resource: .passcodeLogoGreen)
        case .threema, .work, .onPrem, .green:
            UIImage(resource: .passcodeLogo)
        }
    }
}
