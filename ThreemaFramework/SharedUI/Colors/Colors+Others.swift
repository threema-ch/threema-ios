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
    @objc public class var hairLine: UIColor {
        switch theme {
        case .light, .undefined:
            UIColor(resource: .gray400)
        case .dark:
            UIColor(resource: .gray800)
        }
    }
    
    @objc public class var hairLineBallot: UIColor {
        Colors.backgroundNavigationController
    }
        
    @objc public class var qrCodeTint: UIColor {
        switch theme {
        case .light, .undefined:
            .black
        case .dark:
            .white
        }
    }
}

// MARK: Shadows

extension Colors {
    @objc public class var shadowNotification: UIColor {
        switch theme {
        case .light, .undefined:
            .black
        case .dark:
            .white
        }
    }
}

// MARK: URLs

extension Colors {
    @objc public class var licenseLogoURL: String? {
        switch Colors.theme {
        case .light, .undefined:
            MyIdentityStore.shared().licenseLogoLightURL
        case .dark:
            MyIdentityStore.shared().licenseLogoDarkURL
        }
    }
}
