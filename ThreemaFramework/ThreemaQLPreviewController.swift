//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2022 Threema GmbH
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
import QuickLook

public class ThreemaQLPreviewController : QLPreviewController {
    
    var observations : [NSKeyValueObservation] = []
    
    var mdmSetup: MDMSetup = MDMSetup.init(setup: false)
    
    var disableShareButton = false
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        disableShareButton = mdmSetup.disableShareMedia()
        
        if (disableShareButton) {
            navigationItem.setRightBarButton(UIBarButtonItem(), animated: false)
        }
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        removeToolbarItems()
    }
    
    private func removeToolbarItems() {
        if (mdmSetup.disableShareMedia()) {
            if let navigationToolbar = navigationController?.toolbar {
                navigationToolbar.isHidden = true
                let observation = navigationToolbar.observe(\.isHidden, changeHandler: observeNavigationToolbarHidden)
                observations.append(observation)
            }
            
            for toolbar in toolbarsInSubviews(forView: view) {
                toolbar.isHidden = true
                let observation = toolbar.observe(\.isHidden, changeHandler: observeNavigationToolbarSubviewHidden)
                observations.append(observation)
            }
        }
    }
    
    func observeNavigationToolbarHidden(changed : UIView, change :  NSKeyValueObservedChange<Bool>) {
        if self.navigationController?.toolbar.isHidden == false {
            self.navigationController?.toolbar.isHidden = true
        }

    }
    
    func observeNavigationToolbarSubviewHidden(changed : UIView, change :  NSKeyValueObservedChange<Bool>) {
        changed.isHidden = true
    }
    
    private func toolbarsInSubviews(forView view: UIView) -> [UIView] {
        if view is UIToolbar {
            return [view]
        }
        var toolbars = [UIView]()
        for subview in view.subviews {
            toolbars.append(contentsOf: toolbarsInSubviews(forView: subview))
        }
        return toolbars
    }
}
