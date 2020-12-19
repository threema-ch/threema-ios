//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2020 Threema GmbH
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

class ThreemaQLPreviewController : QLPreviewController {
    
    var toolbars: [UIView] = []
    
    var observations : [NSKeyValueObservation] = []
    
    var mdmSetup: MDMSetup = MDMSetup.init(setup: false)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if (mdmSetup.disableShareMedia() == true) {
            navigationItem.setRightBarButton(UIBarButtonItem(), animated: false)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if (mdmSetup.disableShareMedia() == true) {
            navigationController?.toolbar.isHidden = true
            
            if let navigationToobar = navigationController?.toolbar {
                let observation = navigationToobar.observe(\.isHidden) {[weak self] (changedToolBar, change) in
                    
                    if self?.navigationController?.toolbar.isHidden == false {
                        self?.navigationController?.toolbar.isHidden = true
                    }
                }
                observations.append(observation)
            }
            
            toolbars = toolbarsInSubviews(forView: view)
            
            for toolbar in toolbars {
                
                toolbar.isHidden = true
                
                let observation = toolbar.observe(\.isHidden) { (changedToolBar, change) in
                    if let isHidden = change.newValue,
                        isHidden == false {
                        changedToolBar.isHidden = true
                    }
                }
                
                observations.append(observation)
            }
        }
    }
    
    private func toolbarsInSubviews(forView view: UIView) -> [UIView] {
        var toolbars: [UIView] = []
        
        for subview in view.subviews {
            if subview is UIToolbar {
                toolbars.append(subview)
            }
            toolbars.append(contentsOf: toolbarsInSubviews(forView: subview))
        }
        return toolbars
    }
}
