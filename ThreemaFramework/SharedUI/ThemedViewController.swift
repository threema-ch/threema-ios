//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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

open class ThemedViewController: UIViewController {
    
    private let navigationItemPromptShouldChangeNotificationName = Notification
        .Name(kNotificationNavigationItemPromptShouldChange)
    
    // MARK: - Lifecycle
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
                
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(navigationItemPromptShouldChange(_:)),
            name: navigationItemPromptShouldChangeNotificationName,
            object: nil
        )
        
        var prompt = VoIPHelper.shared().currentPromptString(nil)
        if prompt == nil,
           WCSessionHelper.isWCSessionConnected {
            prompt = WCSessionHelper.threemaWebPrompt
        }
        
        navigationItem.prompt = prompt
        
        // Call this here, because views added in code won't be in the hierarchy during `viewDidLoad()`
        updateColors()
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.removeObserver(
            self,
            name: navigationItemPromptShouldChangeNotificationName,
            object: nil
        )
    }
    
    // MARK: - Public methods
    
    /// Refresh view appearance. Called if theme changes.
    @objc open func refresh() {
        // This needs to be accessible from Obj-C to be called when the color theme changes
        // (see `-colorThemeChanged:` in `ThemedNavigationController`)
        updateColors()
    }
    
    /// Called whenever the colors of the views should be set to the current theme colors
    open func updateColors() {
        view.backgroundColor = Colors.backgroundViewController
        Colors.setTextColor(Colors.text, in: view)
    }
    
    // MARK: - Notifications
    
    @objc func navigationItemPromptShouldChange(_ notification: Notification) {
        if notification.object == nil,
           WCSessionHelper.isWCSessionConnected {
            navigationItem.prompt = WCSessionHelper.threemaWebPrompt
        }
        else {
            let time = notification.object as? NSNumber
            navigationItem.prompt = VoIPHelper.shared()?.currentPromptString(time)
        }
        
        updateColors()
        
        navigationController?.view.setNeedsLayout()
        navigationController?.view.layoutIfNeeded()
        navigationController?.view.setNeedsDisplay()
        
        // Update navigation controllers view controllers view when height changes
        /// Fixes incorrect content offset after the navigation bar updates its height
        /// We only noticed this in chat view controller but other views in general should suffer from similar issues.
        /// Thus we don't check specifically for chat view controller.
        navigationController?.viewControllers.forEach { $0.view.setNeedsLayout() }
    }
}
