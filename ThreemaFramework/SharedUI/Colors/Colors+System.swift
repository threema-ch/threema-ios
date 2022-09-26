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
    @objc class var preferredStatusBarStyle: UIStatusBarStyle {
        switch Colors.theme {
        case .light, .undefined:
            return .default
        case .dark:
            return .lightContent
        }
    }
    
    class var activityIndicatorViewStyle: UIActivityIndicatorView.Style {
        switch Colors.theme {
        case .light, .undefined:
            return .gray
        case .dark:
            return .white
        }
    }
    
    class var blurEffectStyle: UIBlurEffect.Style {
        switch Colors.theme {
        case .light, .undefined:
            return .extraLight
        case .dark:
            return .dark
        }
    }
    
    // Use Int instead of enum for Objective-C classes
    @objc class var objcActivityIndicatorViewStyle: Int {
        activityIndicatorViewStyle.rawValue
    }
    
    // Use Int instead of enum for Objective-C classes
    @objc class var objcBlurEffectStyle: Int {
        blurEffectStyle.rawValue
    }
}
