//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

import SwiftUI
import UIKit

@objc class ThreemaSplitViewController: UISplitViewController {
    
    private(set) lazy var threemaTabBarController = ThreemaTabBarController()
    private lazy var navigationManager = ThreemaSplitViewNavigationManager()
    
    // MARK: - Lifecycle Methods
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        
        preferredDisplayMode = .oneBesideSecondary
        presentsWithGesture = false
        
        displayModeButtonItem.customView = UIView()
        displayModeButtonItem.isEnabled = false
        displayModeButtonItem.isHidden = true
        
        navigationManager.configure(
            with: self,
            tabBarController: threemaTabBarController
        )
    }
}
