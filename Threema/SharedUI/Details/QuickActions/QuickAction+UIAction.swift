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

import UIKit

@objc protocol LegacyUIActionProvider: AnyObject {
    func uiActions(in viewController: UIViewController) -> NSArray // of UIAction
}

extension QuickAction {
    var asUIAction: UIAction {
        // Use non-filled version of icon if declared as such in name string
        let actionImageName = imageNameProvider().replacingOccurrences(of: ".fill", with: "")
        let actionImage = BundleUtil.imageNamed(actionImageName)
        assert(
            actionImage != nil,
            "As this only supports iOS 13 and up we assume that at least an SF Symbol exists for the image"
        )
        
        return UIAction(
            title: title,
            image: actionImage,
            handler: action
        )
    }
}

// MARK: - UIAction + QuickActionUpdate

// Support `QuickActionUpdate` for `UIAction` in `UIMenu`
extension UIAction: QuickActionUpdate {
    func reload() {
        // no-op: Because the menu will anyway disappear when the action is called
    }
    
    func hide() {
        // no-op: Because the menu will anyway disappear when the action is called
    }
}
