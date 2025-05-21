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

@objc class MainSplitViewController: UISplitViewController {
    
    // MARK: - Properties

    weak var coordinator: AppCoordinator?

    lazy var sidebarViewController = SidebarViewController(coordinator: coordinator)

    // MARK: - Lifecycle
    
    init(coordinator: AppCoordinator, tabBarController: TabBarController) {
        self.coordinator = coordinator
        
        super.init(style: .tripleColumn)
        
        // UISplitViewController config
        preferredDisplayMode = .oneBesideSecondary
        preferredSplitBehavior = .tile
        showsSecondaryOnlyButton = true
        
        // Setup columns
        setViewController(sidebarViewController, for: .primary)
        setViewController(tabBarController, for: .compact)
        // We set a placeholder for the supplementary column
        setViewController(UIViewController(), for: .supplementary)
        
        show(.primary)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        coordinator?.horizontalSizeClass = traitCollection.horizontalSizeClass
    }
    
    // TODO: (IOS-5209) Check if this is still needed
    // Fixes an issues with supplementary VCs taking too much horizontal space
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        maximumSupplementaryColumnWidth = size.width / 2
    }
    
    // We keep track of the size class here, since the app coordinator has no view to detect it
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        guard previousTraitCollection?.horizontalSizeClass != traitCollection.horizontalSizeClass else {
            return
        }
        coordinator?.horizontalSizeClass = traitCollection.horizontalSizeClass
    }
    
    // MARK: - Updates
    
    func updateSelection() {
        sidebarViewController.setSelection()
    }
}
